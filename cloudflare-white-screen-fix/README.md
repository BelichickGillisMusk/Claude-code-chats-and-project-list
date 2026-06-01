# Cloudflare Pages white-screen remediation

Vite + React apps (exported from Google AI Studio) across the
**BelichickGillisMusk** org deploy to Cloudflare Pages, return HTTP **200**,
but show a **blank page**. Root cause: the repo **root is published as raw
source**, so `index.html` loads `/src/main.tsx` (uncompiled TypeScript) instead
of a built `/assets/*.js` bundle. **No build step ran.** The fix is to build the
app (`npm run build`) and publish the built `dist/` to the existing Pages
project.

- **Cloudflare account:** `bafa242dd95d3fdce72540d20accd0a2`
- **Token:** stored in GitHub org secret `CLOUDFLARE_API_TOKEN` (consumed by the
  GitHub Actions workflow at deploy time).

---

## ⚠️ Why this is a kit and not a finished deploy

The Claude Code session that produced this diagnosis was **environment-blocked**
from executing the fix. Logged explicitly (no silent failure):

| Capability needed | Status in that session |
|---|---|
| Push to the app repos (GitHub MCP / git) | ❌ Scope locked to **only** `Claude-code-chats-and-project-list`. Every other repo returned `Access denied` / `repository not authorized`. |
| Widen repo scope (`list_repos`/`add_repo`) | ❌ No such tool present in the session. |
| `CLOUDFLARE_API_TOKEN` in the environment | ❌ Not set — cannot call the Pages API, list/PATCH projects, or trigger deploys. |
| Outbound network (verify live URLs, wrangler) | ❌ All outbound returns **403** (network policy); even `example.com` is blocked. |
| GitHub **global code search** (read-only) | ✅ Worked — used to build the inventory below. |

So the diagnosis is complete and verified from source, but the writes/deploys
must run from a properly-scoped, credentialed environment. This kit does exactly
that and is idempotent.

---

## Affected repos (from `org:BelichickGillisMusk` code search)

`index.html` references `/src/main.tsx` and `package.json` uses Vite.
"before" = ships raw source (confirmed in repo); "after" = pending the deploy
(verify with `verify-render.sh` once run).

| repo | shape | path(s) → /src/main.tsx | deploy method (likely) | before raw? | after renders? | notes |
|---|---|---|---|---|---|---|
| GILLIS-HQ | SPA (root) | `index.html` | Pages (Actions/none) | **yes** | pending | build `tsc -b --noCheck && vite build` → `dist` |
| silverbackai.agency | SPA (root) | `index.html` | Pages (custom domain silverbackai.agency) | **yes** | pending | → `dist` |
| silverback-site-deploy | SPA (root) | `index.html` | Pages | **yes** | pending | → `dist` |
| rentbuby-2 | SPA (root) | `index.html`* | Pages | **yes** | pending | → `dist` |
| jbruno-no-vite-…-JBruno | SPA (root) | `index.html` | Pages (domain bryanoneillgillis.com?) | **yes** | pending | repo name says "no-vite" but pkg is **vite-react** — confirm intended host |
| AI-Studio-for-Silverback | **monorepo** | `index.html`, `homepage/`, `silverback/`, `orozco/`, `timesheets/` | Pages (multiple) | **yes** | pending | **each subdir is its own app** → needs its own build + own Pages project |
| deployment-handoff-site | **fullstack** | `client/index.html` | Pages/Workers | **yes** | review | Vite client + esbuild server; output likely `dist/public`, not plain `dist` |
| openclaw-command-center | **fullstack** | `client/index.html` | Pages/Workers | **yes** | review | same shape as above |
| intelligence-factory-dashboard | **fullstack** | `client/index.html` | Pages/Workers | **yes** | review | same shape; possibly carbcleantruckcheck.app |
| github (repo) | nested in Workers | `workers/silverback-ai-studio/index.html` | Workers pipeline | **yes** | review | deploy via its own pipeline, not this workflow |

\* `rentbuby-2` matched the Vite `package.json`; its `index.html` follows the
same AI Studio template. Confirm on clone.

### Groups
- **A — simple root SPA** → canonical workflow applies verbatim (`dist`).
  Handled automatically by `fix-white-screens.sh`.
- **B — AI Studio monorepo** (`AI-Studio-for-Silverback`) → one Vite app per
  subdir; each needs its own build and its own Pages project. Do **not** run a
  single root build. Map each subdir → project before applying.
- **C — fullstack** (Manus client+server) → emit a server bundle too (usually
  `dist/public`). Don't blindly point Pages at `dist`; review host/output dir.
- **D — nested-in-Workers** (`github`) → deploy through its existing Workers
  pipeline.

---

## How to run

```bash
export CLOUDFLARE_API_TOKEN=...                       # org secret value
export CLOUDFLARE_ACCOUNT_ID=bafa242dd95d3fdce72540d20accd0a2
gh auth status                                        # must be authenticated with org push rights

# 1. Dry run — prints the plan and resolves existing Pages project names
./fix-white-screens.sh

# 2. Apply Group A (commits the workflow, pushes to main, CI builds + deploys)
APPLY=1 ./fix-white-screens.sh

# 3. Verify the REAL check (renders, not just 200)
./verify-render.sh https://silverbackai.agency https://<project>.pages.dev ...
```

`fix-white-screens.sh` resolves each repo to its **existing** Pages project via
the Pages API (`wrangler pages project list` equivalent) so it never creates a
duplicate. If it can't resolve one, it writes `REPLACE_WITH_EXISTING_PROJECT_NAME`
and warns — set it by hand before `APPLY=1`.

### Native Git integration repos (alternative to the workflow)
If a repo deploys via Cloudflare's **native Git integration** (not Actions),
don't add the workflow — instead PATCH the Pages project build config and
redeploy:

```bash
curl -X PATCH \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/PROJECT_NAME" \
  -d '{"build_config":{"build_command":"npm run build","destination_dir":"dist","root_dir":""}}'

# then trigger a fresh deployment of production:
curl -X POST \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/pages/projects/PROJECT_NAME/deployments"
```

---

## Files
- `deploy.yml` — canonical GitHub Actions workflow (copy to
  `.github/workflows/deploy.yml`, set `PROJECT_NAME`).
- `fix-white-screens.sh` — clones each affected repo, ensures a lockfile, writes
  the workflow with the resolved project name, commits, pushes. Idempotent.
- `verify-render.sh` — fetches a live URL and asserts a hashed `/assets/*.js`
  bundle is present and `/src/*.tsx` is gone; optional headless `#root` check.
