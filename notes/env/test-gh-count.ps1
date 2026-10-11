<#
  test-gh-count.ps1 - gh.ps1 里 .Count 缺陷的反馈循环

  背景:
    gh.ps1 多处直接写 $items.Count, 但 PowerShell 有一个经典陷阱:
      - 单个对象(非数组) -> .Count 在 PS 5.1 下可用(PSv3+ 给标量加了 Count), 但
        在 $null 上返回 $null, 参与 -f 格式化会变成空字符串
      - $null -> $null.Count 不报错但得到 $null
    结果: 空结果时输出 "--- xxx () ---" 而不是 "--- xxx (0) ---"

  这个 harness 用桩替身(stub)替换 Invoke-GitHub, 固定喂入
  0 / 1 / 3 个元素的返回值, 断言各命令的输出必须包含正确的计数。

  用法:
    powershell -NoProfile -ExecutionPolicy Bypass -File .\test-gh-count.ps1
  退出码: 0=全部通过, 1=有失败
#>
[CmdletBinding()]
param(
  # 注意: 不能叫 -Verbose —— [CmdletBinding()] 自带该公共参数, 重名会直接报错:
  # "A parameter with the name 'Verbose' was defined multiple times for the command."
  [switch]$ShowPass
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$GhPath = Join-Path $PSScriptRoot 'gh.ps1'
if (-not (Test-Path $GhPath)) { Write-Host "找不到 gh.ps1: $GhPath" -ForegroundColor Red; exit 2 }

$script:Pass = 0
$script:Fail = 0
$failures = @()

function Assert-Contains {
  param([string]$Label, [string]$Haystack, [string]$Needle)
  if ($Haystack -like "*$Needle*") {
    $script:Pass++
    if ($ShowPass) { Write-Host "    PASS  $Label" -ForegroundColor Green }
  } else {
    $script:Fail++
    $script:Failures += $Label
    Write-Host "    FAIL  $Label" -ForegroundColor Red
    Write-Host "          期望包含: $Needle" -ForegroundColor DarkGray
    $flat = ($Haystack -replace '\s+',' ').Trim()
    Write-Host "          实际输出: $(if ($flat.Length -gt 160) { $flat.Substring(0,160)+'…' } else { $flat })" -ForegroundColor DarkGray
  }
}

# ---------------------------------------------------------------- 被测代码的桩环境
# 思路: 不真的调 API, 直接把 gh.ps1 里用到的关键函数与变量准备好,
#       然后用 Invoke-Expression 载入 gh.ps1 的 switch 逻辑并断言输出。
#       受控输入 -> 确定性 -> 秒级 -> 无人值守。满足技能要求的"紧凑循环"。

function Build-StubSource {
  # 把 gh.ps1 里的 Invoke-GitHub / 取 token / 参数校验整体替换掉,
  # 只保留 switch 里的命令分支。做法: 读原文, 截取 switch 块。
  $src = Get-Content $GhPath -Raw -Encoding UTF8
  $start = $src.IndexOf('switch ($Command) {')
  if ($start -lt 0) { throw 'gh.ps1 里找不到 switch ($Command) 块, harness 需要更新' }
  $tail = $src.Substring($start)
  return $tail
}

function Invoke-Case {
  param(
    [string]$Command,
    [object]$StubReturn,      # 桩替身对任意 API 路径返回什么
    [string]$Arg = 'owner/repo'
  )
  # 每个 case 跑在独立子进程里最干净, 但为速度改为在当前进程里隔离作用域
  $stub = Build-StubSource
  $code = @"
`$script:Count_Calls = @()
function Invoke-GitHub {
  param([string]`$Path, [string]`$Method = 'GET', `$Body, [int]`$Retries = 1, [switch]`$NoExit)
  `$script:Count_Calls += `$Path
  return `$StubReturn
}
function Split-Repo([string]`$r) { return `$r }
function Show-Table(`$rows, `$cols) {
  `$c = @(`$rows).Count
  Write-Host ("  TABLE rows={0}" -f `$c)
}
`$script:Token = 'stub-token'
`$script:Anon  = `$false
`$script:CanWrite = `$null
`$script:WriteTest = `$null
`$Limit = 20
`$Command = '$Command'
`$Arg = '$Arg'
`$Json = `$false
$stub
"@
  # 关键: gh.ps1 全程用 Write-Host 输出, 而 Write-Host 走的是"信息流"(stream 6),
  # 不进 stdout —— 只写 2>&1 | Out-String 会捕获到空字符串(实测 $out.Length = 0)。
  # 必须用 6>&1 把信息流转成成功流才能捕获。
  $out = & ([scriptblock]::Create($code)) 6>&1 2>&1 | Out-String
  return $out
}

Write-Host "=== gh.ps1 .Count 缺陷反馈循环 ===" -ForegroundColor Cyan
Write-Host "被测: $GhPath`n" -ForegroundColor Gray

# ---------------------------------------------------------------- 用例 1: 空结果
Write-Host "[用例 1] 空结果 (0 个元素)" -ForegroundColor Yellow
foreach ($cmd in @('issues','prs','notif')) {
  $out = Invoke-Case -Command $cmd -StubReturn @()
  $expected = switch ($cmd) {
    'issues' { '(0)' }
    'prs'    { '(0)' }
    'notif'  { '(0)' }
  }
  Assert-Contains -Label "$cmd 空结果应显示 $expected" -Haystack $out -Needle $expected
}

# ---------------------------------------------------------------- 用例 2: 单个元素
Write-Host "`n[用例 2] 单个元素 (1 个)" -ForegroundColor Yellow
$one = [pscustomobject]@{ number=1; title='single'; state='open'; user=[pscustomobject]@{login='x'}; labels=@(); created_at='now'; pull_request=$null; updated_at='now'; reason='r'; subject=[pscustomobject]@{title='t'} }
foreach ($cmd in @('issues','prs','notif')) {
  $out = Invoke-Case -Command $cmd -StubReturn $one
  Assert-Contains -Label "$cmd 单元素应显示 (1)" -Haystack $out -Needle '(1)'
}

# ---------------------------------------------------------------- 用例 3: 多元素
Write-Host "`n[用例 3] 多元素 (3 个)" -ForegroundColor Yellow
$three = @(1..3 | ForEach-Object { [pscustomobject]@{ number=$_; title="t$_"; state='open'; user=[pscustomobject]@{login='x'}; labels=@(); created_at='now'; pull_request=$null; updated_at='now'; reason='r'; subject=[pscustomobject]@{title='t'} } })
foreach ($cmd in @('issues','prs','notif')) {
  $out = Invoke-Case -Command $cmd -StubReturn $three
  Assert-Contains -Label "$cmd 三元素应显示 (3)" -Haystack $out -Needle '(3)'
}

# ---------------------------------------------------------------- 结果
Write-Host "`n=== 结果 ===" -ForegroundColor Cyan
Write-Host ("通过 {0} / 失败 {1}" -f $script:Pass, $script:Fail) -ForegroundColor $(if ($script:Fail -eq 0) { 'Green' } else { 'Red' })
if ($script:Fail -gt 0) {
  Write-Host "`n失败清单:" -ForegroundColor Red
  $script:Failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit 1
}
exit 0
