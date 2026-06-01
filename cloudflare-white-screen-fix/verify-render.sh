#!/usr/bin/env bash
#
# verify-render.sh — the REAL check (not just HTTP 200).
# Fetches a live URL's index.html and asserts it references a hashed
# /assets/*.js bundle AND does NOT reference /src/*.tsx. Optionally uses a
# headless browser (if `npx playwright` is available) to confirm that
# <div id="root"> actually has child nodes after hydration.
#
# Usage:
#   ./verify-render.sh https://silverbackai.agency https://gillis-hq.pages.dev ...
#
set -uo pipefail

pass=0; fail=0
printf '%-45s | %-10s | %-10s | %s\n' "URL" "assets js" "no /src" "result"
printf -- '-%.0s' {1..90}; echo

for url in "$@"; do
  html="$(curl -fsSL --max-time 20 "$url" 2>/dev/null || true)"
  if [ -z "$html" ]; then
    printf '%-45s | %-10s | %-10s | %s\n' "$url" "-" "-" "UNREACHABLE"
    fail=$((fail+1)); continue
  fi
  has_assets="no"; has_src="no"
  echo "$html" | grep -Eiq '<script[^>]+src="[^"]*/assets/[^"]+\.js"' && has_assets="yes"
  echo "$html" | grep -Eiq 'src="[^"]*/src/[^"]+\.tsx"' && has_src="yes"

  result="RENDERS (fixed)"
  if [ "$has_assets" != "yes" ] || [ "$has_src" = "yes" ]; then
    result="RAW SOURCE (broken)"
    fail=$((fail+1))
  else
    pass=$((pass+1))
  fi

  # Optional headless confirmation that #root has children.
  if command -v npx >/dev/null 2>&1 && npx --no-install playwright --version >/dev/null 2>&1; then
    children="$(npx --no-install playwright screenshot --help >/dev/null 2>&1; node -e '
      const { chromium } = require("playwright");
      (async () => {
        const b = await chromium.launch();
        const p = await b.newPage();
        await p.goto(process.argv[1], { waitUntil: "networkidle", timeout: 20000 }).catch(()=>{});
        const n = await p.evaluate(() => (document.getElementById("root")?.childElementCount ?? -1)).catch(()=>-1);
        console.log(n); await b.close();
      })();
    ' "$url" 2>/dev/null || echo "?")"
    result="$result | #root children=$children"
  fi

  printf '%-45s | %-10s | %-10s | %s\n' "$url" "$has_assets" "$has_src" "$result"
done

echo
echo "rendered/fixed: $pass    broken/unreachable: $fail"
[ "$fail" -eq 0 ]
