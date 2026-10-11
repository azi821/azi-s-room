---
title: Agent Skills 生态与实践
date: 2026-10-11
tags: [ai, skills, 工具, 实测]
---

# Agent Skills 生态与实践

**结论**：`skills.sh` 是真实的 Agent 技能目录站（Vercel 做的），技能本质就是**带 frontmatter 的 markdown 流程文档**。
但 **装机量排行榜不能用来挑工具**——榜单第 2 名（130 万装机）本体只有 **157 字节**，内容是一句转发指令。
真正干活的那个技能**根本没上榜**。挑技能要看正文，不看数字。

---

## 一、技能是什么

一个技能 = 一个目录 + 一个 `SKILL.md`：

```markdown
---
name: 技能名
description: 何时该用这个技能（写给模型看的触发条件）
---

正文：流程、规范、检查清单……
```

**没有代码，没有魔法。** 所谓「安装技能」就是把 markdown 放到 agent 会读的位置。
技能可以带辅助文件（脚本、参考文档），但核心永远是那份流程文档。

> 这意味着：**能力上限取决于正文写得好不好，不取决于装机量。**
> 也意味着技能完全可以自己写——不需要等别人发布。

## 二、官方安装方式及其限制

```bash
npx skills add <owner/repo>
```

**本机不可用**——没有 node / npx。

替代方案（已实测可行）：

| 方式 | 可行性 |
|---|---|
| `npx skills add` | ❌ 无 node |
| `raw.githubusercontent.com` 直接下载 | ❌ 返回 000 |
| **GitHub REST API `/contents` 解码 base64** | ✅ 可行 |
| `git clone` 整个仓库再挑文件 | ✅ 可行（网络恢复后） |

REST API 方式的关键点：`/repos/{owner}/{repo}/contents/{path}` 返回的
`content` 字段是 **base64**，需要解码；且**必须去掉其中的换行符**再解码。

## 三、⚠ 装机量 ≠ 实用性（实证）

截图榜单数据截止 2026.09.22，与实时数据已有偏差：

| 截图排名 | 技能 | 实时排名 |
|---|---|---|
| 6 | frontend-design | **8** |
| — | hyperframes-cli | **10**（截图时未进榜） |
| 10 | triage | **11** |

**更关键的是这个**：

| 技能 | 装机量 | 本体大小 | 实际内容 |
|---|---|---|---|
| `grill-me` | 130 万 | **157 字节** | `Call the Skill tool with "grilling".` |
| `grill-with-docs` | 110 万 | **247 字节** | `Call the Skill tool twice, for "grilling" and "domain-modeling".` |
| `grilling` | 未上榜 | 2049 字节 | 真正的追问方法论 |
| `domain-modeling` | 未上榜 | 3346 字节 | 真正的领域建模方法 |

**`grill-me` 和 `grill-with-docs` 是转发壳**，真正干活的 `grilling` / `domain-modeling` 都没上 TOP10。

> **装机量统计的是「被一起装了多少次」，不是「这个技能有多少内容」。**
>
> 一个推论：榜单前面的项，很可能是**被某个热门技能包带着装上去的**，而不是被独立选择的。

## 四、技能的真实来源（避免找错仓库）

| 技能 | 仓库 |
|---|---|
| find-skills | `vercel-labs/skills` |
| agent-browser | `vercel-labs/agent-browser` |
| frontend-design | `anthropics/skills` |
| grill-me / grill-with-docs / tdd / triage / handoff / setup-matt-pocock-skills / improve-codebase-architecture | `mattpocock/skills` |

**注意同名技能会分布在多个分类目录下**。例如 `grill-me` 在
`skills/productivity/` 而不在 `skills/engineering/`——
`mattpocock/skills` 有 38 个 `SKILL.md`，按 `engineering` / `productivity` / `misc` / `in-progress` 分类。
**按猜的路径下载会 404，要用 `/git/trees?recursive=1` 先列全树。**

## 五、依赖补全

有些技能是壳，装它等于装了个死链。**下载后要扫描正文里的技能引用并递归补齐。**

`D:\deepseek工作文件夹\ai-connect\fetch-skill-deps.ps1` 做这件事：
用正则匹配正文里的 `Skill tool ... "技能名"`，缺哪个补哪个，多轮直到收敛。

实测：初始 12 个 → 补 3 个依赖（`grilling` / `domain-modeling` / `codebase-design`）→ 收敛。

## 六、使用注意事项

部分技能带 `disable-model-invocation: true`，意思是**需要用户显式触发**，模型不能自行调用：

`grill-me`、`grill-with-docs`、`triage`、`handoff`、`to-spec`、`setup-matt-pocock-skills`

## 七、当前技能库

位置：`D:\deepseek工作文件夹\skills\`（15 个技能 + `MANIFEST.md` 清单）

| 技能 | 字节 | 说明 |
|---|---|---|
| frontend-design | 9390 | 视觉设计指导 |
| diagnosing-bugs | 8664 | 难缠 bug 与性能回归的诊断循环 |
| setup-matt-pocock-skills | 6978 | 为仓库配置工程技能工作流 |
| code-review | 6670 | 基于固定基点审查改动 |
| triage | 6558 | issue/PR 状态机 |
| codebase-design | 6446 | 深模块设计词汇表 |
| improve-codebase-architecture | 6000 | 扫描并重构代码架构 |
| find-skills | 5472 | 发现并安装技能 |
| tdd | 3629 | 测试驱动开发 |
| domain-modeling | 3346 | 领域建模 |
| to-spec | 3043 | 对话转规格说明 |
| grilling | 2049 | 刨根问底式追问 |
| handoff | 940 | 对话转交接文档 |
| grill-me | 157 | 转发壳 → grilling |
| grill-with-docs | 247 | 转发壳 → grilling + domain-modeling |

## 八、未安装的

| 技能 | 原因 |
|---|---|
| `agent-browser` | 需要浏览器自动化运行时，本机环境不满足 |
| `hyperframes` 系列 | 依赖外部服务 |

## 九、顺带记录：DSH 的技能加载机制

DSH **没有全局用户技能目录**的配置项。技能由**插件通过 `assetRoot` 加载**
（例：office 插件从 `resources/runtime/office-skills` 读）。

所以第三方技能**无法挂载进当前会话的技能目录**——但可以直接读正文并遵循，
实际效果差别不大：技能本来就是给人/AI 看的流程文档。

## 待跟进

- [ ] 有 node 环境后，可以试试官方 `npx skills add` 流程做对比
- [ ] 技能更新后需要重新抓取（本页数据为 2026-10-11 快照）
