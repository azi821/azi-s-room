# azi's room

个人**笔记库**。由 DSH Agent 协助维护。

---

## 目录结构

```
.
├── README.md          # 你在这里
├── notes/
│   ├── README.md      # 笔记规范：命名、分类、模板
│   ├── _template.md   # 新笔记模板
│   └── env/           # 环境档案：DSH 接入、网络、凭据
│       ├── README.md
│       ├── github-access.md
│       └── issue-2-archive.md
└── issues/            # 需要长期跟进的事项
    └── README.md
```

## 怎么用

| 我想做的事 | 放哪 |
|---|---|
| 记一条结论 / 资料 / 想法 | `notes/<主题>/` |
| 记环境、配置、排查过程 | `notes/env/` |
| 记需要跟进的事 | `issues/` |

**一条笔记一个文件**，文件名用能直接读懂的中文或英文短句，不要 `untitled-1`。

## 笔记规范

见 [notes/README.md](notes/README.md)。核心三条：

1. **一个文件说清一件事**，开头写清结论
2. **带时间戳**——环境类结论会过时，没有日期的「事实」会误导未来的你
3. **写明依据**——「实测」和「推测」必须区分开

## 现有内容

### 环境档案 `notes/env/`

DSH Agent 接入外部服务的过程记录，包括一次完整的网络排查。**这些结论有长期价值**，因为网络限制是动态的：

| 文档 | 内容 |
|---|---|
| [github-access.md](notes/env/github-access.md) | GitHub 三条通道（git / REST API / raw）的实测状态与踩坑记录 |
| [issue-2-archive.md](notes/env/issue-2-archive.md) | 原始 issue #2 的完整归档 |

---

*最后更新：2026-10-11*
