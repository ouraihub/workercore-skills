# 模型选型指南

当前已配置的模型及适用场景，方便按需选择。

## SiliconFlow 模型

通过 `https://api.siliconflow.cn/v1` 接入。

### 对话/推理模型

| 模型 ID | 上下文 | 特点 | 适合场景 |
|---------|--------|------|----------|
| `deepseek-ai/DeepSeek-V4-Pro` | 1M | 1.6T 参数 (49B active)，旗舰推理 | 复杂推理、长文档分析、架构设计 |
| `deepseek-ai/DeepSeek-V4-Flash` | 1M | 284B 参数 (13B active)，性价比高 | 日常编码、对话、快速迭代 |
| `moonshotai/Kimi-K2.7-Code` | 256K | 1T 参数 (32B active)，代码专长，支持图片 | 代码生成/重构、MCP 工具调用、多模态 |
| `zai-org/GLM-5.2` | 1M | 长程任务、MIT 开源 | 仓库级代码分析、跨文件重构、超长上下文 |

### 图片生成模型（通过 imagegen-mcp 调用）

| 模型 ID | 特点 | 适合场景 |
|---------|------|----------|
| `Tongyi-MAI/Z-Image-Turbo` | 6B 参数，8 步推理，亚秒延迟 | 快速出图、批量生成、原型验证 |
| `Tongyi-MAI/Z-Image` | 6B 参数，完整推理步数 | 高质量图片、精细控制、最终交付 |

> 图片模型走 `/v1/images/generations` 接口，不能当 chat 模型用。在 omp 里通过 MCP 工具 `generate_image` 调用。

---

## 七牛云模型

通过 `https://api.qnaigc.com/v1` 接入。

### GPT-5.6 家族（2026-07-09 发布）

三档设计，按需选用：

| 模型 ID | 档位 | 定价 | 适合场景 |
|---------|------|------|----------|
| `openai/gpt-5.6-sol` | ☀️ 旗舰 | 最贵 | 高难度推理、复杂编码、agent 长链路、失败代价大的任务 |
| `openai/gpt-5.6-terra` | 🌍 均衡 | 中等 | 日常开发、生产环境、文档生成、性价比最优 |
| `openai/gpt-5.6-luna` | 🌙 轻量 | 最便宜 | 高并发批处理、分类/摘要、延迟敏感、成本优先 |

**选型口诀：Sol 干难活，Terra 干日常，Luna 干量大。**

> ⚠️ 七牛云的 GPT-5.6 模型 ID 必须带 `openai/` 前缀（如 `openai/gpt-5.6-sol`），裸名会报错。

### 其他模型

| 模型 ID | 上下文 | 适合场景 |
|---------|--------|----------|
| `gpt-5.5` | 400K | 上一代旗舰，综合能力强 |
| `gpt-5.4-mini` | 400K | 便宜轻量，简单任务够用 |
| `claude-opus-4-8` | 200K | Anthropic 最强模型，长文写作、复杂分析 |

> ⚠️ 七牛云的 `claude-opus-4-8` 不支持 reasoning 模式（`thinking.enabled` 参数会报错），已配置为 `reasoning: false`。

---

## 快速选型

| 我要做什么 | 推荐模型 | 理由 |
|-----------|----------|------|
| 写复杂架构/难题 | `gpt-5.6-sol` 或 `DeepSeek-V4-Pro` | 最强推理 |
| 日常编码 | `gpt-5.6-terra` 或 `DeepSeek-V4-Flash` | 均衡性价比 |
| 批量简单任务 | `gpt-5.6-luna` 或 `gpt-5.4-mini` | 快且便宜 |
| 代码专项/MCP 工具 | `Kimi-K2.7-Code` | 专为代码 agent 优化 |
| 超长文档/仓库级分析 | `GLM-5.2` 或 `DeepSeek-V4-Pro` | 1M 上下文 |
| 多模态（图片输入） | `Kimi-K2.7-Code` 或七牛 GPT 系列 | 支持图片理解 |
| 生成图片 | `Z-Image-Turbo`（快）/ `Z-Image`（精） | MCP generate_image |
| 长文写作/深度分析 | `claude-opus-4-8` | Claude 文字功底强 |

---

## omp 使用方式

```bash
# 指定模型启动（支持模糊匹配）
omp --model "DeepSeek-V4-Pro"
omp --model "5.6-sol"
omp --model "5.6-terra"
omp --model "Kimi"
omp --model "GLM"
omp --model "opus"

# 查看所有可用模型
omp models

# 按 provider 查看
omp models find siliconflow
omp models find qiniu
```
