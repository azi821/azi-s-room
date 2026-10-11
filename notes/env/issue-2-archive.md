---
title: 原始 issue #2 归档（环境能力说明）
date: 2026-10-11
tags: [github, 归档, 权限]
---

# 原始 issue #2 归档

**为什么归档**：这份内容原本是 issue #2，记录 DSH Agent 接入 GitHub 时的环境排查。
它属于「基础设施笔记」而非「待办事项」，所以从 issue 迁到这里长期保存。

**原位置**：https://github.com/azi821/azi-s-room/issues/2

**性质**：这是**历史快照**。其中「权限补齐前」的状态**已经过时**，
最新的通道与权限状态见 [github-access.md](github-access.md)。

> ⚠️ 下文正文里有多处「补充：之后权限已打通」之类的更正段，
> 说明这些结论是**逐步修正**出来的——保留原文是为了留住纠错痕迹。

---

## 原文正文
# azi's room · 初始化说明

这个 issue 是 DSH Agent 通过 **GitHub REST API** 真实创建的，用来记录这个仓库的起点、当前环境的真实能力边界，以及建议的下一步。

> 文中所有「实测」结论都来自本机真实请求，不是推测。

---

## 一、为什么不是普通的方式

正常情况下，AI 帮你操作仓库应该是 `git clone` → 改文件 → `git push`。**这台机器做不到**，原因不在权限，在网络。

### 实测：`github.com` 被 SNI 层拦截

对**同一个 IP** `20.205.243.168` 发 TLS 握手，只改 TLS 里的域名字段（SNI）：

| SNI（TLS 中的域名） | 结果 |
|---|---|
| `api.github.com` | ✅ 200 |
| `github.com` | ❌ 000（超时） |
| `example.com` | ❌ 000 |
| 不带 SNI | ❌ 000 |

**同一 IP、同一端口，只因域名字段不同而一个通一个死** → 这是基于 SNI 的域名白名单审查。

重复采样结果：

| 端点 | 5 次采样 |
|---|---|
| `api.github.com` | `200 200 200 200 000` |
| `codeload.github.com` | `301 301 301 301 301` |
| `github.com` | `000 000 000 000 000` |

### 后果

- ❌ 浏览器打不开 `github.com/settings/...` → **无法在这台电脑上签发 token**
- ❌ `git clone` / `git push` 全部不可用
- ✅ `api.github.com` REST API 完全可用

**所以这个仓库的所有写入都走 REST API，而不是 git。**

---

## 二、当前 token 的真实权限（实测边界）

| 操作 | 结果 | 说明 |
|---|---|---|
| 读取仓库 / 代码 / issue / PR | ✅ 通过 | |
| **创建 issue** | ✅ **HTTP 201** | 就是你现在看到的这个 |
| 修改 issue 状态 / 评论 | ❌ HTTP 403 | `Resource not accessible by personal access token` |
| 打标签 | ❌ HTTP 403 | 同上 |
| **写文件 / 建分支** | ❌ HTTP 403 | 缺 `Contents: write` |
| 创建仓库 | ❌ HTTP 403 | 缺 `Administration: write` |

### 两个值得记住的坑

**坑 1：`permissions.push = true` 是骗人的。**
仓库对象里 `permissions.push=true` 只说明**你是这个仓库的所有者**，**不代表 token 被授予了 Contents 写权限**。实测 `push=true` 但写文件 403。

**坑 2：PowerShell 的 `Invoke-RestMethod` 会吞掉错误原因。**
403 时它返回**空响应体**，只能看到 `远程服务器返回错误: (403) 冲突`。用 `curl` 重放同一个请求才拿到真实原因：

```json
{ "message": "Resource not accessible by personal access token", "status": "403" }
```

> 如果当时没做这个 curl 对照实验，会一直误判成「网络问题」，然后反复无效试错。
> **「空响应体」本身就是一条线索。**

---

## 三、建议的下一步

### 优先级 1：给 token 补 `Contents: write`

去 https://github.com/settings/personal-access-tokens 编辑这个 token：

| 权限 | 改成 |
|---|---|
| **Contents** | `Read and write` |
| **Issues** | `Read and write` |

**不用重新生成 token，也不用改环境变量，保存后立即生效。**

补上之后能力变化：

| | 现在 | 补上之后 |
|---|---|---|
| 放 README / 写文件 | ❌ | ✅ 直接写进 `main` |
| 建分支 | ❌ | ✅ 可以建 `feature/*` 给你审 |
| 评论 / 关闭 issue | ❌ | ✅ |
| `git push` | ❌ | ❌（网络封死，与权限无关） |

### 优先级 2：决定这个仓库放什么

账号是今天新建的，仓库是空的。建议先明确用途，比如：

- **笔记库** —— 把对话、想法、资料按主题存成 markdown
- **实验场** —— 放小脚本、配置、快速验证
- **项目起点** —— 准备正式开发某个东西

### 优先级 3：注意凭据泄露风险

这个 token 曾被**明文粘贴到聊天窗口**，因此它已经存在于会话记录里（明文落盘）。

当前它权限很小（只能创建 issue），风险可控。但**在补 `Contents: write` 之前建议先换一个新 token**——否则一旦泄露，攻击者就能改你仓库里的文件。

换 token 的正确姿势（token 不进聊天记录）：

```powershell
cd /d D:\deepseek工作文件夹\ai-connect
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-github.ps1 -Persist
```

提示时输入 `c` 回车 → **从剪贴板读取**。

---

## 四、配套工具（已在本机就绪）

| 脚本 | 作用 |
|---|---|
| `gh.ps1` | 读操作：`probe` `repo` `issues` `prs` `ci` `tree` `cat` `search` |
| `gh-write.ps1` | 写操作：`issue` `file` `perm` `close` |
| `net-diag.ps1` | 网络诊断：判别 SNI 审查 vs DNS 投毒 |
| `check-capabilities.ps1` | 8 个外部服务的可达性与密钥体检 |

由于 `api.github.com` 有约 20% 概率间歇性失败，所有 API 调用都内置 **6 次重试**，且**只对网络失败重试**——真实的 401/403/404 立即返回，不会空转。

---

*由 DSH Agent 通过 REST API 创建 · 2026-10-11*

---

## 更新（同日稍后）：权限已补齐，全链路打通

上面第二节的权限表**已经过时**。用户补齐了 token 权限，以下是**更新后的实测结果**：

| 操作 | 之前 | 现在 |
|---|---|---|
| 读取仓库 / 代码 / issue / PR | ✅ | ✅ |
| 创建 issue | ✅ | ✅ |
| **修改 / 关闭 issue** | ❌ 403 | ✅ **HTTP 200** |
| **写入文件** | ❌ 403 | ✅ **HTTP 201** |
| **建分支 / 删分支** | ❌ 403 | ✅ **HTTP 201 / 204** |
| 创建仓库 | ❌ 403 | 未测 |
| `git push` | ❌ 网络 | ❌ 网络（与权限无关） |

### 实际完成的事

- **issue #1**（我的测试数据）已关闭清理
- **README.md 已写入**，commit `6aa61b7a` —— 这是本仓库的**第一个提交**
- 建分支 / 删分支的真实写入实验通过，临时分支已清理

所以「本仓库只能通过 REST API 写入」这个结论不变（网络限制），
但**写入能力本身已经完整**。