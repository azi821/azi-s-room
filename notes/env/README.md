# 环境档案

记录这台机器的**工作环境**：网络限制、凭据配置、工具链位置、排查过程。

## 为什么单独成目录

环境类结论有**时效性**。这台机器已经出现过一次「结论反转」：
`github.com` 一度完全不可达，后来恢复。所以每条结论都必须带**实测时间**，
并且要能方便地复测。

## 索引

| 文档 | 内容 | 最后实测 |
|---|---|---|
| [github-access.md](github-access.md) | GitHub 各通道可达性、token 权限边界、踩坑记录 | 2026-10-11 |
| [issue-2-archive.md](issue-2-archive.md) | 原始 issue #2 归档（含权限补齐前后的对比） | 2026-10-11 |

## 关键环境事实

```yaml
磁盘工具位置:  D:\dev-tools\Git\          # git 2.55.0
                D:\deepseek\resources\    # DSH 安装目录
工作目录:      D:\deepseek工作文件夹\
仓库副本:      D:\deepseek工作文件夹\repos\azi-s-room\
工具脚本:      D:\deepseek工作文件夹\ai-connect\
技能库:        D:\deepseek工作文件夹\skills\
```

| 项目 | 状态 |
|---|---|
| git 凭据管理器 | `wincred`（`git-credential-store` 未安装；`manager` 在 `github.com` 不可达时会挂死） |
| node / npx | **不存在**——官方 `npx skills add` 安装方式不可用 |
| `raw.githubusercontent.com` | 不可达（000），下载技能需走 REST API 解码 base64 |

## 复测方法

`D:\deepseek工作文件夹\ai-connect\net-diag.ps1` 会重新判定网络状态并给出结论。
网络一变就跑一次，别靠记忆。
