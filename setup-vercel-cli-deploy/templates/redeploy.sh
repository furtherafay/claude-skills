#!/usr/bin/env bash
# Trigger a production deploy on demand via the Vercel Deploy workflow.
#
# Usage:
#   scripts/redeploy.sh
#   pnpm redeploy
#
# Requirements:
#   - GitHub CLI (`gh`) authenticated with access to this repo.
#   - Repo secrets VERCEL_TOKEN, VERCEL_ORG_ID, VERCEL_PROJECT_ID set.
set -euo pipefail

workflow="vercel-deploy.yml"

# Resolve the repo from `origin` (gh follows GitHub's redirect for renamed or
# transferred repos).
origin_url="$(git remote get-url origin 2>/dev/null || true)"
repo="$(printf '%s' "$origin_url" | sed -E 's#^git@github\.com:##; s#^https://github\.com/##; s#\.git$##')"
if [ -z "$repo" ]; then
  echo "redeploy: could not determine the GitHub repo from the 'origin' remote." >&2
  exit 1
fi

echo "Dispatching $workflow on $repo (__BRANCH__)"
gh workflow run "$workflow" --repo "$repo" --ref __BRANCH__

sleep 3
gh run list --repo "$repo" --workflow="$workflow" --limit 1
echo
echo "Follow it with:"
echo "  gh run watch --repo $repo \$(gh run list --repo $repo --workflow=$workflow --limit 1 --json databaseId -q '.[0].databaseId')"
