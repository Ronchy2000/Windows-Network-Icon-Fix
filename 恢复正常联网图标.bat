@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title Windows Network Icon Mode - Restore
set "NCSI_FIX_SCRIPT=%~f0"
set "NCSI_ICON_MODE=Restore"
set "NCSI_FIX_LOG_DIR=%TEMP%\Windows-Network-Icon-Fix"
if not defined TEMP set "NCSI_FIX_LOG_DIR=%SystemRoot%\Temp\Windows-Network-Icon-Fix"
if not exist "%NCSI_FIX_LOG_DIR%\" mkdir "%NCSI_FIX_LOG_DIR%"
if not exist "%NCSI_FIX_LOG_DIR%\" goto log_failed
set "NCSI_FIX_LOG=%NCSI_FIX_LOG_DIR%\diagnostic-%RANDOM%-%RANDOM%.log"
> "%NCSI_FIX_LOG%" echo Windows Network Icon Mode 2.0.0 - Restore
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

$script:InternetPath = 'SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet'
$script:PolicyPath = 'SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator'
$script:Targets = @(
    @{ SubKey = $script:InternetPath; Name = 'EnableActiveProbing' },
    @{ SubKey = $script:PolicyPath; Name = 'NoActiveProbe' },
    @{ SubKey = $script:PolicyPath; Name = 'DisablePassivePolling' }
)

function Get-IconSnapshot {
    foreach ($target in $script:Targets) {
        $key = Open-NcsiKey $target.SubKey
        try {
            $state = [pscustomobject]@{ SubKey = $target.SubKey; Name = $target.Name; Exists = $false; Kind = $null; Value = $null }
            if ($null -ne $key -and $key.GetValueNames() -contains $target.Name) {
                $state.Exists = $true
                $state.Kind = $key.GetValueKind($target.Name).ToString()
                $state.Value = $key.GetValue($target.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
            $state
        } finally {
            if ($null -ne $key) { $key.Dispose() }
        }
    }
}

function New-IconKey {
    param([string]$SubKey)
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
        [Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
    try { return $base.CreateSubKey($SubKey) } finally { $base.Dispose() }
}

function Convert-IconValue {
    param($State)
    if ($null -eq $State.Value) { throw ('备份缺少数据: ' + $State.Name) }
    $kind = [Microsoft.Win32.RegistryValueKind][Enum]::Parse([Microsoft.Win32.RegistryValueKind], $State.Kind)
    $value = $State.Value
    switch ($kind.ToString()) {
        'String'       { $value = [string]$value }
        'ExpandString' { $value = [string]$value }
        'DWord'        { $value = [int]$value }
        'QWord'        { $value = [long]$value }
        'MultiString'  { $value = [string[]]$value }
        'Binary'       { $value = [byte[]]$value }
        'None'         { $value = [byte[]]$value }
    }
    return [pscustomobject]@{ Kind = $kind; Value = $value }
}

function Set-IconValue {
    param($State)
    $key = Open-NcsiKey $State.SubKey $true
    try {
        if ($State.Exists) {
            if ($null -eq $key) {
                $key = New-IconKey $State.SubKey
            }
            $prepared = Convert-IconValue $State
            $kind = $prepared.Kind
            $value = $prepared.Value
            $key.SetValue($State.Name, $value, $kind)
            $key.Flush()
            $actual = $key.GetValue($State.Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            $actualJson = ConvertTo-Json -InputObject $actual -Compress
            $expectedJson = ConvertTo-Json -InputObject $value -Compress
            if ($actualJson -cne $expectedJson -or $key.GetValueKind($State.Name) -ne $kind) {
                throw ('写入校验失败: ' + $State.Name)
            }
        } elseif ($null -ne $key) {
            $key.DeleteValue($State.Name, $false)
            $key.Flush()
            if ($key.GetValueNames() -contains $State.Name) { throw ('删除校验失败: ' + $State.Name) }
        }
        Write-Status ('[OK] 已校验 {0}: exists={1}, value={2}' -f $State.Name, $State.Exists, $State.Value)
    } finally {
        if ($null -ne $key) { $key.Dispose() }
    }
}

function Set-IconState {
    param([array]$Desired)
    $before = @(Get-IconSnapshot)
    try {
        foreach ($state in $Desired) { Set-IconValue $state }
    } catch {
        $failure = $_.Exception.Message
        Write-Status ('[ERROR] ' + $failure + '；正在回滚本次操作。')
        $failed = $false
        foreach ($state in $before) {
            try { Set-IconValue $state } catch {
                $failed = $true
                Write-Status ('[ERROR] 回滚失败 {0}: {1}' -f $state.Name, $_.Exception.Message)
            }
        }
        if ($failed) {
            Write-Status '[ERROR] 自动回滚不完整，请保留 backups 和日志，使用原始 .reg 备份手动恢复。'
        } else {
            Write-Status '[OK] 已回滚到本次操作前的值。'
        }
        throw $failure
    }
}

function Export-IconRegistry {
    param([string]$SubKey, [string]$Path)
    $ErrorActionPreference = 'Continue'
    $output = & "$env:SystemRoot\System32\reg.exe" export "HKLM\$SubKey" $Path 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    foreach ($line in $output) { Write-Status ([string]$line) }
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $Path) -or (Get-Item -LiteralPath $Path).Length -eq 0) {
        throw ('注册表备份失败，未修改任何配置: ' + $Path)
    }
}

function Read-LegacyIconValue {
    param([string]$Path, [string]$SubKey, [string]$Name)
    $text = [IO.File]::ReadAllText($Path)
    $inSection = $false
    $foundSection = $false
    $state = [pscustomobject]@{ SubKey = $SubKey; Name = $Name; Exists = $false; Kind = $null; Value = $null }
    foreach ($line in ($text -split '\r?\n')) {
        if ($line -match '^\[(.+)\]$') {
            $inSection = $Matches[1] -ieq ('HKEY_LOCAL_MACHINE\' + $SubKey)
            if ($inSection) { $foundSection = $true }
        } elseif ($inSection -and $line -match ('^"' + [regex]::Escape($Name) + '"=(.+)$')) {
            $data = $Matches[1]
            if ($data -notmatch '^dword:([0-9a-fA-F]{8})$') {
                throw ('旧版备份中存在不支持自动恢复的值类型，请保留备份手动恢复: ' + $Name)
            }
            $state.Exists = $true
            $state.Kind = 'DWord'
            $state.Value = [Convert]::ToInt32($Matches[1], 16)
        }
    }
    if (-not $foundSection) { throw ('旧版备份缺少预期注册表项: ' + $Path) }
    return $state
}

function Read-IconBackup {
    param([string]$Directory)
    $jsonPath = Join-Path $Directory 'state.json'
    if (Test-Path -LiteralPath $jsonPath) {
        $document = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($jsonPath, [Text.Encoding]::UTF8))
        if ($document.Version -ne 2) { throw '备份版本不受支持。' }
        $states = @($document.Values)
        if ($states.Count -ne 3) { throw '备份条目数量不正确。' }
        for ($i = 0; $i -lt 3; $i++) {
            $state = $states[$i]
            if ($state.SubKey -ine $script:Targets[$i].SubKey -or $state.Name -ine $script:Targets[$i].Name -or
                $state.Exists -isnot [bool]) { throw '备份包含无效条目，未修改注册表。' }
            if ($state.Exists -and $state.Kind -notin @('String', 'ExpandString', 'DWord', 'QWord', 'MultiString', 'Binary', 'None')) {
                throw '备份的注册表类型无效。'
            }
            if ($state.Exists) { $null = Convert-IconValue $state }
        }
        return $states
    }
    # Compatibility with backups from the previous BAT-only version.
    $internetFile = Join-Path $Directory 'Internet.reg'
    $policyFile = Join-Path $Directory 'Policy.reg'
    $absentFile = Join-Path $Directory 'policy-key-absent.flag'
    if (-not (Test-Path -LiteralPath $internetFile)) { throw '原始备份 Internet.reg 缺失，未修改注册表。' }
    if ((Test-Path -LiteralPath $policyFile) -eq (Test-Path -LiteralPath $absentFile)) {
        throw '原始策略备份缺失或标记冲突，未修改注册表。'
    }
    foreach ($target in $script:Targets) {
        if ($target.SubKey -eq $script:InternetPath) {
            Read-LegacyIconValue $internetFile $target.SubKey $target.Name
        } elseif (Test-Path -LiteralPath $policyFile) {
            Read-LegacyIconValue $policyFile $target.SubKey $target.Name
        } else {
            [pscustomobject]@{ SubKey = $target.SubKey; Name = $target.Name; Exists = $false; Kind = $null; Value = $null }
        }
    }
}

function Get-IconBackupDirectory {
    param([string]$Root)
    $latest = Join-Path $Root 'latest.txt'
    if (-not (Test-Path -LiteralPath $latest)) { return $null }
    $name = [IO.File]::ReadAllText($latest).Trim()
    if ($name -notmatch '^\d{8}-\d{6}(?:-[a-fA-F0-9]{32})?$') {
        throw 'backups\latest.txt 无效，请保留备份并检查；未修改注册表。'
    }
    $directory = Join-Path $Root $name
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { throw '备份指针指向的目录不存在，未修改注册表。' }
    return $directory
}

function New-IconBackup {
    param([string]$Root)
    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $name = '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [Guid]::NewGuid().ToString('N')
    $directory = Join-Path $Root $name
    New-Item -ItemType Directory -Path $directory | Out-Null
    $snapshot = @(Get-IconSnapshot)
    Export-IconRegistry $script:InternetPath (Join-Path $directory 'Internet.reg')
    $policy = Open-NcsiKey $script:PolicyPath
    if ($null -ne $policy) {
        $policy.Dispose()
        Export-IconRegistry $script:PolicyPath (Join-Path $directory 'Policy.reg')
    } else {
        [IO.File]::WriteAllText((Join-Path $directory 'policy-key-absent.flag'), 'Policy key was absent.')
    }
    $json = ConvertTo-Json -InputObject @{ Version = 2; Values = $snapshot } -Depth 8
    [IO.File]::WriteAllText((Join-Path $directory 'state.json'), $json, [Text.UTF8Encoding]::new($false))
    $null = @(Read-IconBackup $directory)
    $pending = Join-Path $Root ('latest-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($pending, $name, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $pending -Destination (Join-Path $Root 'latest.txt') -ErrorAction Stop
    return $directory
}

function Invoke-IconMode {
    param([ValidateSet('Enable', 'Restore')][string]$Mode)
    try {
        Write-Status ('Windows Network Icon Mode 2.0.0; mode={0}; OS={1}; PowerShell={2}' -f
            $Mode, [Environment]::OSVersion.Version, $PSVersionTable.PSVersion)
        if (-not (Test-IsAdministrator)) { throw '当前没有管理员权限，请右键 BAT，选择“以管理员身份运行”，并允许 UAC 提示。' }
        $internet = Open-NcsiKey $script:InternetPath
        if ($null -eq $internet) { throw '找不到 NCSI Internet 注册表项。' }
        $internet.Dispose()
        $root = Join-Path ([IO.Path]::GetDirectoryName($env:NCSI_FIX_SCRIPT)) 'backups'
        $directory = Get-IconBackupDirectory $root
        if ($Mode -eq 'Enable') {
            if ($null -eq $directory) { $directory = New-IconBackup $root }
            $null = @(Read-IconBackup $directory)
            Write-Status ('原始备份（重复启用不会覆盖）: ' + $directory)
            $desired = @(for ($i = 0; $i -lt 3; $i++) {
                [pscustomobject]@{ SubKey = $script:Targets[$i].SubKey; Name = $script:Targets[$i].Name;
                    Exists = $true; Kind = 'DWord'; Value = [int]($i -ne 0) }
            })
            Set-IconState $desired
            Write-Status '[OK] 离线图标模式的三项注册表值已修改并校验。请重启 Windows 后观察图标。'
            Write-Status '[INFO] 不会禁用网卡；具体图标和 NCSI 行为取决于系统版本、缓存及组织策略，不能保证图标一定变化。'
        } else {
            if ($null -ne $directory) {
                $desired = @(Read-IconBackup $directory)
                Write-Status ('从原始备份恢复本工具涉及的三项值: ' + $directory)
            } else {
                Write-Status '[WARN] 没有备份指针，将启用主动探测并删除本工具涉及的两项策略值；不会重写探测网址。'
                $desired = @(for ($i = 0; $i -lt 3; $i++) {
                    [pscustomobject]@{ SubKey = $script:Targets[$i].SubKey; Name = $script:Targets[$i].Name;
                        Exists = ($i -eq 0); Kind = 'DWord'; Value = 1 }
                })
            }
            Set-IconState $desired
            if ($null -ne $directory) { Remove-Item -LiteralPath (Join-Path $root 'latest.txt') -ErrorAction Stop }
            Write-Status '[OK] 恢复操作已校验。历史备份保留，请重启 Windows 后观察真实联网状态。'
        }
        return 0
    } catch {
        Write-Status ('[ERROR] ' + $_.Exception.Message)
        return 1
    }
}

$global:NcsiFixExitCode = Invoke-IconMode -Mode $env:NCSI_ICON_MODE
