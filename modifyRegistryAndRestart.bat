@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title Windows Network Icon Fix
set "NCSI_FIX_SCRIPT=%~f0"
set "NCSI_FIX_LOG_DIR=%TEMP%\Windows-Network-Icon-Fix"
if not defined TEMP set "NCSI_FIX_LOG_DIR=%SystemRoot%\Temp\Windows-Network-Icon-Fix"
if not exist "%NCSI_FIX_LOG_DIR%\" mkdir "%NCSI_FIX_LOG_DIR%"
if not exist "%NCSI_FIX_LOG_DIR%\" goto log_failed
set "NCSI_FIX_LOG=%NCSI_FIX_LOG_DIR%\diagnostic-%RANDOM%-%RANDOM%.log"
> "%NCSI_FIX_LOG%" echo Windows Network Icon Fix 2.0.0
if errorlevel 1 goto log_failed
echo Log: "%NCSI_FIX_LOG%"
set "NCSI_FIX_POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "NCSI_FIX_POWERSHELL=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%NCSI_FIX_POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false); $source = [IO.File]::ReadAllText($env:NCSI_FIX_SCRIPT, [Text.Encoding]::UTF8); $marker = ':__NCSI_POWERSHELL__'; $offset = $source.LastIndexOf($marker); if ($offset -lt 0) { throw 'Embedded script not found.' }; & ([ScriptBlock]::Create($source.Substring($offset + $marker.Length))); exit $global:NcsiFixExitCode } catch { $message = '[ERROR] ' + $_.Exception.Message; Write-Host $message; Add-Content -LiteralPath $env:NCSI_FIX_LOG -Value $message -Encoding UTF8; exit 1 }" 2> "%NCSI_FIX_LOG%.stderr"
set "NCSI_FIX_EXIT=%ERRORLEVEL%"
type "%NCSI_FIX_LOG%.stderr" >> "%NCSI_FIX_LOG%"
del "%NCSI_FIX_LOG%.stderr" >nul 2>&1
echo.
if not "%NCSI_FIX_EXIT%"=="0" type "%NCSI_FIX_LOG%"
echo Exit code: %NCSI_FIX_EXIT%
echo Log: "%NCSI_FIX_LOG%"
echo Press any key to close this window.
pause >nul
exit /b %NCSI_FIX_EXIT%

:log_failed
echo [ERROR] Cannot create a log in "%NCSI_FIX_LOG_DIR%". Check TEMP permissions and disk space.
echo Press any key to close this window.
pause >nul
exit /b 1

:__NCSI_POWERSHELL__
# The batch launcher above is ASCII; read this UTF-8 payload explicitly.
# Keep Windows PowerShell 5.1 compatibility. Do not restart adapters automatically.
function Write-Status {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Message
    Write-Host $line
    try {
        Add-Content -LiteralPath $env:NCSI_FIX_LOG -Value $line -Encoding UTF8 -ErrorAction Stop
    } catch {
        # Logging failure must not interrupt registry rollback.
        Write-Host ('[WARN] 无法写入日志，请保留窗口报错: ' + $_.Exception.Message)
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } finally {
        $identity.Dispose()
    }
}

function Open-NcsiKey {
    param([string]$SubKey, [bool]$Writable = $false)
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
    try {
        return $base.OpenSubKey($SubKey, $Writable)
    } finally {
        $base.Dispose()
    }
}

function Write-NetworkDiagnostics {
    foreach ($name in @('NlaSvc', 'netprofm', 'Dnscache')) {
        try {
            $service = Get-Service -Name $name -ErrorAction Stop
            Write-Status ('服务 {0}: {1}' -f $name, $service.Status)
        } catch {
            Write-Status ('[WARN] 无法查询服务 {0}: {1}' -f $name, $_.Exception.Message)
        }
    }
    try {
        foreach ($profile in @(Get-NetConnectionProfile -ErrorAction Stop)) {
            Write-Status ('网卡 {0}: IPv4={1}, IPv6={2}' -f
                $profile.InterfaceAlias, $profile.IPv4Connectivity, $profile.IPv6Connectivity)
        }
    } catch {
        Write-Status ('[WARN] 无法查询网络状态: ' + $_.Exception.Message)
    }
}

function Test-WebProbe {
    param([string]$Uri, [string]$ExpectedContent)
    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 10 -MaximumRedirection 0 -ErrorAction Stop
        if ($response.StatusCode -eq 200 -and [string]$response.Content -ceq $ExpectedContent) {
            Write-Status ('[OK] 探测返回预期内容: ' + $Uri)
            return $true
        }
        Write-Status ('[WARN] 探测内容不匹配，可能被代理、认证页或安全软件改写: ' + $Uri)
    } catch {
        Write-Status ('[WARN] 探测失败 {0}: {1}' -f $Uri, $_.Exception.Message)
    }
    return $false
}

function Export-NcsiBackup {
    param([string]$SubKey, [string]$Path)
    # Native stderr in Windows PowerShell 5.1 can produce non-terminating ErrorRecords.
    $ErrorActionPreference = 'Continue'
    $output = & "$env:SystemRoot\System32\reg.exe" export "HKLM\$SubKey" $Path 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    foreach ($line in $output) { Write-Status ([string]$line) }
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $Path) -or (Get-Item -LiteralPath $Path).Length -eq 0) {
        throw '注册表备份失败，未修改任何配置。'
    }
}

function Set-VerifiedValues {
    param($Key, [System.Collections.IDictionary]$Values)
    $snapshot = @{}
    foreach ($name in $Values.Keys) {
        $exists = $Key.GetValueNames() -contains $name
        $snapshot[$name] = @{ Exists = $exists }
        if ($exists) {
            $snapshot[$name].Value = $Key.GetValue($name, $null,
                [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $snapshot[$name].Kind = $Key.GetValueKind($name)
        }
    }
    try {
        foreach ($name in $Values.Keys) {
            $kind = [Microsoft.Win32.RegistryValueKind]::String
            if ($name -eq 'EnableActiveProbing') { $kind = [Microsoft.Win32.RegistryValueKind]::DWord }
            $Key.SetValue($name, $Values[$name], $kind)
        }
        $Key.Flush()
        foreach ($name in $Values.Keys) {
            $kind = [Microsoft.Win32.RegistryValueKind]::String
            if ($name -eq 'EnableActiveProbing') { $kind = [Microsoft.Win32.RegistryValueKind]::DWord }
            if ($Key.GetValue($name) -cne $Values[$name] -or $Key.GetValueKind($name) -ne $kind) {
                throw ('注册表写入校验失败: ' + $name)
            }
            Write-Status ('校验 {0} = {1}' -f $name, $Values[$name])
        }
    } catch {
        $failure = $_.Exception.Message
        Write-Status ('[ERROR] ' + $failure + '；正在恢复本次修改前的值。')
        $rollbackFailed = $false
        foreach ($name in $snapshot.Keys) {
            try {
                $old = $snapshot[$name]
                if ($old.Exists) {
                    $Key.SetValue($name, $old.Value, $old.Kind)
                    if ($Key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) -cne $old.Value -or
                        $Key.GetValueKind($name) -ne $old.Kind) { throw '恢复校验失败' }
                } else {
                    $Key.DeleteValue($name, $false)
                    if ($Key.GetValueNames() -contains $name) { throw '删除校验失败' }
                }
            } catch {
                $rollbackFailed = $true
                Write-Status ('[ERROR] 无法恢复 {0}: {1}' -f $name, $_.Exception.Message)
            }
        }
        try {
            $Key.Flush()
        } catch {
            $rollbackFailed = $true
            Write-Status ('[ERROR] 无法刷新恢复后的注册表: ' + $_.Exception.Message)
        }
        if ($rollbackFailed) {
            Write-Status '[ERROR] 自动恢复不完整，请使用日志中的 .reg 备份恢复。'
        } else {
            Write-Status '[OK] 已恢复本次修改前的值。'
        }
        throw $failure
    }
}

function Invoke-NcsiFix {
    $key = $null
    try {
        Write-Status ('Windows Network Icon Fix 2.0.0; OS={0}; PowerShell={1}' -f
            [Environment]::OSVersion.Version, $PSVersionTable.PSVersion)
        if (-not (Test-IsAdministrator)) {
            throw '当前没有管理员权限。请关闭窗口，右键 BAT，选择“以管理员身份运行”，并允许 UAC 提示。'
        }
        Write-NetworkDiagnostics
        $policy = Open-NcsiKey 'SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator'
        if ($null -ne $policy) {
            try {
                $noActiveProbe = $policy.GetValue('NoActiveProbe')
                Write-Status ('策略 NoActiveProbe = ' + $noActiveProbe)
            } finally {
                $policy.Dispose()
            }
            if ($noActiveProbe -eq 1) {
                Write-Status '[BLOCKED] 组策略 NoActiveProbe=1 禁用了主动探测。请检查组织策略或曾使用的隐私/优化工具；本工具不覆盖此策略。'
                return 2
            }
        }
        $subKey = 'SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet'
        $key = Open-NcsiKey $subKey $true
        if ($null -eq $key) { throw ('找不到注册表项: HKLM\' + $subKey) }
        Write-Status ('当前 EnableActiveProbing = ' + $key.GetValue('EnableActiveProbing'))
        Write-Status ('当前探测: http://{0}/{1}' -f $key.GetValue('ActiveWebProbeHost'), $key.GetValue('ActiveWebProbePath'))

        $candidates = @(
            @{ HostName = 'www.msftncsi.com'; HostV6 = 'ipv6.msftncsi.com'; Path = 'ncsi.txt'; Content = 'Microsoft NCSI' },
            @{ HostName = 'www.msftconnecttest.com'; HostV6 = 'ipv6.msftconnecttest.com'; Path = 'connecttest.txt'; Content = 'Microsoft Connect Test' }
        )
        $selected = $null
        foreach ($candidate in $candidates) {
            $uri = 'http://{0}/{1}' -f $candidate.HostName, $candidate.Path
            if (Test-WebProbe $uri $candidate.Content) {
                $selected = $candidate
                break
            }
        }
        if ($null -eq $selected) {
            Write-Status '[BLOCKED] 两个检测地址均未返回预期内容，未修改注册表。请检查 DNS、代理/VPN、防火墙或网页登录认证；重启电脑不会解除这些拦截。'
            return 2
        }

        $backupName = 'NCSI-backup-{0}-{1}.reg' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [Guid]::NewGuid().ToString('N')
        $backupPath = Join-Path $env:NCSI_FIX_LOG_DIR $backupName
        Export-NcsiBackup $subKey $backupPath
        Write-Status ('原始配置备份: ' + $backupPath)
        Write-Status ('如需恢复，请在管理员终端执行: reg.exe import "{0}"' -f $backupPath)
        $values = [ordered]@{
            ActiveWebProbeContent = $selected.Content
            ActiveWebProbeContentV6 = $selected.Content
            ActiveWebProbeHost = $selected.HostName
            ActiveWebProbeHostV6 = $selected.HostV6
            ActiveWebProbePath = $selected.Path
            ActiveWebProbePathV6 = $selected.Path
            EnableActiveProbing = 1
        }
        Set-VerifiedValues $key $values
        Write-Status '[OK] 注册表修改并校验成功。请重启计算机，或手动重新连接网络后观察图标。'
        Write-Status '[INFO] 本次探测使用当前用户的网络环境；系统服务的代理/IPv6 路径可能不同，写入成功不代表图标已恢复。'
        return 0
    } catch {
        Write-Status ('[ERROR] ' + $_.Exception.Message)
        return 1
    } finally {
        if ($null -ne $key) { $key.Dispose() }
    }
}

$global:NcsiFixExitCode = Invoke-NcsiFix
