# claude-skills

Skills for [Claude Code](https://claude.com/claude-code).

| Skill | What it does |
|---|---|
| [`setup-vercel-cli-deploy`](setup-vercel-cli-deploy/SKILL.md) | Deploy to Vercel from GitHub Actions with the Vercel CLI: fills Sensitive env vars from a secret, deploys prebuilt output, promotes, smoke-tests, and auto-rolls back. For repos whose committers aren't on the Vercel team. |

## Install

Copy a skill folder into `~/.claude/skills/` (all projects) or `<repo>/.claude/skills/` (one project):

```bash
git clone https://github.com/furtherafay/claude-skills.git
cp -r claude-skills/setup-vercel-cli-deploy ~/.claude/skills/
```

Then run it with `/setup-vercel-cli-deploy`, or ask Claude to set up Vercel deploys from GitHub Actions.
