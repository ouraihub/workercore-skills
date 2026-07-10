---
name: setup-pi-easyclaude
description: 在一台新机器上安装并配置 Pi coding agent，使其通过 EasyClaude 中转（api.easyclaude.com）使用 Claude Opus 4.8 与 GPT-5.4/5.5。当用户要求"配置 pi""装 pi""pi 走中转""复现 pi 环境"或 pi 报 403/无模型可用时使用。包含已验证的双 provider 分流配置和 OpenAI-SDK User-Agent 被 WAF 拦截（403）的修复方法。
compatibility: 需要 Node.js 与 npm；Windows 用 Git Bash（Unix 语法）。已在 Windows 10 + pi 0.80.3 验证。
---

# 配置 Pi 走 EasyClaude 中转

在新机器上把 Pi coding agent 配好，走 EasyClaude 中转。按顺序执行，每步都有验证。
**最关键的坑在第 4 步（403），务必执行其中的 UA 覆盖。**

前置：拿到 EasyClaude 的 API key（形如 `sk-...`）。下文命令里的 `<KEY>` 全部替换成真实 key。
配置目录 `$PI = ~/.pi/agent`（Windows：`%USERPROFILE%\.pi\agent`）。

## 1. 安装 pi

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
pi --version
```

## 2. 查中转真实支持哪些模型（别凭记忆）

```bash
curl -s "https://api.easyclaude.com/v1/models" -H "Authorization: Bearer <KEY>" \
  | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>JSON.parse(d).data.forEach(m=>console.log(m.id)))"
```
本配置用到：`claude-opus-4-8`、`gpt-5.4`、`gpt-5.5`。只有列表里的 id 才能配。

## 3. 写 `~/.pi/agent/models.json`

**双 provider 分流**（官方推荐；不要硬塞进一个 API）：Claude 走 `anthropic-messages`（原生 thinking + prompt caching），GPT 走 `openai-completions`（原生 reasoning_effort）。
注意两个 baseUrl 不同：openai 端点**带 `/v1`**，anthropic 端点**不带 `/v1`**。
`headers.user-agent` 那行是第 4 步的修复，**必须保留**。

用 [assets/models.json](assets/models.json) 作为模板，把 `<KEY>` 替换后写入 `~/.pi/agent/models.json`。

## 4. ⚠️ 关键坑：403 Your request was blocked

**现象**：models.json 配好、`pi --list-models` 能看到模型，但一发对话就 `403 Your request was blocked.`

**根因**：Pi 底层用 OpenAI 官方 JS SDK，自动带 `user-agent: OpenAI/JS <ver>`，被 EasyClaude 的 WAF 拉黑。curl/裸 Node fetch 都能过，只有这个 UA 被拦。

**确认**（key 换自己的）：
```bash
KEY="<KEY>"; U="https://api.easyclaude.com/v1/chat/completions"; B='{"model":"gpt-5.5","messages":[{"role":"user","content":"hi"}],"max_tokens":5}'
curl -s -o /dev/null -w "plain: %{http_code}\n"     "$U" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$B"
curl -s -o /dev/null -w "openai-ua: %{http_code}\n" "$U" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -H "user-agent: OpenAI/JS 6.26.0" -d "$B"
curl -s -o /dev/null -w "pi-ua: %{http_code}\n"     "$U" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -H "user-agent: pi/0.80.3" -d "$B"
```
预期：`plain 200` / `openai-ua 403` / `pi-ua 200` → 证实是 UA 问题。

**解法**：models.json 每个 provider 的 `headers` 里覆盖 UA（模板已含）：
```json
"headers": { "user-agent": "pi/0.80.3" }
```
`x-stainless-*` 头无害，不用动。这是中转侧 WAF 策略，非 Pi bug；若中转日后放开该 UA，这行也无副作用。

## 5. 写 `~/.pi/agent/settings.json`

默认用 Claude Opus 4.8（编码最强），medium 推理，Ctrl+P 三模型循环。
用 [assets/settings.json](assets/settings.json) 直接写入 `~/.pi/agent/settings.json`。
要点：`retry.provider.maxRetries` **必须保持 0**（否则 SDK 层会吞掉超额错误、卡住 agent）。

## 6. 验证

运行 [scripts/verify.sh](scripts/verify.sh)（先 `export EASYCLAUDE_KEY=<KEY>`）：
```bash
EASYCLAUDE_KEY=<KEY> bash scripts/verify.sh
```
它校验两个 JSON、列模型、并对三个 provider 各发一次非交互请求。全部返回对应 `PI_*_OK` 即成功。

手动等价验证：
```bash
pi --list-models | grep -iE "easyclaude|opus|gpt-5"
pi -p --no-session "reply with exactly: PI_DEFAULT_OK"
pi -p --no-session --provider easyclaude --model gpt-5.5 "reply with exactly: PI_GPT_OK"
pi -p --no-session --provider easyclaude-anthropic --model claude-opus-4-8 "reply: PI_CLAUDE_OK"
```

## 7. 可选：联网能力

```bash
pi install npm:pi-web-access   # 零配置，默认用 Exa，无需 key；注册 web_search / fetch_content
```

## 常见问题

| 现象 | 解决 |
|---|---|
| `403 Your request was blocked` | 第 4 步：models.json 加 `headers.user-agent` |
| `No models available` | settings.json 没设 defaultProvider/defaultModel；或 models.json 的 apiKey 缺失 |
| Claude provider 401/403 | anthropic 端点 baseUrl 误带了 `/v1`，改成 `https://api.easyclaude.com` |
| 模型在 list 里但 available=no | 该 provider apiKey 没填 |

## 安全

`models.json` 里 key 是明文（文件权限 0600）。别提交公开仓库。可改用 `"apiKey": "$EASYCLAUDE_API_KEY"` 从环境变量读。
Pi 扩展/skill 以完整系统权限运行，装第三方包前审阅来源。
