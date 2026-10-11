---
title: GitHub 接入通道与权限边界
date: 2026-10-11
tags: [github, 网络, 凭据, 排查]
---

# GitHub 接入通道与权限边界

**结论（2026-10-11 实测）**：GitHub 三条通道**目前全部可用**——`git` 协议、REST API、资源下载。
但 `github.com` 曾一度被 **SNI 层完全拦截**，所以这份文档的价值在于**复测方法**，
而不是「现在能用」这个易过时的结论。

⚠️ **网络状态会变。** 同一批测试在 2026-10-11 当天就出现过从 **0/5 到 5/5** 的反转。
本页任何结论使用前，先跑一遍复测。

---

## 一、三条通道

| 通道 | 用途 | 2026-10-11 状态 |
|---|---|---|
| `git` 协议（`github.com:443`） | clone / pull / push | ✅ 可用 |
| REST API（`api.github.com`） | 读写文件、issue、PR、元数据 | ✅ 可用 |
| 资源下载 | tarball、Release 资产 | ✅ 可用 |
| `raw.githubusercontent.com` | 直接取单文件 | ❌ 000（改走 API `/contents`） |

## 二、曾经的拦截：SNI 白名单

当时的判别实验——对**同一个 IP** `20.205.243.168` 发 TLS 握手，只改 TLS 里的域名字段（SNI）：

| SNI | 结果 |
|---|---|
| `api.github.com` | ✅ 200 |
| `github.com` | ❌ 000 |
| `example.com` | ❌ 000 |
| 不带 SNI | ❌ 000 |

**同一 IP、同一端口，只因域名字段不同而一个通一个死。**
这排除了 DNS 问题（改 hosts / 换 DNS 服务器都不会有用），指向 SNI 层审查。

重复采样（当时）：

| 端点 | 5 次 |
|---|---|
| `api.github.com` | `200 200 200 200 000` |
| `codeload.github.com` | `301 301 301 301 301` |
| `github.com` | `000 000 000 000 000` |

**后来复测**：`git ls-remote` 5/5 成功，`git clone` 和 `git push` 均成功。

> **教训**：不要拿一次网络测试的结论当永久事实。当时的错误判定直接导致
> 「`git push` 永远发不出去」这个错误结论被写进了文档。

## 三、token 权限边界

fine-grained PAT，仓库 `azi821/azi-s-room`。

| 操作 | 权限补齐前 | 补齐后 |
|---|---|---|
| 读取仓库 / 代码 / issue / PR | ✅ | ✅ |
| 创建 issue | ✅ HTTP 201 | ✅ |
| 修改 / 关闭 issue | ❌ HTTP 403 | ✅ HTTP 200 |
| 写入文件 | ❌ HTTP 403 | ✅ HTTP 201 |
| 建分支 / 删分支 | ❌ HTTP 403 | ✅ HTTP 201 / 204 |
| 创建仓库 | ❌ HTTP 403 | 未测 |

补齐方式：在 token 设置页把 **Contents** 和 **Issues** 改为 `Read and write`。
**不需要重新生成 token，也不需要改环境变量，保存后立即生效。**

## 四、排查中踩过的坑

### 坑 1：`permissions.push = true` 不代表能写

仓库对象里这个字段只说明**你是仓库所有者**，不代表 token 被授予了写权限。
实测出现过 `push=true` 但写文件 403。

**判定写权限的唯一可靠方法是真实写入实验**（建个临时分支再删掉），不能看字段。

### 坑 2：PowerShell 的 `Invoke-RestMethod` 会吞掉错误原因

403 时它返回**空响应体**，只能看到 `远程服务器返回错误: (403)`。
用 `curl` 重放同一个请求才拿到真实原因：

```json
{ "message": "Resource not accessible by personal access token", "status": "403" }
```

> 如果没做这个 curl 对照实验，会一直误判成「网络问题」然后反复无效试错。
> **「空响应体」本身就是一条线索**——正常的报错不会没有原因。

### 坑 3：判断可达性不能看 HTTP 跳转

`curl http://github.com` 返回 301，被 `-w %{http_code}` 记成 200，看起来像「通了」。
实际那是 **80 端口**的跳转，**443 依然死**。

**判断可达必须看 TLS 结果，不能被 HTTP 跳转迷惑。**

### 坑 4：仓库 `size` 字段是缓存值

刚提交完仍显示 `0 KB`，不能用它判断仓库是否为空。
可靠判断是**默认分支的 ref 是否存在**。

### 坑 5：`$args` 是 PowerShell 自动变量

在函数里写 `$args = @(...)` 会触发运行时解析错误（`Unexpected token`），
而**语法检查能通过**——极其难查。改用 `$cargs` 之类的名字。

### 坑 6：`[switch]` 参数无法绑定 `$null`

调用 `Invoke-Api 'GET' $path $null` 时，如果函数签名末尾有 `[switch]$Raw`，
`$null` 会尝试绑定到 switch 并抛
`Cannot convert the "" value ... to SwitchParameter`。
不用的 switch 参数直接删掉。

## 五、复测

```powershell
# 网络状态判定（SNI 审查 vs DNS 投毒）
powershell -NoProfile -ExecutionPolicy Bypass -File D:\deepseek工作文件夹\ai-connect\net-diag.ps1

# 权限体检（含真实写入实验）
powershell -NoProfile -ExecutionPolicy Bypass -File D:\deepseek工作文件夹\ai-connect\gh-write.ps1 perm azi821/azi-s-room
```

## 六、本机工具链位置

| 项目 | 路径 |
|---|---|
| git | `D:\dev-tools\Git\cmd\git.exe`（2.55.0） |
| 凭据管理器 | `D:\dev-tools\Git\mingw64\bin\git-credential-manager.exe` |
| 实际使用的 helper | `wincred` |
| node / npx | **不存在** |
