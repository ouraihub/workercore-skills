---
name: agents-md-init
description: |
  为项目创建或修复 AGENTS.md + CLAUDE.md 的方法论 skill。核实真实代码结构后，把项目事实写进单一事实源 AGENTS.md，CLAUDE.md 只用一行 @AGENTS.md 导入，让 Claude Code / Codex / Cursor / Copilot 等所有工具拿到一致指令、永不漂移。触发词：创建 AGENTS.md、生成 CLAUDE.md、初始化 agent 配置、统一 agent 指令文件、修复 CLAUDE.md 和 AGENTS.md 不一致、agent 指令文件、agents md。当用户想给项目建立或整顿 AI 编码助手的指令文件时使用。
---

# AGENTS.md + CLAUDE.md 生成方法论

给任意项目创建（或修复）AI 编码助手指令文件。核心结论来自 2026 社区共识，见文末 references。

## 核心原则（不可动摇）

1. **单一事实源**：项目事实（结构、命令、规范、行为准则）只写进一处 —— `AGENTS.md`。
2. **CLAUDE.md 只做桥接**：内容只有一行 `@AGENTS.md`。Claude Code 启动时展开导入，等价于内联全部内容。
3. **绝不复制内容**：两个文件不放重叠内容，从物理上杜绝漂移。
4. **AGENTS.md 必须自洽**：因为 Codex/Cursor/Copilot 只读 AGENTS.md、不读 CLAUDE.md、也不懂 `@import`。行为准则若只放 CLAUDE.md，这些工具就丢失了 —— 所以一切都放 AGENTS.md。

## 为什么这样做（工具加载真相）

| 工具 | 读什么 | 结果 |
|------|--------|------|
| Claude Code | 只读 `CLAUDE.md`，遇 `@AGENTS.md` 展开导入 | 拿到 AGENTS.md 全部内容 |
| Codex / Cursor / Copilot / Amp | 只读 `AGENTS.md`，不认识 CLAUDE.md 与 `@import` | 直接拿到全部内容 |

每个工具只读自己的文件，**不会双读、不会冲突**。真正的冲突来自「两份文件各写一套项目事实且互相矛盾」—— 本方案从根上消除。

## 执行流程

### 第 1 步：核实真实结构（最重要，别信旧文档）

旧的 AGENTS.md/CLAUDE.md 经常描述已删除的目录。**一切以代码为准**：

- 用 `git ls-files | awk -F/ '{print $1}' | sort -u` 看真实的顶层目录/文件（只认 git 跟踪的）
- 读构建/依赖文件确认技术栈与命令：`package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` / `Makefile` 等
- 读 1-3 个代表性源文件，确认真实的日志/错误处理/命名约定，别照搬文档里的规范
- 看 `.github/workflows/`（或其他 CI）确认真实的安装、测试、lint 命令
- 对旧文档里每个声称的目录/文件/函数/flag，逐一验证是否还存在；不存在就删

### 第 2 步：写 AGENTS.md（唯一事实源）

按下述模板，只写**核实过**的内容。原则：

- **目标 < 200 行**（理想 60-150）。超过 300 行模型开始丢信号。
- **规则可验证**：写「外部请求必须带 timeout」而非「注意性能」。含糊的规则等于没写。
- **命令可直接执行**：给出精确的安装/测试/lint/运行命令，别写「跑测试」。
- **描述性 + 边界**：既说怎么做，也说禁止做什么（白名单目录、不许新增顶层目录等）。
- **不泄露敏感信息**：真实域名/仓库名用占位符，绝不写 API key。
- **保留已准确的旧内容**：修复场景下，旧文档里核实仍准确的规范（如依赖库使用约定）直接保留。

### 第 3 步：写 CLAUDE.md（纯导入）

内容只有：

```markdown
# CLAUDE.md

@AGENTS.md
```

不放任何独有内容。若项目已有 CLAUDE.md 且含有价值的规范，先把规范**移进** AGENTS.md，再把 CLAUDE.md 瘦成这一行。

### 第 4 步：验证

- 确认 `git ls-files` 里真实目录与 AGENTS.md 描述一致
- 确认 AGENTS.md 无残留的幽灵目录、无泄露的真实域名/密钥
- 确认 CLAUDE.md 只有 `@AGENTS.md` 一行
- （Claude Code 内）可让用户用 `/memory` 查看导入是否正确展开

## AGENTS.md 模板

```markdown
# AGENTS.md

<一两句话说明项目是什么、这个仓库负责哪一部分>。
本文件是 AI 编码助手的唯一事实源。改动前先读，不确定就问，不要猜。

## 开发环境
<精确、可直接执行的命令>
- 安装：`...`
- 运行：`...`
- 测试：`...`
- Lint：`...`

## 项目结构
<只列 git 跟踪的真实顶层目录，各目录一句话职责>

## 文件放置规范（严格遵守）
<白名单：允许在哪些路径创建/修改文件>
<禁止：不得新增顶层目录、不得在 X 外放 Y 类代码等>

## 依赖/框架约定
<项目特有的库使用规范，如「禁止重复造轮子」表格，只写核实过的>

## 错误处理（必须遵守）
<可验证的规则：外部请求必须 timeout、不许裸 except、失败必须带上下文日志等>

## 日志（必须遵守）
<真实的 logger 用法、命名约定、什么该记什么不该记>

## 改动原则
- 只改需要改的，不顺手重构
- 每个 commit 只做一件事
- <项目特有约束>

## 验证
<改完必须跑什么来确认没坏>

## 不要做的事
<项目特有的红线>

## 行为准则
（通用 agent 行为，放这里让所有工具都受约束）
1. 先想再写：说出假设，不确定就问，多种理解就摆出来
2. 极简优先：最少代码解决问题，不做没要求的抽象/配置
3. 外科手术式改动：只碰必须改的，匹配现有风格，每行改动可追溯到需求
4. 目标驱动：把任务转成可验证目标，改完按「验证」一节跑，别只声称能跑
```

## 常见误区（避免）

- ❌ 照抄旧文档的目录结构 —— 必核实
- ❌ 把行为准则只放 CLAUDE.md —— Codex 读不到
- ❌ 两份文件各写一套项目事实 —— 必然漂移
- ❌ 写含糊、不可验证的规则（「写好代码」「注意性能」）
- ❌ 文件过长塞满细节 —— 高频细节进代码注释/rules，可复用流程进 skill
- ❌ 用符号链接 `ln -s AGENTS.md CLAUDE.md` 也可行，但 import 方式更灵活（CLAUDE.md 未来可加 Claude 专属内容），本 skill 默认用 import

## References

- agents.md 官方标准：https://agents.md
- Claude Code 只读 CLAUDE.md、@import 与 symlink 两法：https://gist.github.com/yurukusa/d36197848911f025add142abefcde685
- 跨工具统一（Codex/Cursor/Copilot 等）：https://gist.github.com/hungson175/76131bb8434f9d58ee7b2f08c3242624
- CLAUDE.md 内容准则（<200 行、可验证规则）：https://www.turbodocx.com/blog/how-to-write-claude-md-best-practices
- 2026 CLAUDE.md playbook（更短、可证伪、显式强制）：https://gentic-news.hashnode.dev/the-2026-claudemd-playbook-8-rules-that-make-your-agent-2x-more-effective
```
