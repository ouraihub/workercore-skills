# workercore-skills

Claude Code skill for building admin panels with [`@ouraihub/workercore`](https://github.com/ouraihub/workercore) — a zero-config admin-panel framework for Cloudflare Workers.

The skill teaches any coding agent to generate correct workercore code: the `createApp` structure, data-only page handlers, JSON API routes, Mustache templates, the semantic color-token system (no `dark:`), the built-in partial catalog, and the "no inline JS" client-interactivity convention.

## Install

### Option A — skills CLI (recommended)

```bash
# install into the current project (.claude/skills/)
npx skills add ouraihub/workercore-skills --skill workercore

# or install globally (~/.claude/skills/)
npx skills add ouraihub/workercore-skills -g --skill workercore

# list what's in the repo
npx skills add ouraihub/workercore-skills -l
```

| Flag | Effect |
| --- | --- |
| `-g` | Install globally to `~/.claude/skills/`. Omit to install into the current project's `.claude/skills/`. |
| `--skill <name>` | Install a specific skill. |
| `--all` | Install every skill in the repo. |
| `-l` | List available skills without installing. |

### Option B — Claude Code plugin marketplace

```bash
# in Claude Code
/plugin marketplace add ouraihub/workercore-skills
/plugin install workercore-skills@workercore-skills
```

### Option C — git clone

```bash
git clone https://github.com/ouraihub/workercore-skills.git ~/.claude/plugins/workercore-skills
```

## Skills

| Skill | Description |
| --- | --- |
| `workercore` | Full-framework skill — conventions, `createApp`, PageHandler/ApiHandler patterns, semantic color tokens, partial catalog, client interactivity, errors, and an end-to-end recipe. Triggers automatically when generating workercore code or when the repo imports `@ouraihub/workercore`. |

## Usage

Once installed, ask your agent for workercore work and the skill loads automatically:

```
Add a "Reports" page with a stats row and a data table. use the workercore skill
```

## The 7 rules the skill enforces

1. TS never contains page HTML structure — pages are Mustache `.html` templates; handlers return data.
2. HTML never contains JS — interactivity lives in `src/client/modules/`, bound via `data-*` or CSS `:target`.
3. A PageHandler only returns data: `(ctx) => Promise<object>`.
4. Throw `WorkerError` / `ValidationError` / `NotFoundError` / `AuthError`, never bare `Error`.
5. Log with `logger.info("msg", { key })`, never `console.log`.
6. KV keys are colon-namespaced: `user:admin`, `session:<id>`.
7. UI uses semantic tokens (`bg-surface`, `text-fg`, `bg-primary`, `bg-danger-solid`), never raw Tailwind colors and never `dark:` for color.

## License

MIT
