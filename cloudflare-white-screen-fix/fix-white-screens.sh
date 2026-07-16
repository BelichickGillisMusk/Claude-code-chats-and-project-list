#!/usr/bin/env bash
#
# fix-white-screens.sh
# ---------------------
# Fixes white-screen Cloudflare Pages deploys across the BelichickGillisMusk
# org: Vite + React apps (exported from Google AI Studio) whose repo ROOT is
# published as raw source, so index.html loads /src/main.tsx (uncompiled TS)
# instead of a built /assets/*.js bundle, producing a blank page on a 200.
#
# The fix: add a GitHub Actions workflow that runs `npm ci && npm run build`
# and deploys the built `dist/` to the EXISTING Cloudflare Pages project.
#
# WHY THIS SCRIPT EXISTS SEPARATELY:
# The Claude Code session that diagnosed this was network-locked (no outbound
# access, no CLOUDFLARE_API_TOKEN) and GitHub-scoped to a single repo, so it
# could not push to the app repos or call the Cloudflare API. Run this from an
# environment that has: gh authenticated, git push rights to the org, and
# CLOUDFLARE_API_TOKEN exported. It is idempotent and safe to re-run.
#
# Requirements: bash, git, gh (authenticated), node/npm, jq, curl,
#               and `npx wrangler` (or wrangler) for project name lookup.
#
# Usage:
#   export CLOUDFLARE_API_TOKEN=...          # required for Pages API + verify
#   export CLOUDFLARE_ACCOUNT_ID=bafa242dd95d3fdce72540d20accd0a2
#   ./fix-white-screens.sh                   # dry-run: prints planned actions
#   APPLY=1 ./fix-white-screens.sh           # actually commit + push + deploy
#
set -euo pipefail

ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-bafa242dd95d3fdce72540d20accd0a2}"
ORG="BelichickGillisMusk"
APPLY="${APPLY:-0}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# --- Repos confirmed to ship raw Vite source (index.html -> /src/main.tsx). ---
# Group A: simple single-app Vite SPA at repo root. Canonical workflow applies
#          as-is; build output is `dist`. Format: "repo|subdir|build_out"
GROUP_A=(
  "GILLIS-HQ|.|dist"
  "silverbackai.agency|.|dist"
  "silverback-site-deploy|.|dist"
  "rentbuby-2|.|dist"
  # Repo literally named "...no-vite..." but its package.json IS vite-react.
  # Confirm the intended live domain before deploying.
  "jbruno-no-vite-use-bryanoneillgillis.com-for-SIlverBack-KPI-and-JBruno|.|dist"
)

# Group B: AI Studio MONOREPO — multiple independent Vite apps in subdirs.
#          Each subdir is its own app and needs its own build + (likely) its
#          own Pages project. A single root `npm run build` will NOT build them.
GROUP_B_REPO="AI-Studio-for-Silverback"
GROUP_B_SUBDIRS=( "." "homepage" "silverback" "orozco" "timesheets" )

# Group C: FULLSTACK (Vite client + Node/esbuild server). NOT a plain static
#          publish — they emit a server bundle too and usually output to
#          dist/public. Do NOT blindly point Pages at `dist`. Manual review.
GROUP_C=( "deployment-handoff-site" "openclaw-command-center" "intelligence-factory-dashboard" )

# Group D: Vite app nested inside a Workers monorepo. Different deploy path.
GROUP_D_NOTE="github (workers/silverback-ai-studio) — deploy via its own pipeline, not this workflow."

log()  { printf '\033[1;34m[fix]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[err]\033[0m %s\n' "$*" >&2; }

require() { command -v "$1" >/dev/null 2>&1 || { err "missing required tool: $1"; exit 1; }; }
require git; require gh; require npm; require jq; require curl

# Cache `wrangler pages project list` once.
PROJECTS_JSON=""
load_projects() {
  [ -n "$PROJECTS_JSON" ] && return 0
  [ -z "${CLOUDFLARE_API_TOKEN:-}" ] && { warn "CLOUDFLARE_API_TOKEN unset — cannot resolve project names automatically"; return 1; }
  log "Listing existing Cloudflare Pages projects (no duplicates will be created)…"
  PROJECTS_JSON="$(curl -fsS \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/pages/projects?per_page=100" \
    | jq -c '.result')" || { warn "Pages project list call failed"; return 1; }
  echo "$PROJECTS_JSON" | jq -r '.[] | "  - \(.name)  (subdomain: \(.subdomain))"'
}

# Best-effort: match a repo name to an existing Pages project name.
resolve_project() {
  local repo="$1"
  load_projects >/dev/null 2>&1 || true
  [ -z "$PROJECTS_JSON" ] && { echo ""; return; }
  # exact, then case-insensitive, then prefix match
  echo "$PROJECTS_JSON" | jq -r --arg r "$repo" '
    ([.[] | select(.name==$r)] | .[0].name) //
    ([.[] | select((.name|ascii_downcase)==($r|ascii_downcase))] | .[0].name) //
    ([.[] | select((.name|ascii_downcase)|startswith($r|ascii_downcase[0:12]))] | .[0].name) //
    "" '
}

# Explicit override: set PROJECT_<REPO> (repo name upper-cased, non-alphanumerics
# -> "_") to force a project name the API can't resolve. e.g.
#   export PROJECT_GILLIS_HQ=gillis-hq
override_project() {
  local key
  key="PROJECT_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')"
  printf '%s' "${!key:-}"
}

write_workflow() {
  local dir="$1" project="$2" build_out="$3"
  mkdir -p "$dir/.github/workflows"
  cat > "$dir/.github/workflows/deploy.yml" <<YAML
name: Deploy to Cloudflare Pages
on:
  push:
    branches: [main]
permissions:
  contents: read
  deployments: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm run build
      - uses: cloudflare/wrangler-action@9acf94ace14e7dc412b076f2c5c20b8ce93c79cd # v3
        with:
          apiToken: \${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${ACCOUNT_ID}
          command: pages deploy ${build_out} --project-name=${project}
YAML
}

process_repo() {
  local repo="$1" subdir="${2:-.}" build_out="${3:-dist}"
  local project; project="$(override_project "$repo")"
  [ -z "$project" ] && project="$(resolve_project "$repo")"
  if [ -z "$project" ]; then
    # Fail fast in apply mode: never commit/push a workflow with an unresolved
    # project — that would deploy a broken CI config into the repo.
    if [ "$APPLY" = "1" ]; then
      err "$repo: SKIPPED — could not resolve an existing Pages project."
      err "       Set PROJECT_$(printf '%s' "$repo" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')=<existing-project> and re-run, or check CLOUDFLARE_API_TOKEN."
      return
    fi
    warn "$repo: could not resolve an existing Pages project (dry-run placeholder shown)."
    project="REPLACE_WITH_EXISTING_PROJECT_NAME"
  fi
  log "$repo (subdir=$subdir) -> Pages project '$project', deploy '$build_out'"
  [ "$APPLY" != "1" ] && { echo "       (dry-run; set APPLY=1 to commit/push)"; return; }

  local clone="$WORKDIR/$repo"
  rm -rf "$clone"
  gh repo clone "$ORG/$repo" "$clone" -- --depth=1 >/dev/null 2>&1 \
    || git clone --depth=1 "https://github.com/$ORG/$repo.git" "$clone"
  ( cd "$clone"
    # Ensure a lockfile exists so `npm ci` works in CI.
    local app="$clone/$subdir"
    if [ ! -f "$app/package-lock.json" ]; then
      log "  no package-lock.json in $subdir — running npm install to generate one"
      ( cd "$app" && npm install --package-lock-only --ignore-scripts >/dev/null 2>&1 || npm install --ignore-scripts >/dev/null 2>&1 )
    fi
    write_workflow "$app" "$project" "$build_out"
    git add -A
    if git diff --cached --quiet; then
      log "  nothing to commit (already fixed)"
    else
      git commit -q -m "ci: build Vite app and deploy built dist to Cloudflare Pages

Repo root was published as raw source so index.html loaded /src/main.tsx
instead of a built /assets bundle (blank page on HTTP 200). This adds a
GitHub Actions workflow that runs npm ci && npm run build and deploys the
built output to the existing Pages project '$project'."
      git push origin HEAD:main
      log "  pushed. GitHub Actions will build + deploy."
    fi
  )
}

echo "=============================================================="
echo " Cloudflare Pages white-screen remediation"
echo " Account: $ACCOUNT_ID   Apply: $APPLY"
echo "=============================================================="
load_projects || true
echo

log "GROUP A — simple Vite SPA at repo root:"
for entry in "${GROUP_A[@]}"; do
  IFS='|' read -r r s o <<< "$entry"; process_repo "$r" "$s" "$o"
done

echo
log "GROUP B — AI Studio monorepo ($GROUP_B_REPO): one app per subdir."
warn "Each subdir needs its OWN Pages project. Edit the project mapping below before APPLY=1."
for sub in "${GROUP_B_SUBDIRS[@]}"; do
  echo "  - $GROUP_B_REPO/$sub  (build that subdir, deploy its dist to a distinct project)"
done

echo
warn "GROUP C — fullstack apps (client+server), NOT a plain static publish: ${GROUP_C[*]}"
warn "  These output a server bundle too (usually dist/public). Review host/output before deploying to Pages."
echo
warn "GROUP D — $GROUP_D_NOTE"
echo
log "Done. Re-run with APPLY=1 (and CLOUDFLARE_API_TOKEN set) to execute Group A."
echo "After deploys finish, verify each live URL with verify-render.sh."
