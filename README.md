# workercore-skills

A collection of Claude Code skills. Two groups:

1. **`workercore`** — build admin panels with [`@ouraihub/workercore`](https://github.com/ouraihub/workercore), a zero-config admin-panel framework for Cloudflare Workers. Teaches any coding agent to generate correct workercore code: the `createApp` structure, data-only page handlers, JSON API routes, Mustache templates, the semantic color-token system (no `dark:`), the built-in partial catalog, and the "no inline JS" client-interactivity convention.

2. **`setup-*-relay`** — configure a coding agent (Claude Code, Codex, OpenCode, Pi) on a fresh machine to run through an OpenAI/Anthropic-compatible relay (七牛云 Qiniu, EasyClaude, NeCodeX, …). Each skill is profile-driven: relay-specific differences live in `assets/profiles/<name>.json`, so adding a new relay is just adding one profile. Every profile ships end-to-end verified, with the relay-specific gotchas (endpoint shape, auth mode, WAF User-Agent blocks) baked in.

## Install

### Option A — skills CLI (recommended)

```bash
# install a specific skill into the current project (.claude/skills/)
npx skills add ouraihub/workercore-skills --skill workercore

# or install globally (~/.claude/skills/)
npx skills add ouraihub/workercore-skills -g --skill setup-codex-relay

# install everything
npx skills add ouraihub/workercore-skills --all

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
| `setup-claude-relay` | Configure Claude Code CLI to run through an Anthropic-compatible relay (`/v1/messages`). Writes `~/.claude/settings.json`. Verified against Qiniu (七牛云). |
| `setup-codex-relay` | Configure OpenAI Codex CLI to run through a Responses-API relay. Writes `~/.codex/config.toml` (+ `auth.json` for relays like Qiniu's `/bypass/openai/v1` endpoint). Codex 0.133.0+ only supports `wire_api=responses`. |
| `setup-opencode-relay` | Install + configure OpenCode through an OpenAI/Anthropic-compatible relay, plus the oh-my-openagent (omo) multi-agent plugin and per-agent model-mapping. Fixes several installer gotchas. |
| `setup-pi-relay` | Install + configure the Pi coding agent through an OpenAI/Anthropic-compatible relay. Includes the dual-provider split and the OpenAI-SDK User-Agent WAF (403) fix. |

The `setup-*-relay` skills are profile-driven: relays ship as `assets/profiles/<name>.json`. Verified profiles include `qiniu` (七牛云), `easyclaude`, and `necodex`. Each skill has a `scripts/verify.sh` that end-to-end tests a profile in an isolated config dir.

## Usage

Once installed, ask your agent for the matching task and the skill loads automatically:

```
Add a "Reports" page with a stats row and a data table. use the workercore skill
```

```
配置 codex 走七牛云中转
```

## The 7 rules the `workercore` skill enforces

1. TS never contains page HTML structure — pages are Mustache `.html` templates; handlers return data.
2. HTML never contains JS — interactivity lives in `src/client/modules/`, bound via `data-*` or CSS `:target`.
3. A PageHandler only returns data: `(ctx) => Promise<object>`.
4. Throw `WorkerError` / `ValidationError` / `NotFoundError` / `AuthError`, never bare `Error`.
5. Log with `logger.info("msg", { key })`, never `console.log`.
6. KV keys are colon-namespaced: `user:admin`, `session:<id>`.
7. UI uses semantic tokens (`bg-surface`, `text-fg`, `bg-primary`, `bg-danger-solid`), never raw Tailwind colors and never `dark:` for color.

## License

MIT
