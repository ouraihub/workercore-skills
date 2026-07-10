---
name: setup-opencode-easyclaude
description: 在一台新机器上安装并配置 OpenCode，使其通过 EasyClaude 中转（api.easyclaude.com）使用 Claude Opus 4.8 与 GPT-5.4/5.5，并安装 oh-my-openagent(omo) 多 agent 插件、配好各 agent 的模型映射最佳实践。当用户要求"配置 opencode""装 opencode""opencode 走中转""装 omo/oh-my-openagent 插件""opencode 看不到模型/provider"或复现 opencode 环境时使用。包含已验证的自定义 provider 配置与多个安装器陷阱的修复。
compatibility: 需要 Node.js、bun（装 opencode + omo 安装器都用得上）。Windows 用 Git Bash（Unix 语法）。已在 Windows 10 + opencode 1.17.13、及 Linux/WSL + opencode 1.17.18 + oh-my-openagent 4.16.2 上验证。
---

# 配置 OpenCode 走 EasyClaude 中转 + oh-my-openagent 插件

在新机器上装好 OpenCode、走 EasyClaude 中转、装 omo 多 agent 插件并配好模型映射。
按顺序执行。**四个坑分别在第 3、5、6 步，务必照做。**

前置：拿到 EasyClaude 的 API key（`sk-...`）。下文 `<KEY>` 全部替换成真实 key。
配置目录 `$CFG = ~/.config/opencode`（Windows：`%USERPROFILE%\.config\opencode`，Git Bash 里即 `~/.config/opencode`）。

## 1. 安装 / 更新 opencode

**推荐用 bun 装**（bun 后面装 omo 也要用，一步到位）：
```bash
bun --version || npm install -g bun     # 没 bun 先装
bun install -g opencode-ai@latest
hash -r; opencode --version              # 已验证 1.17.13 / 1.17.18
```
bun 装到 `~/.bun/bin`（确保在 PATH 里）。

> ⚠️ 坑〇（Linux/WSL）：别用 `npm install -g`。多数 Linux 发行版 npm 全局前缀是 `/usr`（root 所有），`npm install -g` 直接报 `EACCES/permission denied` 装不上。用上面的 `bun install -g` 绕过，无需 sudo。
> Windows 坑：`npm install -g` 更新时可能报 `EPERM ... opencode.exe` 清理警告 —— exe 被占用导致临时目录没删，**不影响主安装**。先关掉运行中的 opencode，残留目录手动清：
> `rm -rf "$(dirname "$(which opencode)")/node_modules/.opencode-ai-"*`

## 2. 查中转真实支持哪些模型

```bash
curl -s "https://api.easyclaude.com/v1/models" -H "Authorization: Bearer <KEY>" \
  | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>JSON.parse(d).data.forEach(m=>console.log(m.id)))"
```
本配置用到：`claude-opus-4-8`、`gpt-5.4`、`gpt-5.5`。只有列表里的 id 才能配。

## 3. ⚠️ 坑一：provider ID 不能用保留名

`openai` / `anthropic` / `google` 是 opencode 内置保留 provider。用它们时 opencode 强制走内置 SDK（`openai` 走 `@ai-sdk/openai` 的 `/v1/responses`），**忽略你写的 baseURL**，导致中转不被调用、模型列表里看不到。

**必须用自定义 ID**（这里叫 `easyclaude`）+ `npm: "@ai-sdk/openai-compatible"` + baseURL **带 `/v1`**。

用 [assets/opencode.json](assets/opencode.json) 作模板，替换 `<KEY>` 后写入 `$CFG/opencode.json`。
（模板里也含 `plugin: ["oh-my-openagent@latest"]`，第 5 步的安装器会复用。若不装 omo，删掉该数组即可。）

验证：
```bash
node -e "const c=JSON.parse(require('fs').readFileSync(require('os').homedir()+'/.config/opencode/opencode.json','utf8'));console.log('provider:',Object.keys(c.provider).join(','))"
# 单模型连通
curl -s "https://api.easyclaude.com/v1/chat/completions" -H "Authorization: Bearer <KEY>" -H "Content-Type: application/json" \
  -d '{"model":"claude-opus-4-8","messages":[{"role":"user","content":"ping"}],"max_tokens":10}'
```

字段要点：`npm: "@ai-sdk/openai-compatible"`（走 `/v1/chat/completions`，opencode 内置无需 npm i）；baseURL 带 `/v1`；`models` 的 key 必须等于第 2 步的 id；`variants` 只给 gpt 系列配；opencode 内置 openai provider 才需要 `store:false`，兼容适配器不要加。

## 4. 确认 bun 可用（omo 安装器用 bunx）

第 1 步已装好 bun，这里只确认：
```bash
bun --version
```

## 5. ⚠️ 坑二 + 坑三：安装 omo 插件

```bash
cd "$CFG"
# 非交互安装。用自定义中转（非官方直连），三个官方 provider 全填 no。
bunx oh-my-openagent@latest install --no-tui --claude=no --gemini=no --copilot=no
```
安装器会：把插件写进 opencode.json 的 plugin 数组、生成 agent 映射文件、生成 `tui.json`。

> ⚠️ **文件名随版本变化**：老版本生成 `oh-my-openagent.jsonc`，**omo 4.16.x 生成 `oh-my-openagent.json`**（严格 JSON，不能带注释）。第 6 步以安装器实际生成的文件名为准。

**坑二**：安装器生成的映射文件里模型是 fallback（三个官方 provider 都填 no 时，omo 4.16.x 全填 `opencode/gpt-5-nano`；老版本是 `openai/gpt-5.4-pro`/`gpt-5.3-codex`）—— **无论哪个，都不是 `easyclaude/` 前缀，中转里也没这些模型**。照原样插件跑不起来，**必须用第 6 步覆盖它**。判断标准：只要模型前缀不是 `easyclaude/` 就是没修。

**坑三**：若目录里存在旧名文件 `oh-my-opencode.json[c]`，其检测优先级**高于** `oh-my-openagent.jsonc`，会覆盖新配置。删掉：
```bash
rm -f "$CFG/oh-my-opencode.json" "$CFG/oh-my-opencode.jsonc"
```

## 6. ⚠️ 坑四：覆盖 omo 映射文件（模型映射最佳实践）

依据官方 `agent-model-matching.md` / `overview.md`：
- **sisyphus**（主编排器）：官方优先级 1 = Claude Opus 4.7/4.8，且有 Claude 家族专用 prompt → `claude-opus-4-8`。
- **hephaestus**（编码）：官方明确 "needs GPT"，单一 GPT prompt，跨家族退化 → `gpt-5.5`。
- **prompt 家族边界**：sisyphus/hephaestus 的 prompt 绑定单一家族，不能乱换；atlas/prometheus/metis 会自动识别切换。
- **variant** 只对 gpt-5.4/gpt-5.5 有效；`claude-opus-4-8` 在 opencode.json 未定义 variants，故 opus 角色**不写 variant**（写了是空操作）。
- 工具类（explore/librarian）用便宜快速档。

**按第 5 步安装器实际生成的文件名覆盖**（两个模板内容等价，选对应格式的那个）：
- omo 4.16.x（生成 `.json`）：用 [assets/oh-my-openagent.json](assets/oh-my-openagent.json)（严格 JSON，无注释）覆盖 `$CFG/oh-my-openagent.json`。
- 老版本（生成 `.jsonc`）：用 [assets/oh-my-openagent.jsonc](assets/oh-my-openagent.jsonc) 覆盖 `$CFG/oh-my-openagent.jsonc`。

> 别把 `.jsonc` 内容写进 `.json` 文件 —— 注释会让严格 JSON 解析失败。也别新建一个不同扩展名的文件放着不管，那样生效的仍是安装器原文件（坑二没修）。

## 7. 验证

运行 [scripts/verify.sh](scripts/verify.sh)：
```bash
EASYCLAUDE_KEY=<KEY> bash scripts/verify.sh
```
校验 opencode.json / omo 映射文件（自动探测 `.json` 或 `.jsonc`）合法性与模型引用、中转连通、omo doctor、opencode 识别的 provider。

手动等价：
```bash
opencode models | grep -iE "easyclaude|opus|gpt-5"
bunx oh-my-openagent@latest doctor      # 只剩 AST-Grep 那条（可选依赖，无关）为正常
```
**改完 provider 或插件配置后重启 opencode**（不一定热加载）。omo 用法：提示词里加 `ultrawork`（或 `ulw`）触发并行 agent 全套能力。

## 常见问题

| 现象 | 解决 |
|---|---|
| `npm install -g` 报 EACCES/权限错误 (Linux/WSL) | 坑〇：全局前缀是 root 的 `/usr`，改用 `bun install -g opencode-ai@latest`（见第 1 步） |
| 模型列表里看不到 / 请求发到官方端点 | 坑一：provider ID 用了 `openai` 等保留名，改自定义 ID |
| omo 插件不生效 / 用了假模型 403 | 坑二：映射文件还是安装器默认 fallback（4.16.x 是 `opencode/gpt-5-nano`，老版本 `openai/gpt-5.4-pro`），用第 6 步模板覆盖 |
| 覆盖后仍是旧配置 | 坑三：删掉旧名 `oh-my-opencode.json[c]`；或覆盖了 `.jsonc` 但安装器实际生成的是 `.json`（反之亦然），改对文件名 |
| doctor 报 "Using legacy package name" | plugin 数组用了旧名 `oh-my-opencode`，改 `oh-my-openagent@latest` |
| doctor 报 AST-Grep unavailable | 可选依赖，与本配置无关，可忽略 |
| EPERM on opencode.exe (Windows) | 关掉运行中的 opencode 再更新；手动清 `.opencode-ai-*` 临时目录 |

## 安全

opencode.json 里 key 是明文，别提交公开仓库。omo 插件以完整系统权限运行。
EasyClaude 也提供 `claude-opus-4-7/4-6`、`claude-sonnet-5/4-6`、`claude-haiku-4-5` 等模型，需要时按第 2/6 步扩展（haiku 适合工具类/quick 分类进一步省钱）。
