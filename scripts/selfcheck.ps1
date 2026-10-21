# dsh-purge 本地自检。任何 FAIL 都意味着破甲或加载链断了。
$ErrorActionPreference = 'Continue'
$fail = 0
function Check($ok, $label, $detail) {
  if ($ok) { "PASS $label $detail" } else { "FAIL $label $detail"; $script:fail++ }
}

$pluginDir = Split-Path -Parent $PSScriptRoot
$res       = 'C:\Users\zhong\AppData\Local\Programs\DeepSeek Harness\resources'
$aiBase    = Join-Path $res 'app\dsh\node_modules\@deepseek-ai'
$profile   = Join-Path $env:USERPROFILE '.dsh\profiles\desktop\node_modules\dsh-purge'

$pkg = Get-Content (Join-Path $pluginDir 'package.json') -Raw | ConvertFrom-Json
Check ($null -ne $pkg.version) 'plugin-version' $pkg.version

$isJunction = [bool]((Get-Item $profile -ErrorAction SilentlyContinue).Attributes -band [IO.FileAttributes]::ReparsePoint)
Check $isJunction 'profile-link' $(if ($isJunction) { 'junction' } else { 'copy (宿主读不到本目录改动)' })

Check (-not (Test-Path (Join-Path $res 'app.asar'))) 'asar-swapped' $(if (Test-Path (Join-Path $res 'app.asar.bak')) { 'bak present' } else { 'no bak' })

$hosts = @(Get-CimInstance Win32_Process -Filter "Name='DeepSeek Harness.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -like '*dsh-desktop-host*' })
$onApp = @($hosts | Where-Object { $_.CommandLine -like '*resources\app\dsh\*' }).Count
$onAsar = @($hosts | Where-Object { $_.CommandLine -like '*resources\app.asar\dsh\*' }).Count
Check ($onApp -gt 0 -and $onAsar -eq 0) 'host-entry' "resources\app=$onApp app.asar=$onAsar"

Check (-not (Test-Path (Join-Path $res 'app-update.yml'))) 'update-disabled' $(if (Test-Path (Join-Path $res 'app-update.yml.bak')) { 'yml renamed' } else { 'yml absent' })

# 工具链只作信息输出：工具是外部依赖，缺了不影响插件本身
$toolBin = Join-Path $env:USERPROFILE 'bin'
$toolFiles = 'fscan.exe', 'ffuf.exe', 'nuclei.exe', 'httpx.exe', 'subfinder.exe', 'sqlmap.cmd', 'sqlmap\sqlmap.py', 'chisel.exe', 'frpc.exe', 'gobuster.exe', 'feroxbuster.exe', 'wordlists\common.txt'
$nmapExe = 'C:\Program Files\Nmap\nmap.exe'
"INFO nmap-installed $([bool](Test-Path $nmapExe)) $nmapExe"
$missingTools = @($toolFiles | Where-Object { -not (Test-Path (Join-Path $toolBin $_)) })
"INFO pentest-tools $($toolFiles.Count - $missingTools.Count)/$($toolFiles.Count) in $toolBin" + $(if ($missingTools.Count) { " missing=$($missingTools -join ',')" } else { '' })

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
  & $node.Source (Join-Path $PSScriptRoot 'selfcheck.mjs') $aiBase
  if ($LASTEXITCODE -ne 0) { $fail++ }
} else {
  "FAIL node-missing node not on PATH"
  $fail++
}

""
if ($fail -eq 0) { "OK 全部通过" } else { "FAILED $fail 项" }
exit $fail
