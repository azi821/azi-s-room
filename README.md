# azi's room

这是 **azi821** 的个人仓库，由 DSH Agent 通过 GitHub REST API 初始化。

---

## 环境备忘：为什么这里没有用 git

本机网络对 `github.com:443` 做了 **SNI 白名单审查**，只放行 `api.github.com`。
因此 `git clone` / `git push` 全部不可用，所有写入都走 REST API。

判别实验（对同一个 IP `20.205.243.168` 发 TLS 握手，只改 TLS 里的域名字段）：

| SNI | 结果 |
|---|---|
| `api.github.com` | ✅ 200 |
| `github.com` | ❌ 000 |
| `example.com` | ❌ 000 |
| 不带 SNI | ❌ 000 |

**同一 IP、同一端口，只因域名字段不同而一个通一个死** → 这是 SNI 层拦截，不是 DNS 问题。
改 hosts、换 DNS 服务器都不会有用。

重复采样：

| 端点 | 5 次 |
|---|---|
| `api.github.com` | `200 200 200 200 000` |
| `codeload.github.com` | `301 301 301 301 301` |
| `github.com` | `000 000 000 000 000` |

> 因此 `api.github.com` 约有 20% 概率间歇性失败，所有 API 调用都内置 6 次重试
> （只对网络失败重试，真实的 401/403/404 立即返回，不空转）。

---

## 当前可用的操作

| 操作 | 状态 |
|---|---|
| 读取仓库 / 代码 / issue / PR | ✅ |
| 创建 issue | ✅ |
| 关闭 / 修改 issue | ✅ |
| **写入文件** | ✅ |
| 建分支 | ✅ |
| `git push` | ❌ 网络层封死（与权限无关） |

---

## 配套工具

详见另一台机器上的 `D:\deepseek工作文件夹\ai-connect\`：

| 脚本 | 作用 |
|---|---|
| `gh.ps1` | 读操作：`probe` `repo` `issues` `prs` `ci` `tree` `cat` `search` |
| `gh-write.ps1` | 写操作：`issue` `file` `perm` `close` |
| `net-diag.ps1` | 网络诊断：判别 SNI 审查 vs DNS 投毒 |
| `check-capabilities.ps1` | 8 个外部服务的可达性与密钥体检 |

---

*由 DSH Agent 通过 REST API 写入 · 2026-10-11*
