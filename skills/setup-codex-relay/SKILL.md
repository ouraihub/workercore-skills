---
name: setup-codex-relay
description: 在一台新机器上安装并配置 codex-cli（OpenAI Codex CLI），使其通过 OpenAI Responses API 兼容中转（如 NeCodeX、七牛云 bypass 端点）使用 GPT-5 系模型。中转差异由 assets/profiles/<name>.json 描述，加新中转=加一份 profile。当用户要求"配置 codex""装 codex""codex 走中转/七牛云""复现 codex 环境"或 codex 报 provider/wire_api 错误时使用。关键约束：codex 0.133.0 起仅支持 wire_api=responses，中转必须暴露 responses 端点（标准 /v1/responses 或七牛那样的 /bypass/openai/v1 专用端点）。
compatibility: 需要 Node.js；推荐 bun 安装（见第 1 步）。Windows 用 Git Bash（Unix 语法）。已在 Linux/WSL + codex-cli 0.133.0 上验证。
---

# 配置 codex 走中转

在新机器上把 codex-cli 配好，走某个 **OpenAI Responses API 兼容**中转。按顺序执行，每步都有验证。

配置目录 `$CODEX = ~/.codex`（Windows：`%USERPROFILE%\.codex`），主配置文件 `~/.codex/config.toml`。

## 0. 选择或新建 profile（中转差异都在这）

skill 把「中转特有的东西」抽进 `assets/profiles/<name>.json`，正文和模板只认占位符。**先确定用哪个**：

- 已有 profile（`necodex` / `qiniu`）：直接用，跳到第 1 步。
- 新中转：先按文末 **「新中转接入 playbook」** 实测产出 profile，再回第 1 步。

profile 字段（以 `assets/profiles/necodex.json` 为准）：
```jsonc
{
  "name": "necodex",                             // codex provider ID（[model_providers.<name>]）
  "displayName": "NeCodeX API",
  "baseUrl": "https://fast.sbbbbbbbbb.xyz/v1",    // ⭐ 必须带 /v1（codex 只在其后拼 /responses）
  "key": { "mode": "env", "ref": "NECODEX_API_KEY" },  // 或 {"mode":"inline","value":"sk-..."}
  "codexAuth": "env_key",                        // 鉴权模式：env_key（默认）| openai_auth（七牛 bypass 用）
  "apis": { "responses": { "enabled": true } },   // codex 唯一能用的协议
  "models": {
    "main": { "id": "gpt-5.4", "reasoning": "high", ... },  // 默认模型
    "high": { "id": "gpt-5.5", "reasoning": "high", ... },  // 可选更强档
    "ultra": { "id": "openai/gpt-5.6-sol", "reasoning": "high", ... }  // 可选，5.6 主打编码；七牛 id 须带 openai/ 前缀
  },
  "quirks": { "disableResponseStorage": true }
}
```

> ⚠️ **codex 的硬约束（和 pi/opencode 不同，务必先懂）**：
> - codex 0.133.0 起**只支持 `wire_api = "responses"`**（OpenAI Responses API）。`chat` 已被移除，写了会报 `` `wire_api = "chat"` is no longer supported ``。
> - 所以中转**必须暴露 Responses 端点**。标准是 `/v1/responses`；也有中转把它挂在**专用 bypass 路径**上（如七牛 `/bypass/openai/v1/responses`——标准 `/v1/responses` 反而 404）。只有 `/v1/chat/completions` 的纯 chat 中转（如 EasyClaude）用不了 codex。
> - codex **没有 Anthropic 协议**。Claude 模型只有在中转把 `claude-*` 也挂到 responses 端点时才可达（少见）。多数中转对 Claude 走 responses 会返回 `500 not implemented` → 本类 profile 只放 GPT 系。
> - **鉴权两种模式**（profile.codexAuth）：`env_key`（默认，config 写 `env_key`，从环境变量读 key）；`openai_auth`（config 写 `requires_openai_auth = true`，key 写进 `~/.codex/auth.json`）。七牛 bypass 端点要求后者。

## 1. 安装 codex

**先查是否已装**：
```bash
command -v codex && codex --version
```

**推荐用 bun 装**（原生盘、无权限坑）：
```bash
bun --version || npm install -g bun     # 没 bun 先装
bun install -g @openai/codex
hash -r; command -v codex; codex --version
```
> ⚠️ 坑〇（Linux/WSL）：别用 `npm install -g`。多数 Linux 发行版 npm 全局前缀是 `/usr`（root 所有），直接报 `EACCES`。用 `bun install -g` 绕过，无需 sudo。
>
> ⚠️ 安装位置（WSL）：别装到 `/mnt/c`、`/mnt/d` 等挂载盘（9p I/O 慢）。装到原生盘（bun 默认 `~/.bun/bin`）。
>
> 已装的 codex 可自更新：`codex update`。

若坚持用 npm（非 root-owned 前缀，如 Windows）：
```bash
npm install -g @openai/codex
```

## 2. 查中转真实支持哪些模型 + 确认走的是 responses

```bash
# KEY 按 profile.key 解析：env 模式用 $<ref>，inline 用其值
curl -s "<profile.baseUrl>/models" -H "Authorization: Bearer $KEY" \
  | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>JSON.parse(d).data.forEach(m=>console.log(m.id)))"
```
**再实测 responses 端点**（这是 codex 真正走的端点，`/v1/models` 列表不代表 responses 可用）：
```bash
curl -s -o /dev/null -w "HTTP %{http_code}\n" "<profile.baseUrl>/responses" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"<main.id>","input":"hi","max_output_tokens":16}'
```
- `200` → 该模型可用，填进 profile.models。
- `404` → 这条路径没有 responses。**先别急着判死**：有的中转把 responses 挂在别的路径（如七牛 `https://api.qnaigc.com/bypass/openai/v1/responses` 是 200，而标准 `https://api.qnaigc.com/v1/responses` 是 404）。把 profile.baseUrl 指到那条 bypass 路径即可。都试过还 404 才是真不支持。
- `500 not implemented` → 该模型（常见于 Claude 系）不支持 responses，换 GPT 系。

## 3. 写 `~/.codex/config.toml`

用 [assets/config.toml](assets/config.toml) 作模板，按 profile 替换占位符：

| 占位符 | 替换成 |
|---|---|
| `__PROFILE_NAME__` | `profile.name`（`model_provider` 与 `[model_providers.<name>]`） |
| `__PROFILE_DISPLAY__` | `profile.displayName` |
| `__PROFILE_BASEURL_V1__` | `profile.baseUrl`（**已含 `/v1` 或 bypass 路径**，codex 自动拼 `/responses`） |
| `__PROFILE_KEY_REF__` | `profile.key.ref`（仅 env_key 模式，codex 从该环境变量读 key） |
| `__MAIN_ID__` / `__MAIN_REASONING__` | `profile.models.main` 的 id / reasoning |

要点：
- `wire_api = "responses"` **写死**（唯一支持值）。
- `disable_response_storage = true` **必须保留** —— 中转不实现 OpenAI 服务端会话存储，不关会每轮被拒。
- **鉴权按 `profile.codexAuth` 二选一**：
  - `env_key`（默认）：config 里写 `env_key = "<ref>"`，codex 从环境变量读 key，明文不落盘（推荐）。
  - `openai_auth`（七牛 bypass 端点用）：config 里写 `requires_openai_auth = true`（**删掉 env_key**），把 key 写进 `~/.codex/auth.json`：
    ```json
    {"auth_mode":"apikey","OPENAI_API_KEY":"sk-..."}
    ```
    `chmod 600 ~/.codex/auth.json`，别提交公开仓库。这是官方 `qiniu-coding-helper` 的写法。
- **已有 config.toml 时只合并三处**（`model` / `model_provider` / `[model_providers.<name>]`），别覆盖用户已有的 `[projects.*]`、`[tui.*]`、`approval_policy`、`sandbox_mode` 等。

> **inline（明文）key 模式**：不写 `env_key`，改用 `experimental_bearer_token = "sk-..."`（codex 官方标注 discouraged，仅在用户坚持时用）。文件须 `chmod 600`，别提交公开仓库。env 模式（默认）更安全。

## 4. 验证

运行 [scripts/verify.sh](scripts/verify.sh)（脚本自动从同名 profile 读 baseUrl/模型/key/codexAuth，**用隔离 CODEX_HOME 端到端测，不碰你真实的 `~/.codex`**）：
```bash
# env 模式：先 export profile.key.ref 指定的变量
export NECODEX_API_KEY=<KEY>
PROFILE=necodex bash scripts/verify.sh

# 七牛（openai_auth 模式，脚本自动写临时 auth.json）：
export QINIU_API_KEY=<KEY>
PROFILE=qiniu bash scripts/verify.sh
```
它校验 codex 已装、responses 端点连通、并用 `codex exec` 实测 main/high/ultra 各档返回 `CODEX_*_OK`。

手动等价验证（会用你真实的 config.toml）：
```bash
codex exec --skip-git-repo-check "reply with exactly: CODEX_MAIN_OK" < /dev/null
codex exec --skip-git-repo-check -c model='"<high.id>"' "reply with exactly: CODEX_HIGH_OK" < /dev/null
```
> ⚠️ `codex exec` 会阻塞读 stdin。非交互调用**必须 `< /dev/null`**，否则会一直卡住直到超时。

## 新中转接入 playbook（产出一份 profile）

给定 key + baseUrl + 候选模型，实测产出 `assets/profiles/<name>.json`：
1. **找到 responses 端点**（第 2 步）：先试标准 `<baseUrl>/responses`。若 `404`，再试 bypass 路径（如 `/bypass/openai/v1/responses`）。标准和 bypass 都 `404` 才是这个中转 codex 用不了、**到此为止**。
2. **查真实模型 id**：把 main/high/ultra 映射到 responses 返回 `200` 的 id。Claude 系多半 `500 not implemented`，别放进去。
3. **base_url 写到 responses 前一段**：codex 只在 base_url 后拼 `/responses`。标准端点写到 `/v1`；bypass 端点写到 `/bypass/openai/v1`。
4. **鉴权模式（codexAuth）**：普通中转用 `env_key`（默认）。若中转要求 OpenAI 式登录鉴权（如七牛 bypass），用 `openai_auth` → config 写 `requires_openai_auth=true` + `~/.codex/auth.json`。curl 用 Bearer 能过、但 codex 报鉴权错时，多半要切 `openai_auth`。
5. **key 存法**：env 模式 `{"mode":"env","ref":"<RELAY>_API_KEY"}`；用户坚持明文再 inline。
6. 写 profile → 按第 3 步套模板 → `PROFILE=<name> bash scripts/verify.sh` 端到端 → 通过后标 `verified`。

> ⚠️ 提醒：codex 与 pi/opencode 的中转**协议不通用**。pi/opencode 吃 chat-completions（+ 可选 anthropic），codex 只吃 responses。同一个中转对不同 agent 走不同端点——七牛就是例子：pi/opencode 走 `/v1/chat`、claude 走 `/v1/messages`、codex 走 `/bypass/openai/v1/responses`。选 agent 前先确认它要的端点存在。

## 常见问题

| 现象 | 解决 |
|---|---|
| `` `wire_api = "chat"` is no longer supported `` | codex 0.133.0+ 只认 `responses`。中转若只有 chat 端点则不可用；改用 pi/opencode skill |
| 标准 `/v1/responses` 返回 404 | 先试 bypass 路径（如七牛 `/bypass/openai/v1/responses`）。都 404 才是真没有 Responses API |
| codex 鉴权失败但 curl Bearer 能过 | 中转要 OpenAI 式登录鉴权；改 `codexAuth=openai_auth`：config 写 `requires_openai_auth=true`、key 进 `~/.codex/auth.json` |
| `codex exec` 卡住不返回（超时 124） | 漏了 `< /dev/null`；codex 会阻塞读 stdin |
| Claude 模型 `500 not implemented` | 中转未为 Claude 实现 responses；codex 也无 anthropic 协议。profile 只放 GPT 系 |
| 每轮请求被拒 / 会话报错 | 漏了 `disable_response_storage = true`（中转无服务端存储） |
| `npm install -g` 报 EACCES (Linux/WSL) | 坑〇：全局前缀是 root 的 `/usr`，改用 `bun install -g @openai/codex` |
| codex 启动/跑慢 (WSL) | codex 装在 `/mnt/*` 挂载盘。重装到原生盘 `~/.bun/bin` |

## 安全

env 模式（`env_key`）key 不落盘，推荐。`openai_auth` 模式 key 明文写进 `~/.codex/auth.json`、inline（`experimental_bearer_token`）明文写进 `config.toml`——两者都须 `chmod 600` 且别提交公开仓库；profile 若用 inline 也含明文，同样别入公开仓。
codex 默认 `sandbox_mode` 决定它能否写文件/联网，`approval_policy` 决定是否每步询问 —— 新机器建议先用较严档位，确认行为后再放宽。
