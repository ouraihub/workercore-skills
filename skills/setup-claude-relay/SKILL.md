---
name: setup-claude-relay
description: 在一台新机器上配置 Claude Code CLI，使其通过 Anthropic API 兼容中转（七牛云、EasyClaude 等）使用 Claude Opus/Sonnet/Haiku 模型。中转差异由 assets/profiles/<name>.json 描述，加新中转=加一份 profile。当用户要求"配置 claude code""claude 走中转/七牛云/easyclaude""复现 claude code 环境"或 claude 连不上中转时使用。走 Anthropic /v1/messages，与 codex（Responses API）不同——chat/anthropic 兼容中转都能用。
compatibility: 需要 Node.js（npm 装）。Windows 用 Git Bash（Unix 语法）。已在 Linux/WSL + Claude Code 2.1.150、七牛云 (api.qnaigc.com) 上端到端验证。
---

# 配置 Claude Code 走中转

在新机器上把 Claude Code CLI 配好，走某个 **Anthropic API 兼容**中转。按顺序执行，每步都有验证。

配置目录 `$CLAUDE = ~/.claude`（Windows：`%USERPROFILE%\.claude`），主配置文件 `~/.claude/settings.json`。

## 0. 选择或新建 profile（中转差异都在这）

skill 把「中转特有的东西」抽进 `assets/profiles/<name>.json`，正文和模板只认占位符。**先确定用哪个**：

- 已有 profile（`qiniu` / `easyclaude`）：直接用，跳到第 1 步。
- 新中转：先按文末 **「新中转接入 playbook」** 实测产出 profile，再回第 1 步。

profile 字段（以 `assets/profiles/qiniu.json` 为准）：
```jsonc
{
  "name": "qiniu",
  "displayName": "Qiniu (七牛云)",
  "baseUrl": "https://api.qnaigc.com",        // ⭐ 不带 /v1（Claude Code 自拼 /v1/messages）
  "key": { "mode": "env", "ref": "QINIU_API_KEY" },  // 或 {"mode":"inline","value":"sk-..."}
  "models": {
    "opus":   { "id": "claude-opus-4-8" },     // 角色 -> 该中转实际存在的 id
    "sonnet": { "id": "claude-4.6-sonnet" },
    "haiku":  { "id": "claude-haiku-4-5" }      // 兼作 small/fast 模型
  },
  "default": "opus"                            // 主模型用哪个角色
}
```

> ⚠️ **Claude Code 与 codex 的关键区别**：Claude Code 走 **Anthropic 原生 `/v1/messages`**，不是 codex 的 Responses API。所以七牛云、EasyClaude 这类有 anthropic 兼容端点的中转**都能用 Claude Code**（但用不了 codex）。反过来只有 Responses 端点的中转（如 necodex）能配 codex 却配不了 Claude Code。

## 1. 安装 Claude Code

**先查是否已装**：
```bash
command -v claude && claude --version
```
未装则（官方安装脚本，或 npm）：
```bash
curl -fsSL https://claude.ai/install.sh | bash    # macOS/Linux
# 或： npm install -g @anthropic-ai/claude-code
hash -r; claude --version
```

## 2. 查中转真实支持哪些 Claude 模型（别凭记忆）

```bash
# KEY 按 profile.key 解析：env 模式用 $<ref>，inline 用其值
for m in claude-opus-4-8 claude-4.6-sonnet claude-haiku-4-5; do
  code=$(curl -s -m 20 -o /dev/null -w "%{http_code}" "<profile.baseUrl>/v1/messages" \
    -H "Authorization: Bearer $KEY" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" \
    -d "{\"model\":\"$m\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}")
  echo "$m -> $code"
done
```
`200` 的 id 才能填进 profile.models。`400 no available channels` = 该中转没有这个模型，换一个。

## 3. 写 `~/.claude/settings.json`

用 [assets/settings.json](assets/settings.json) 作模板，按 profile 替换占位符：

| 占位符 | 替换成 |
|---|---|
| `__PROFILE_BASEURL__` | `profile.baseUrl`（**不带 `/v1`**，客户端自拼 `/v1/messages`） |
| `__PROFILE_KEY_VALUE__` | env 模式填 `profile.key.ref` 对应变量的**值**；inline 模式填 `profile.key.value` |
| `__OPUS_ID__` / `__SONNET_ID__` / `__HAIKU_ID__` | 各角色的 id |
| `__DEFAULT_ID__` | `profile.default` 指向角色的 id（顶层 `model` 字段，决定默认模型） |

要点：
- `ANTHROPIC_BASE_URL` **不带 `/v1`** —— 带了会变成 `/v1/v1/messages` 报错。
- 鉴权走 `ANTHROPIC_AUTH_TOKEN`（中转通常 `Bearer` 与 `x-api-key` 两种头都接受）。
- `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` 把 Claude Code 内部的模型别名重定向到中转实际 id；`ANTHROPIC_SMALL_FAST_MODEL` 给后台小任务用便宜模型（haiku）。
- **已有 settings.json 时只合并 `env` 块与 `model` 字段**，别覆盖用户已有的 `hooks`、`permissions` 等。

> **key 存哪**：settings.json 的 `env.ANTHROPIC_AUTH_TOKEN` 是**明文**。文件须 `chmod 600`，别提交公开仓库。
> 想彻底不落盘：settings.json 里去掉 `ANTHROPIC_AUTH_TOKEN`，改在 shell 里 `export ANTHROPIC_AUTH_TOKEN=...`（Claude Code 读环境变量）。env 模式（profile.key.mode=env）推荐后者。

## 4. 验证

运行 [scripts/verify.sh](scripts/verify.sh)（脚本自动从同名 profile 读 baseUrl/模型/key，**用隔离 HOME 端到端测，不碰你真实的 `~/.claude`**）：
```bash
export QINIU_API_KEY=<KEY>
PROFILE=qiniu bash scripts/verify.sh
```
它校验 claude 已装、`/v1/messages` 对各模型连通、并用 `claude -p` 实测默认模型返回 `CLAUDE_RELAY_OK`。

手动等价（会用你真实的 settings.json）：
```bash
claude -p "reply with exactly: CLAUDE_RELAY_OK"
```

> ⚠️ 首次跑 Claude Code 会卡在 onboarding 交互。非交互场景用 `claude -p "..." < /dev/null`，或先手动跑一次过引导。

## 新中转接入 playbook（产出一份 profile）

给定 key + baseUrl + 候选模型，实测产出 `assets/profiles/<name>.json`：
1. **确认有 anthropic 端点**（第 2 步）：`<baseUrl>/v1/messages` 对候选 Claude 模型发一发。都非 200 → 这个中转没有 anthropic 兼容端点，Claude Code 用不了（可能得走别的 agent）。
2. **查真实模型 id**：opus/sonnet/haiku 映射到返回 `200` 的 id。
3. **baseUrl 是否带 `/v1`**：Claude Code 自拼 `/v1/messages`，所以 profile.baseUrl 写到域名为止、**不带 `/v1`**。
4. **key 模式**：默认 `{"mode":"env","ref":"<RELAY>_API_KEY"}`；用户坚持明文再 inline。
5. 写 profile → 按第 3 步套模板 → `PROFILE=<name> bash scripts/verify.sh` 端到端 → 通过后标 `verified`。

> ⚠️ 提醒：同一个中转对不同 agent 走不同协议。七牛云：Claude Code 走 anthropic ✅、pi/opencode 走 chat+anthropic ✅、codex 走 responses ❌（无此端点）。选 agent 前先确认端点。

## 常见问题

| 现象 | 解决 |
|---|---|
| 请求 404 / 路径含 `/v1/v1/messages` | `ANTHROPIC_BASE_URL` 带了 `/v1`，去掉（profile.baseUrl 不含 /v1） |
| 401 / 403 | key 错或没被中转接受；确认用 `ANTHROPIC_AUTH_TOKEN`（不是 `ANTHROPIC_API_KEY`） |
| `400 no available channels for model X` | 中转没有该模型，第 2 步换一个存在的 id |
| claude 启动卡住不响应 | 首次 onboarding 交互；用 `claude -p "..." < /dev/null` 或先手动过引导 |
| 模型没走中转（还是官方） | settings.json 的 `env.ANTHROPIC_BASE_URL` 没生效；确认文件路径 `~/.claude/settings.json` 且 JSON 合法 |

## 安全

settings.json 的 `env.ANTHROPIC_AUTH_TOKEN` 明文落盘，须 `chmod 600`，别入公开仓库。更安全的做法是不写进文件、改用 shell `export`。
Claude Code 以完整系统权限运行；装第三方 skill/插件前审阅来源。
