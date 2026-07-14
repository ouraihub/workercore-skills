---
name: omp-siliconflow-setup
description: "OMP + SiliconFlow 环境一键配置。在新机器上安装 Oh My Pi (omp) 并配置 SiliconFlow 中转，使其使用 DeepSeek-V4-Pro/Flash、Kimi-K2.7-Code、GLM-5.2 对话模型，以及通过 imagegen-mcp 使用 Z-Image-Turbo/Z-Image 图片生成。中转差异由 assets/profiles/siliconflow.json 描述。触发词：配置 omp、配置 siliconflow、复制环境、setup omp、新机器配置、omp 走 siliconflow。前置条件：Node 22+、pnpm/npm、Git。"
---

# 配置 OMP + SiliconFlow

在新机器上安装 Oh My Pi 并配好 SiliconFlow 中转（对话模型 + 图片生成）。按顺序执行，每步有验证。

配置目录 `$OMP = ~/.omp/agent`。

## 0. 确认 profile

skill 把 SiliconFlow 特有参数抽进 `assets/profiles/siliconflow.json`。包含：
- 4 个对话模型：DeepSeek-V4-Pro、DeepSeek-V4-Flash、Kimi-K2.7-Code、GLM-5.2
- 2 个图片生成模型：Z-Image-Turbo（默认）、Z-Image
- API 格式：OpenAI 兼容（`/v1/chat/completions` + `/v1/images/generations`）

需要用户提供：**SiliconFlow API Key**（从 https://cloud.siliconflow.cn 获取）。

## 1. 安装 omp

**先查是否已装**：
```bash
command -v omp && omp --version
```

**推荐用 bun 安装**（快、无权限坑）：
```bash
bun --version || npm install -g bun
bun install -g @anthropic-ai/claude-code    # omp 基于此
bun install -g oh-my-pi
hash -r; command -v omp; omp --version      # 应指向 ~/.bun/bin/omp
```

> ⚠️ WSL 用户：别装在 `/mnt/c` 等 Windows 挂载盘，I/O 慢。用 bun 装到 `~/.bun/bin`。
>
> ⚠️ Linux/WSL：别用 `npm install -g`（全局前缀 `/usr` 需 root）。用 `bun install -g`。

## 2. 写 `~/.omp/agent/models.yml`

omp 用 YAML 格式注册自定义 provider。用 [assets/models.yml](assets/models.yml) 作模板，按 profile 替换占位符：

| 占位符 | 替换成 |
|---|---|
| `__PROFILE_NAME__` | `siliconflow` |
| `__PROFILE_BASEURL__` | `https://api.siliconflow.cn` |
| `__PROFILE_KEY__` | API Key（明文或环境变量名 `SILICONFLOW_API_KEY`） |
| `__MODEL_*_ID__` | profile 对应模型 id |
| `__MODEL_*_NAME__` | profile 对应模型 name |
| `__MODEL_*_CTX__` | contextWindow |
| `__MODEL_*_MAX__` | maxTokens |

实际渲染结果：
```yaml
providers:
  siliconflow:
    baseUrl: https://api.siliconflow.cn/v1
    api: openai-completions
    apiKey: <KEY 或 SILICONFLOW_API_KEY>
    authHeader: true
    models:
      - id: deepseek-ai/DeepSeek-V4-Pro
        name: DeepSeek V4 Pro
        reasoning: true
        input: [text]
        contextWindow: 1000000
        maxTokens: 65536
      - id: deepseek-ai/DeepSeek-V4-Flash
        name: DeepSeek V4 Flash
        reasoning: true
        input: [text]
        contextWindow: 1000000
        maxTokens: 65536
      - id: moonshotai/Kimi-K2.7-Code
        name: Kimi K2.7 Code
        reasoning: true
        input: [text, image]
        contextWindow: 256000
        maxTokens: 65536
      - id: zai-org/GLM-5.2
        name: GLM 5.2
        reasoning: true
        input: [text]
        contextWindow: 1000000
        maxTokens: 65536
```

验证：
```bash
omp models find siliconflow   # 应显示 4 个模型
```

## 3. 安装 imagegen-mcp（图片生成）

Z-Image 系列是图片生成模型，走 `/v1/images/generations` 接口，**不能**配在 models.yml 里当 chat 模型用。通过 MCP server 接入。

```bash
mkdir -p ~/projects
git clone https://github.com/acrossoffwest/imagegen-mcp.git ~/projects/imagegen-mcp
cd ~/projects/imagegen-mcp
pnpm install && pnpm approve-builds --all && pnpm install
# 或 npm install
```

写 imagegen-mcp 配置（用 [assets/imagegen-config.json](assets/imagegen-config.json) 模板）：
```bash
mkdir -p ~/.config/imagegen-mcp
```
渲染后写入 `~/.config/imagegen-mcp/config.json`：
```json
{
  "providers": {
    "siliconflow": {
      "type": "openai",
      "envVar": "SILICONFLOW_API_KEY",
      "baseUrl": "https://api.siliconflow.cn/v1"
    }
  },
  "defaultProvider": "siliconflow",
  "defaultModel": "Tongyi-MAI/Z-Image-Turbo"
}
```

## 4. 写 `~/.omp/agent/mcp.json`

注册 imagegen-mcp 为 omp 的 MCP server（用 [assets/mcp.json](assets/mcp.json) 模板）：
```json
{
  "mcpServers": {
    "imagegen": {
      "command": "npx",
      "args": ["-y", "tsx", "~/projects/imagegen-mcp/src/server.ts"],
      "env": {
        "SILICONFLOW_API_KEY": "<KEY>"
      }
    }
  }
}
```
> `args` 中路径用绝对路径（展开 `~`）。

## 5. 外观设置（可选）

```bash
omp config set symbolPreset nerd    # 需 Nerd Font（终端字体设为 JetBrainsMono Nerd Font 等）
```

## 6. 验证

```bash
export SILICONFLOW_API_KEY=<KEY>
PROFILE=siliconflow bash scripts/verify.sh
```
全部通过会输出 `OMP_SILICONFLOW_ALL_OK`。

手动验证：
```bash
# 对话模型
omp --model DeepSeek-V4-Flash -p "reply with exactly: OMP_OK"

# 图片生成（MCP 内测试）
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"generate_image","arguments":{"prompt":"a red circle","outputPath":"/tmp/test.png"}}}\n' | \
  SILICONFLOW_API_KEY=$SILICONFLOW_API_KEY timeout 30 npx tsx ~/projects/imagegen-mcp/src/server.ts 2>/dev/null
```

## 常见问题

| 现象 | 解决 |
|---|---|
| omp 启动默认显示 `gemma4:31b-cloud` | models.yml 没放对位置（必须 `~/.omp/agent/models.yml`，不是 `~/.pi/agent/`） |
| `omp models find siliconflow` 无结果 | models.yml 语法错误或路径不对；用 `omp config path` 确认配置目录 |
| imagegen-mcp 生成报错 | 确认 `SILICONFLOW_API_KEY` 在 mcp.json 的 env 中正确设置 |
| `Tip: Please use nerdfont` | 运行 `omp config set symbolPreset nerd`，并在终端设置 Nerd Font 字体 |
| pnpm install 报 `ERR_PNPM_IGNORED_BUILDS` | 运行 `pnpm approve-builds --all` 再 `pnpm install` |

## 安全

推荐 apiKey 写环境变量名（omp 先查同名 env var，找不到才当字面量用）：
```yaml
apiKey: SILICONFLOW_API_KEY
```
然后 shell 里 `export SILICONFLOW_API_KEY=sk-xxx`。这样 models.yml 可安全提交。

mcp.json 里的 env 块中 key 始终是字面量（omp 不对 env 值做二次 env 解析），注意 `chmod 600 ~/.omp/agent/mcp.json`。
