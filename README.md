# Claude-code-chats-and-project-list

Central repo for Claude Code session outputs: Cloudflare ops, cleanup inventory, and deployment kits.

## Contents

| Path | Purpose |
|---|---|
| `cloudflare-white-screen-fix/` | Fix kit for Vite/React Pages sites showing blank on HTTP 200 |
| `Random Cloudflare files/` | Multi-run cleanup inventory (Runs 1–22) |
| `.claude/agents/` | Custom agents (e.g. project-progress-tracker) |
| `PROJECT_PROGRESS_ASSESSMENT.md` | Latest progress % and next steps |

## Quick commands

```bash
# White-screen fix (dry run)
cd cloudflare-white-screen-fix
./fix-white-screens.sh

# After setting CLOUDFLARE_API_TOKEN and verifying project names:
APPLY=1 ./fix-white-screens.sh
./verify-render.sh https://silverbackai.agency
```

## Lodi worker (2026-06-24)

Worker `cleantruckcheck-lodi` deployed to `https://cleantruckcheck-lodi.silverbackai.workers.dev`.  
Custom domain `cleantruckchecklodi.com` needs dashboard attach (conflicts with existing Pages project).

## Account

- Cloudflare: `bafa242dd95d3fdce72540d20accd0a2` (Gillis Institute of AI)
- GitHub org: `BelichickGillisMusk`