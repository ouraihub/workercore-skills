---
name: setup-pi-relay
description: 在一台新机器上安装并配置 Pi coding agent，使其通过 OpenAI/Anthropic 兼容中转（EasyClaude、七牛云等）使用 Claude Opus、GPT-5 等模型。中转差异由 assets/profiles/<name>.json 描述，加新中转=加一份 profile。当用户要求"配置 pi""装 pi""pi 走中转/easyclaude/七牛云""复现 pi 环境"或 pi 报 403/无模型可用时使用。包含已验证的双 provider 分流配置和 OpenAI-SDK User-Agent 被 WAF 拦截（403）的修复方法。
compatibility: 需要 Node.js；推荐 bun 安装（见第 1 步）。Windows 用 Git Bash（Unix 语法）。已在 Windows 10 + pi 0.80.3、及 Linux/WSL + pi 0.80.6 上验证。
---

# 配置 Pi 走中转

在新机器上把 Pi coding agent 配好，走某个 OpenAI/Anthropic 兼容中转。按顺序执行，每步都有验证。
**最关键的坑在第 4 步（UA 403），务必执行其中的确认与覆盖。**

配置目录 `$PI = ~/.pi/agent`（Windows：`%USERPROFILE%\.pi\agent`）。

## 0. 选择或新建 profile（中转差异都在这）

skill 把「中转特有的东西」抽进 `assets/profiles/<name>.json`，正文和模板只认占位符。**先确定用哪个**：

- 已有 profile（如 `easyclaude`）：直接用，跳到第 1 步。
- 新中转：先按文末 **「新中转接入 playbook」** 实测产出 profile，再回第 1 步。

profile 字段（以 `assets/profiles/easyclaude.json` 为准）：
```jsonc
{
  "name": "easyclaude",                       // pi provider ID 前缀
  "baseUrl": "https://api.easyclaude.com",    // 不含 /v1
  "key": { "mode": "env", "ref": "EASYCLAUDE_API_KEY" },  // 或 {"mode":"inline","value":"sk-..."}
  "apis": {                                   // ⭐ 该中转暴露哪些端点 —— 决定 provider 分流
    "openai":    { "enabled": true, "pathV1": true },   // /v1/chat/completions
    "anthropic": { "enabled": true, "pathV1": false }   // /messages，不带 /v1；只有 openai 兼容时 enabled=false
  },
  "models": {
    "opus":    { "id": "claude-opus-4-8", "via": "anthropic", ... },  // via 决定走哪个 provider
    "gptHigh": { "id": "gpt-5.5", "via": "openai", ... },
    "gptCheap":{ "id": "gpt-5.4", "via": "openai", ... }
  },
  "quirks": { "userAgentWafBlock": true, "userAgentValue": "pi/0.80.3" }
}
```

> ⭐ **关键分流逻辑**：pi 双 provider 分流依据 `profile.apis`。
> - `apis.anthropic.enabled = true`（如 EasyClaude）：建两个 provider —— `<name>`（openai-completions，放 gpt）+ `<name>-anthropic`（anthropic-messages，放 opus）。opus 走原生 thinking + prompt caching。
> - `apis.anthropic.enabled = false`（**只有 OpenAI 兼容端点的中转**）：只建 `<name>` 一个 provider，**Claude 模型也当作 openai-completions 放进去**（把 opus 的 `via` 视作 openai）。此时不写 `-anthropic` provider。

## 1. 安装 pi

**先查是否已装**，避免复用到慢盘/旧版本：
```bash
command -v pi && pi --version   # 已装则看位置与版本；在 /mnt/* 挂载盘上建议按下方重装到原生盘
```

**推荐用 bun 装**（原生盘、无权限坑、自动跳过 postinstall）：
```bash
bun --version || npm install -g bun     # 没 bun 先装
bun install -g @earendil-works/pi-coding-agent
hash -r; command -v pi; pi --version    # 应指向 ~/.bun/bin/pi，已验证 0.80.6
```
> bun 默认会 "Blocked N postinstalls"，等价于 npm 的 `--ignore-scripts`，符合本 skill 需求。
>
> ⚠️ 坑〇（Linux/WSL）：别用 `npm install -g`。多数 Linux 发行版 npm 全局前缀是 `/usr`（root 所有），`npm install -g` 直接报 `EACCES/permission denied`。用上面的 `bun install -g` 绕过，无需 sudo。
>
> ⚠️ 安装位置（WSL）：别装/复用 `/mnt/c`、`/mnt/d` 等 Windows 挂载盘上的 pi —— 经 9p 协议挂载，文件 I/O 明显慢，pi 启动和跑 skill 都拖。装到 WSL 原生盘（`bun install -g` 默认落在 `~/.bun/bin`）。若机器上已有挂载盘的旧 pi，确保 PATH 里 `~/.bun/bin` 优先级更高，或删掉旧的。

若坚持用 npm（非 root-owned 前缀，如 Windows 或自定义 prefix）：
```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
```

## 2. 查中转真实支持哪些模型（别凭记忆）

```bash
# KEY 按 profile.key 解析：env 模式用 $<ref>，inline 用其值
curl -s "<profile.baseUrl>/v1/models" -H "Authorization: Bearer $KEY" \
  | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>JSON.parse(d).data.forEach(m=>console.log(m.id)))"
```
profile.models 每个角色的 `id` 必须在这个列表里。只有列表里的 id 才能配。

## 3. 写 `~/.pi/agent/models.json`

**双 provider 分流**（官方推荐；不要硬塞进一个 API）：Claude 走 `anthropic-messages`（原生 thinking + prompt caching），GPT 走 `openai-completions`（原生 reasoning_effort）—— **前提是中转有 anthropic 端点**（见第 0 步分流逻辑）。
注意两个 baseUrl 不同：openai 端点按 `apis.openai.pathV1` **带/不带 `/v1`**，anthropic 端点按 `apis.anthropic.pathV1`（EasyClaude 不带）。
`headers.user-agent` 那行是第 4 步的修复，`quirks.userAgentWafBlock=true` 时**必须保留**。

用 [assets/models.json](assets/models.json) 作模板，按 profile 替换占位符后写入 `~/.pi/agent/models.json`：

| 占位符 | 替换成 |
|---|---|
| `__PROFILE_NAME__` | `profile.name` |
| `__PROFILE_KEY_REF__` | `profile.key.ref`（env 模式，pi 原生支持 `$VAR`）；**inline** 改写明文 |
| `__PROFILE_BASEURL_V1__` | openai 端点：`baseUrl`(+`/v1` 若 `apis.openai.pathV1`) |
| `__PROFILE_BASEURL_ANTHROPIC__` | anthropic 端点：`baseUrl`(+`/v1` 若 `apis.anthropic.pathV1`) |
| `__UA_VALUE__` | `quirks.userAgentValue`（无 WAF 坑时也可留，无副作用） |
| `__OPUS_ID__` / `__GPTHIGH_ID__` / `__GPTCHEAP_ID__` 等 | 对应角色 id/name |

> **中转只有 OpenAI 兼容端点时**（`apis.anthropic.enabled=false`）：删掉模板里整个 `__PROFILE_NAME__-anthropic` provider 块，把 opus 的 model 对象挪进 `__PROFILE_NAME__` 的 `models` 数组（即 Claude 也走 openai-completions）。

## 4. ⚠️ 关键坑：403 Your request was blocked

**现象**：models.json 配好、`pi --list-models` 能看到模型，但一发对话就 `403 Your request was blocked.`

**根因**：Pi 底层用 OpenAI 官方 JS SDK，自动带 `user-agent: OpenAI/JS <ver>`，被某些中转的 WAF 拉黑。curl/裸 Node fetch 都能过，只有这个 UA 被拦。**是否中招因中转而异**，profile 的 `quirks.userAgentWafBlock` 记录结论。

**确认**（对新中转必做；KEY/URL 按 profile）：
```bash
KEY="$<profile.key.ref>"; U="<profile.baseUrl>/v1/chat/completions"; M="<profile.models.gptHigh.id>"
B="{\"model\":\"$M\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}"
curl -s -o /dev/null -w "plain: %{http_code}\n"     "$U" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$B"
curl -s -o /dev/null -w "openai-ua: %{http_code}\n" "$U" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -H "user-agent: OpenAI/JS 6.26.0" -d "$B"
curl -s -o /dev/null -w "pi-ua: %{http_code}\n"     "$U" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -H "user-agent: pi/0.80.3" -d "$B"
```
若 `plain 200` / `openai-ua 403` / `pi-ua 200` → 证实 UA 问题，`quirks.userAgentWafBlock=true`。三个都 200 则该中转不拦（覆盖仍无害）。

**解法**：models.json 每个 provider 的 `headers` 里覆盖 UA（模板已含 `__UA_VALUE__`）：
```json
"headers": { "user-agent": "pi/0.80.3" }
```
`x-stainless-*` 头无害，不用动。这是中转侧 WAF 策略，非 Pi bug；若中转日后放开该 UA，这行也无副作用。

## 5. 写 `~/.pi/agent/settings.json`

默认用 opus（编码最强），medium 推理，Ctrl+P 三模型循环。
用 [assets/settings.json](assets/settings.json) 按 profile 替换占位符后写入 `~/.pi/agent/settings.json`。

| 占位符 | 替换成 |
|---|---|
| `__PROFILE_NAME__` | `profile.name`（模板里 `__PROFILE_NAME__-anthropic` 是 opus 的 provider） |
| `__OPUS_ID__` / `__GPTHIGH_ID__` / `__GPTCHEAP_ID__` | 对应角色 id |

> **只有 OpenAI 兼容端点时**：把 `defaultProvider` 和 `enabledModels` 里的 `__PROFILE_NAME__-anthropic` 改成 `__PROFILE_NAME__`（opus 也在 openai provider 下）。
> 要点：`retry.provider.maxRetries` **必须保持 0**（否则 SDK 层会吞掉超额错误、卡住 agent）。

## 6. 验证

运行 [scripts/verify.sh](scripts/verify.sh)（脚本自动从同名 profile 读 baseUrl/模型/key/apis，并据此决定测哪些 provider）：
```bash
# env 模式：先 export profile.key.ref 指定的变量
export EASYCLAUDE_API_KEY=<KEY>
PROFILE=easyclaude bash scripts/verify.sh
```
它校验两个 JSON、UA 三连、列模型、并对应测 default/gptHigh/opus。全部返回 `PI_*_OK` 即成功。

手动等价验证：
```bash
pi --list-models | grep -iE "<profile.name>|opus|gpt-5"
pi -p --no-session "reply with exactly: PI_DEFAULT_OK"
pi -p --no-session --provider <profile.name> --model <gptHigh.id> "reply with exactly: PI_GPT_OK"
# opus provider：anthropic 启用时是 <name>-anthropic，否则是 <name>
pi -p --no-session --provider <opus-provider> --model <opus.id> "reply: PI_CLAUDE_OK"
```

## 7. 可选：联网能力

```bash
pi install npm:pi-web-access   # 零配置，默认用 Exa，无需 key；注册 web_search / fetch_content
```

## 新中转接入 playbook（产出一份 profile）

给定 key + baseUrl + 候选模型，实测产出 `assets/profiles/<name>.json`：
1. **查真实模型 id**（第 2 步）：角色 opus/gptHigh/gptCheap 映射到列表里**实际存在**的 id。
2. **探测端点形态**：
   - openai：`<baseUrl>/v1/chat/completions` 发一发，200 → `apis.openai.pathV1=true`；若 `/v1` 报 404 试不带 `/v1`。
   - anthropic：`<baseUrl>/messages`（带 `anthropic-version: 2023-06-01` 头）发一发；再试 `<baseUrl>/v1/messages`。哪个 200 就是有 anthropic 端点 → `apis.anthropic.enabled=true` + 对应 `pathV1`。**都非 200 → `enabled=false`**（该中转只 OpenAI 兼容，Claude 走 openai-completions）。
3. **UA 三连**（第 4 步）→ 判 `quirks.userAgentWafBlock` 与要覆盖成什么。
4. **key 模式**：默认 `{"mode":"env","ref":"<RELAY>_API_KEY"}`；用户坚持明文再 inline。
5. 写 profile → 按第 3/5 步套模板（注意 anthropic 是否启用的分流）→ `PROFILE=<name> bash scripts/verify.sh` 端到端 → 通过后标 `verified`。

> ⚠️ 提醒：中转「支持 Claude 模型」≠「有 Anthropic-native 端点」。很多中转把 Claude 挂在 OpenAI 兼容端点上。第 2 步必须实测 `/messages`，不能假设。

## 常见问题

| 现象 | 解决 |
|---|---|
| `npm install -g` 报 EACCES/权限错误 (Linux/WSL) | 坑〇：全局前缀是 root 的 `/usr`，改用 `bun install -g @earendil-works/pi-coding-agent`（见第 1 步） |
| pi 启动/跑 skill 明显慢 (WSL) | pi 装在 `/mnt/*` 挂载盘（9p I/O 慢）。重装到原生盘 `~/.bun/bin`，并让其在 PATH 中优先 |
| `403 Your request was blocked` | 第 4 步：models.json 加 `headers.user-agent`（`quirks.userAgentWafBlock`） |
| `No models available` | settings.json 没设 defaultProvider/defaultModel；或 models.json 的 apiKey 缺失/env 变量没 export |
| Claude provider 401/403 | anthropic 端点 baseUrl 的 `/v1` 带错了（按 `apis.anthropic.pathV1`）；或该中转根本没 anthropic 端点，应设 `enabled=false` 走 openai |
| 模型在 list 里但 available=no | 该 provider apiKey 没填/env 没解析 |

## 安全

env 模式（`"apiKey": "$VAR"`，pi 原生支持）key 不落盘，推荐。inline 模式明文写进 `models.json`，须 `chmod 600` 且别提交公开仓库；profile 若用 inline 也含明文，同样别入公开仓。
Pi 扩展/skill 以完整系统权限运行，装第三方包前审阅来源。
