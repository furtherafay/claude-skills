---
name: setup-vercel-cli-deploy
description: "Set up production deploys to Vercel from GitHub Actions with the Vercel CLI (pull → fill Sensitive env vars from a secret → build → deploy --prebuilt → promote → smoke test → auto-rollback), plus a `redeploy` script and a manual Ops workflow (inspect / roll back). For when pushes don't deploy because the commit author isn't on the Vercel team and adding them isn't an option. TRIGGER when the user asks to deploy to Vercel from GitHub Actions/CI, set up `pnpm redeploy` / `npm run redeploy`, or says pushes aren't deploying on Vercel because of the commit author / team membership."
user-invocable: true
---

# Set up Vercel deploys from GitHub Actions (Vercel CLI)

Builds the app in GitHub Actions and deploys the **prebuilt** output with the
project owner's Vercel token.

**Check first:** if the commit author can simply be added to the Vercel team,
recommend that. The Git integration is simpler and has no secrets to keep in
sync. Use this skill when that isn't an option.

## Hard-won facts (each one took production down or blocked a deploy)

1. **Source deploys are blocked.** Vercel blocks `vercel deploy` *without*
   `--prebuilt` when the commit author isn't a team member ("Deployment Blocked:
   <user> is not a member of your team"). The CLI doesn't fail; it sits on
   "Building…" forever. Prebuilt deploys with the team's token are accepted.
2. **`vercel pull` can't read Sensitive env vars.** It prints
   `! N Secret values cannot be pulled` and writes the literal `[SENSITIVE]` as
   their values. `vercel build` then bakes the placeholders in, and **every
   route returns 500**, yet the workflow reports success. The template fills
   them from the `VERCEL_SENSITIVE_ENV` secret and refuses to build if any
   placeholder is left.
3. **A green run doesn't mean production works.** Always load the live site.
   The template smoke-tests the domain after promoting and rolls back on a 5xx.
4. **After an Instant Rollback in the dashboard**, Vercel stops assigning the
   domain to new production deploys. The template's explicit `vercel promote`
   lifts that, then checks the domain really serves the new deploy.

## Files this adds

```
<repo>/
├── .github/workflows/vercel-deploy.yml   # deploy on push to the prod branch + manual dispatch
├── .github/workflows/vercel-ops.yml      # manual: list deploys, inspect one, roll back
└── scripts/redeploy.sh                    # `gh workflow run` wrapper
```

The templates are in `templates/`.

## Steps

### 1. Inspect the repo

- **Package manager:** check the lockfile and the `packageManager` field.
- **Production branch** and **production domain**.
- **Node version:** `engines.node` / `.nvmrc`, or 22.
- **Existing workflows:** don't clobber any.
- **Monorepo:** each Vercel project needs its own job and `VERCEL_PROJECT_ID`.
- Read the env var *names* (never the values) from `.env*` files so you can
  tell the user which ones are probably Sensitive.

### 2. Copy and fill in the templates

Copy all three, and mark `redeploy.sh` executable
(`git update-index --add --chmod=+x`). Replace the placeholders:
- `__BRANCH__`: the production branch
- `__PRODUCTION_DOMAIN__`: e.g. `app.example.com`
- `__NODE_VERSION__`: the Node major version
- `__PACKAGE_MANAGER__`: `pnpm`, `npm` or `yarn`. For npm/yarn, delete the
  `pnpm/action-setup` step.

Add `"redeploy": "bash scripts/redeploy.sh"` to `package.json`.

### 3. Get the repo secrets added (the user/owner does this)

| Secret | Where |
|---|---|
| `VERCEL_TOKEN` | vercel.com/account/tokens, created with the owning team selected |
| `VERCEL_ORG_ID` | Team Settings → General → Team ID |
| `VERCEL_PROJECT_ID` | Project → Settings → General → Project ID |
| `VERCEL_SENSITIVE_ENV` | `KEY=value` lines, one per **Sensitive** production var (lock icon in Environment Variables) |

Vercel never shows Sensitive values again, so they must come from each
service's own dashboard. Warn the user that production values can differ from
their local `.env` (live vs sandbox keys, app URL). Tell them they must update
the secret whenever a Sensitive var changes in Vercel.

You can confirm the secret *names* exist through the GitHub API
(`GET /repos/<o>/<r>/actions/secrets`); the values can't be read.

### 4. First deploy: supervised, not a blind push

- Keep the deploy workflow **disabled** while pushing the files
  (`PUT /repos/<o>/<r>/actions/workflows/vercel-deploy.yml/disable`), so the
  push doesn't deploy.
- Only push after the user asks. Stage just these files; `git fetch` and
  `git pull --rebase` if the remote moved.
- Enable the workflow, start it with `workflow_dispatch` while the user
  watches, and wait for it to finish.
- Then **load the live site yourself** (`/` and a route that touches the
  backend/auth) before reporting success.

If `gh` is missing and the repo is private, use the REST API with the user's
stored git credential (`git credential fill`), and never print the token:
- Runs: `GET /actions/workflows/<file>/runs?head_sha=<sha>`, then
  `/actions/runs/<id>` until it's `completed`.
- Job log (only available once the step finishes; follow the redirect):
  `GET /actions/jobs/<job_id>/logs`. Grep for `Currently live`, `now serves`,
  `-> <code>`, `healthy`, `::error::`.

## If production breaks

1. The fastest fix is an **Instant Rollback** in the Vercel dashboard
   (Deployments → last good deploy → ⋯).
2. Without dashboard access, use the **Vercel Ops** workflow: set
   `rollback_before` to an ISO time before the bad deploy, and set `inspect` to
   a deployment URL to see its status or logs.
3. A deploy stuck on "Building…": check its page in Vercel. "Blocked" means
   fact 1 above.

## Notes for the user

- If the Vercel Git integration is connected, non-member pushes also create
  "Blocked" deploys in the dashboard. That's noise, not harm.
- `pnpm redeploy` needs the GitHub CLI (`winget install GitHub.cli` /
  `brew install gh`, then `gh auth login`).
- Preview deploys aren't included.
