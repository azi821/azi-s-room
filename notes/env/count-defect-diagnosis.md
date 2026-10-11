---
title: 用 diagnosing-bugs 技能定位并修复 .Count 缺陷
date: 2026-10-11
tags: [排查, powershell, 技能实践, 测试]
---

# 用 diagnosing-bugs 技能定位并修复 `.Count` 缺陷

**结论**：PowerShell 里 `f(x).Count` 是**不可靠**的。当函数返回**恰好 1 个元素**时，
PowerShell 把数组解包成**标量**，标量的 `.Count` 返回 **`$null`**，
用 `-f` 格式化后变成**空字符串**——症状是「单元素时计数显示为空」。

**修复：调用方用 `@()` 显式包裹**，`$items = @(Invoke-GitHub ...)`。

---

## 为什么记这条

这是第一次**实际执行**下载的 Agent Skill。`diagnosing-bugs` 的第一条规矩是：

> **Phase 1: Build a feedback loop** —— "This is the skill. Everything else is mechanical."
> 并且明确禁止：「If you catch yourself reading code to build a theory before this command exists, **stop**」

实际执行下来，这条规矩**确实拦住了两次错误**（见下文「技能拦住了我什么」）。
所以这条笔记不只记 bug，也记**方法论是否有效**。

## 症状

`gh.ps1` 的 `issues` / `prs` / `notif` 三个命令在 API 返回**恰好 1 个元素**时，
计数打印成空：

```
--- microsoft/vscode 开放 PR () ---     ← 应该是 (1)
--- 未读通知 () ---
```

返回 **0 个**或 **3 个**元素时都正常。**只有恰好 1 个时出错**——这种形状的 bug 很容易被忽略，
因为最常见的测试数据（0 个、多个）都不触发它。

## 根因（实测机制）

| 函数的 `return` 值 | 调用方拿到的类型 | `.Count` | `-f "({0})"` |
|---|---|---|---|
| `@()`（零元素） | `null` | **0** | `(0)` ✅ |
| `@(单元素)` | `PSCustomObject`（标量） | **`$null`** | `()` ❌ |
| `@(三元素)` | `Object[]` | 3 | `(3)` ✅ |

关键在于 **PowerShell 的管道会枚举数组**：

- `return @()` → 零元素被枚举掉，调用方得到 `null`
- `return @(单元素)` → 一个元素被枚举出来，调用方得到**标量**，不是数组

而 PS 5.1 对 `$null` 的 `.Count` 返回 `0`（为了兼容性），
所以**零元素反而正常**，掩盖了问题。

## 反馈循环

`D:\deepseek工作文件夹\ai-connect\test-gh-count.ps1`

用**桩替身**（stub）替换 `Invoke-GitHub`，固定喂入 0 / 1 / 3 个元素，
断言每个命令的计数输出。满足技能对循环的四项要求：

| 要求 | 本循环 |
|---|---|
| Red-capable | 断言的是**用户症状本身**（计数文本），不是「没崩溃」 |
| Deterministic | 桩替身输入固定，每次同样结果 |
| Fast | **约 2 秒** |
| Agent-runnable | 全程无人值守 |

### 踩到的两个陷阱（都是构建循环时踩的）

**陷阱 1：`Write-Host` 不进 stdout。**
`$out = & (...) 2>&1 | Out-String` 捕获到的是**空字符串**（实测 `$out.Length = 0`），
而循环照样「变红」——**但红的原因是我的捕获方式错了，不是被测代码有 bug**。

必须用 **`6>&1`** 把信息流（stream 6，`Write-Host` 走这条）重定向才能捕获：

```powershell
$out = & ([scriptblock]::Create($code)) 6>&1 2>&1 | Out-String
```

> **这是本次最有价值的教训**：一个「会变红」的循环**不等于**一个「红在正确位置」的循环。
> 如果没检查红的**原因**，就会拿着错误的信号往下走，最后修错东西。

**陷阱 2：`[switch]$Verbose` 与 `[CmdletBinding()]` 冲突。**
`[CmdletBinding()]` 已自带 `-Verbose` 公共参数，重名会直接报
`A parameter with the name 'Verbose' was defined multiple times`。
改用 `-ShowPass`。

## 技能拦住了我什么

### 拦截 1：不许先猜原因

我最初的判断是「现在没有已知的 bug 可以诊断」——
**这个判断是错的**。技能要求先建循环，我去找事实，才发现 `.Count` 在源码里有 12 处用法、
其中 3 处真的会踩到解包问题。**先建循环，逼出了本来会被忽略的 bug。**

### 拦截 2：红的循环不等于对的循环

第一次跑出 `9/9 失败`，但输出里 `(0)`、`(3)` 明明是**对的**。
如果接受这个「红」，我就会去改没坏的东西。
技能要求「断言用户的真实症状」，这条要求让我去查了失败原因，才发现是自己的捕获 bug。

## 修复

三处调用点，加 `@()` 包裹：

```powershell
# 修复前
$items = Invoke-GitHub "/repos/$r/pulls?state=open&per_page=$Limit"

# 修复后
$items = @(Invoke-GitHub "/repos/$r/pulls?state=open&per_page=$Limit")
```

**验证**：

| 阶段 | 循环结果 |
|---|---|
| 修复前 | 通过 6 / 失败 3 |
| 修复后 | **通过 9 / 失败 0** |

真实 API 复验（非桩替身）：
- `prs microsoft/vscode` → `(1)` ✅
- 临时建 issue 使仓库恰好 1 个 open → `(1)` ✅，验证后已关闭

## 附带发现

`GET /notifications` 需要 token 的 **Notifications** 权限（本 token 没有，返回 403）。
不是 bug，是权限边界。

## 可复用的经验

1. **PowerShell 里对集合计数一律 `@()` 包裹**，不要相信 `.Count`
2. **`Write-Host` 的输出要 `6>&1` 才能捕获**——写测试时最容易踩
3. **循环变红后，先确认红在正确的位置**，再去改代码
4. **「恰好 1 个元素」是特殊路径**，测试数据要覆盖 0 / 1 / N 三种

## 待跟进

- [ ] `notif` 需要 Notifications 权限才能验证单元素路径
- [ ] 其余 12 处 `.Count` 用法已复核，风险较低（列表结果，非单元素场景）
