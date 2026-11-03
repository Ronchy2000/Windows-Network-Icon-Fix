# No live NCSI changes. Windows additionally exercises the actual cmd.exe launchers.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$enableName = ([string][char]0x663E + [char]0x793A + [char]0x7070 + [char]0x8272 + [char]0x5730 + [char]0x7403 + [char]0x56FE + [char]0x6807 + '.bat')
$restoreName = ([string][char]0x6062 + [char]0x590D + [char]0x6B63 + [char]0x5E38 + [char]0x8054 + [char]0x7F51 + [char]0x56FE + [char]0x6807 + '.bat')
$source = [IO.File]::ReadAllText((Join-Path $root $enableName), [Text.Encoding]::UTF8)
$restoreSource = [IO.File]::ReadAllText((Join-Path $root $restoreName), [Text.Encoding]::UTF8)
$marker = ':__NCSI_POWERSHELL__'
$payload = $source.Substring($source.LastIndexOf($marker) + $marker.Length)
$restorePayload = $restoreSource.Substring($restoreSource.LastIndexOf($marker) + $marker.Length)
if ($payload -cne $restorePayload) { throw 'Enable and restore must use the same tested payload' }
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($payload, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
# Load definitions and constants without running the production entrypoint.
. ([ScriptBlock]::Create($payload.Replace('$global:NcsiFixExitCode = Invoke-IconMode -Mode $env:NCSI_ICON_MODE', '')))

class IconFaults {
    [int]$Count = 0
    [int]$FailOn = 0
    [int]$IgnoreOn = 0
    [int]$WrongKindOn = 0
    [bool]$DenyDeletes = $false
}
class IconKey {
    [hashtable]$Values = @{}
    [hashtable]$Kinds = @{}
    [IconFaults]$Faults
    IconKey([IconFaults]$faults) { $this.Faults = $faults }
    [object] GetValue([string]$name, [object]$fallback, [Microsoft.Win32.RegistryValueOptions]$options) { return $this.Values[$name] }
    [string[]] GetValueNames() { return @($this.Values.Keys) }
    [Microsoft.Win32.RegistryValueKind] GetValueKind([string]$name) { return $this.Kinds[$name] }
    [void] SetValue([string]$name, [object]$value, [Microsoft.Win32.RegistryValueKind]$kind) {
        $this.Faults.Count++
        if ($this.Faults.Count -eq $this.Faults.FailOn) { throw 'Simulated write failure' }
        if ($this.Faults.Count -eq $this.Faults.IgnoreOn) { return }
        $this.Values[$name] = $value
        $this.Kinds[$name] = $kind
        if ($this.Faults.Count -eq $this.Faults.WrongKindOn) { $this.Kinds[$name] = [Microsoft.Win32.RegistryValueKind]::ExpandString }
    }
    [void] DeleteValue([string]$name, [bool]$throwOnMissing) {
        $this.Faults.Count++
        if ($this.Faults.DenyDeletes -or $this.Faults.Count -eq $this.Faults.FailOn) { throw 'Simulated delete failure' }
        $this.Values.Remove($name)
        $this.Kinds.Remove($name)
    }
    [void] Flush() {}
    [void] Dispose() {}
}
function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw ($Message + "`n" + ($script:Messages -join "`n")) }
}
function Write-Status([string]$Message) { $script:Messages.Add($Message) }
function Test-IsAdministrator { return $script:IsAdmin }
function Open-NcsiKey([string]$SubKey, [bool]$Writable = $false) {
    if ($SubKey -eq $script:InternetPath) { return $script:Internet }
    if ($SubKey -eq $script:PolicyPath) { return $script:Policy }
    throw 'Unexpected registry path'
}
function New-IconKey([string]$SubKey) {
    Assert-True ($SubKey -eq $script:PolicyPath) 'Only the NCSI policy key may be created'
    $script:Policy = [IconKey]::new($script:Faults)
    return $script:Policy
}
function Export-IconRegistry([string]$SubKey, [string]$Path) {
    $script:Exports++
    Assert-True ($script:Faults.Count -eq 0) 'Backup must precede registry changes'
    if ($script:ExportFails) { throw 'Simulated backup failure' }
    [IO.File]::WriteAllText($Path, 'Simulated registry export')
}
function Reset-Scenario {
    if (Test-Path -LiteralPath $script:BackupRoot) { Remove-Item -LiteralPath $script:BackupRoot -Recurse -Force }
    $script:Faults = [IconFaults]::new()
    $script:Internet = [IconKey]::new($script:Faults)
    $script:Internet.Values = @{ EnableActiveProbing = 1; ActiveWebProbeHost = 'untouched.example' }
    $script:Internet.Kinds = @{ EnableActiveProbing = [Microsoft.Win32.RegistryValueKind]::DWord; ActiveWebProbeHost = [Microsoft.Win32.RegistryValueKind]::String }
    $script:Policy = [IconKey]::new($script:Faults)
    $script:Policy.Values = @{ NoActiveProbe = 0; UnrelatedPolicy = 42 }
    $script:Policy.Kinds = @{ NoActiveProbe = [Microsoft.Win32.RegistryValueKind]::DWord; UnrelatedPolicy = [Microsoft.Win32.RegistryValueKind]::DWord }
    $script:Exports = 0
    $script:ExportFails = $false
    $script:IsAdmin = $true
    $script:Messages = [Collections.Generic.List[string]]::new()
}
function Assert-OriginalState {
    Assert-True ($script:Internet.Values.EnableActiveProbing -eq 1) 'Original active probing flag must be restored'
    Assert-True ($script:Policy.Values.NoActiveProbe -eq 0) 'Original policy must be restored'
    Assert-True (-not $script:Policy.Values.ContainsKey('DisablePassivePolling')) 'New policy must be removed'
    Assert-True ($script:Internet.Values.ActiveWebProbeHost -eq 'untouched.example' -and $script:Policy.Values.UnrelatedPolicy -eq 42) 'Unrelated configuration must be preserved'
}
function Assert-EnabledState {
    Assert-True ($script:Internet.Values.EnableActiveProbing -eq 0 -and $script:Policy.Values.NoActiveProbe -eq 1 -and $script:Policy.Values.DisablePassivePolling -eq 1) 'All mode values must be set'
}
function Assert-NoWrites {
    Assert-True ($script:Faults.Count -eq 0) 'Blocked operation must not change registry values'
}
function New-LegacyBackup([bool]$PolicyAbsent) {
    $directory = Join-Path $script:BackupRoot '20260801-153000'
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $script:BackupRoot 'latest.txt'), '20260801-153000')
    $internetReg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\$script:InternetPath]`r`n`"EnableActiveProbing`"=dword:00000001`r`n"
    [IO.File]::WriteAllText((Join-Path $directory 'Internet.reg'), $internetReg, [Text.Encoding]::Unicode)
    if ($PolicyAbsent) {
        [IO.File]::WriteAllText((Join-Path $directory 'policy-key-absent.flag'), 'absent')
    } else {
        $policyReg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\$script:PolicyPath]`r`n`"NoActiveProbe`"=dword:00000000`r`n"
        [IO.File]::WriteAllText((Join-Path $directory 'Policy.reg'), $policyReg, [Text.Encoding]::Unicode)
    }
    return $directory
}

$scratch = Join-Path ([IO.Path]::GetTempPath()) ('ncsi-mode-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
$script:BackupRoot = Join-Path $scratch 'backups'
$oldScript = $env:NCSI_FIX_SCRIPT
$env:NCSI_FIX_SCRIPT = Join-Path $scratch 'test.bat'
try {
    Reset-Scenario
    $script:IsAdmin = $false
    Assert-True ((Invoke-IconMode Enable) -eq 1) 'Non-admin mode must fail'
    Assert-NoWrites
    Write-Host 'PASS: offline mode elevation check'

    Reset-Scenario
    Assert-True ((Invoke-IconMode Enable) -eq 0) 'Enable must succeed'
    Assert-EnabledState
    $directory = Get-IconBackupDirectory $script:BackupRoot
    $originalJson = [IO.File]::ReadAllText((Join-Path $directory 'state.json'))
    Assert-True ((Invoke-IconMode Enable) -eq 0) 'Repeated enable must succeed'
    Assert-True ($script:Exports -eq 2) 'Repeated enable must reuse both original key exports'
    Assert-True ([IO.File]::ReadAllText((Join-Path $directory 'state.json')) -ceq $originalJson) 'Original snapshot must not be overwritten'
    Assert-True ((Invoke-IconMode Restore) -eq 0) 'Restore must succeed'
    Assert-OriginalState
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:BackupRoot 'latest.txt'))) 'Successful restore must clear the pointer'
    Assert-True (Test-Path -LiteralPath (Join-Path $directory 'state.json')) 'Historical snapshot must remain'
    Write-Host 'PASS: enable, repeat, verified restore and backup retention'

    Reset-Scenario
    $script:Policy = $null
    Assert-True ((Invoke-IconMode Enable) -eq 0) 'Absent policy key must be handled'
    Assert-True ((Invoke-IconMode Restore) -eq 0) 'Absent original policy values must restore'
    Assert-True ($script:Policy.Values.Count -eq 0) 'Created policy values must be deleted'
    Write-Host 'PASS: originally absent policy key'

    Reset-Scenario
    $script:Internet.Values.EnableActiveProbing = '%ORIGINAL%'
    $script:Internet.Kinds.EnableActiveProbing = [Microsoft.Win32.RegistryValueKind]::ExpandString
    Assert-True ((Invoke-IconMode Enable) -eq 0 -and (Invoke-IconMode Restore) -eq 0) 'Original value type must round trip'
    Assert-True ($script:Internet.Values.EnableActiveProbing -ceq '%ORIGINAL%' -and $script:Internet.Kinds.EnableActiveProbing -eq [Microsoft.Win32.RegistryValueKind]::ExpandString) 'Unexpanded data and type must be preserved'
    Write-Host 'PASS: exact original value type'

    Reset-Scenario
    $script:ExportFails = $true
    Assert-True ((Invoke-IconMode Enable) -eq 1) 'Failed backup must abort enable'
    Assert-NoWrites
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $script:BackupRoot 'latest.txt'))) 'Failed backup must not publish a pointer'
    Write-Host 'PASS: backup failure before any changes'

    foreach ($fault in @('write', 'readback', 'type')) {
        Reset-Scenario
        if ($fault -eq 'write') { $script:Faults.FailOn = 2 }
        if ($fault -eq 'readback') { $script:Faults.IgnoreOn = 2 }
        if ($fault -eq 'type') { $script:Faults.WrongKindOn = 2 }
        Assert-True ((Invoke-IconMode Enable) -eq 1) ('Fault must abort enable: ' + $fault)
        Assert-OriginalState
        Assert-True (Test-Path -LiteralPath (Join-Path $script:BackupRoot 'latest.txt')) 'Failed operation must retain recovery pointer'
    }
    Write-Host 'PASS: rollback after partial writes, readback and type failures'

    Reset-Scenario
    Assert-True ((Invoke-IconMode Enable) -eq 0) 'Setup must enable mode'
    $script:Faults.DenyDeletes = $true
    Assert-True ((Invoke-IconMode Restore) -eq 1) 'Delete failure must not report successful restore'
    Assert-EnabledState
    Assert-True (Test-Path -LiteralPath (Join-Path $script:BackupRoot 'latest.txt')) 'Failed restore must retain recovery pointer'
    Write-Host 'PASS: failed deletion is detected and restore rolls back'

    foreach ($badPointer in @('', '..\outside', '20000101-000000')) {
        Reset-Scenario
        New-Item -ItemType Directory -Path $script:BackupRoot | Out-Null
        [IO.File]::WriteAllText((Join-Path $script:BackupRoot 'latest.txt'), $badPointer)
        Assert-True ((Invoke-IconMode Restore) -eq 1) 'Invalid pointer must not silently reset defaults'
        Assert-NoWrites
    }
    Write-Host 'PASS: invalid and missing backup targets stop restore'

    Reset-Scenario
    Assert-True ((Invoke-IconMode Enable) -eq 0) 'Setup must enable mode'
    $directory = Get-IconBackupDirectory $script:BackupRoot
    [IO.File]::WriteAllText((Join-Path $directory 'state.json'), '{broken')
    $script:Faults.Count = 0
    Assert-True ((Invoke-IconMode Restore) -eq 1) 'Corrupt snapshot must not reset defaults'
    Assert-NoWrites
    Assert-EnabledState
    Write-Host 'PASS: corrupt snapshot preserves current state'

    Reset-Scenario
    Assert-True ((Invoke-IconMode Enable) -eq 0) 'Setup must enable mode'
    $directory = Get-IconBackupDirectory $script:BackupRoot
    $jsonPath = Join-Path $directory 'state.json'
    $document = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($jsonPath))
    $document.Values[1].Value = 'invalid-integer'
    [IO.File]::WriteAllText($jsonPath, (ConvertTo-Json -InputObject $document -Depth 8))
    $script:Faults.Count = 0
    Assert-True ((Invoke-IconMode Restore) -eq 1) 'Invalid value data must fail before any writes'
    Assert-NoWrites
    Write-Host 'PASS: all backup data is validated before restore'

    foreach ($absent in @($false, $true)) {
        Reset-Scenario
        $directory = New-LegacyBackup $absent
        $script:Internet.Values.EnableActiveProbing = 0
        $script:Policy.Values.NoActiveProbe = 1
        $script:Policy.Values.DisablePassivePolling = 1
        $script:Policy.Kinds.DisablePassivePolling = [Microsoft.Win32.RegistryValueKind]::DWord
        Assert-True ((Invoke-IconMode Restore) -eq 0) 'Legacy backup must restore without importing unrelated settings'
        Assert-True ($script:Internet.Values.EnableActiveProbing -eq 1) 'Legacy active probing flag mismatch'
        Assert-True (-not $script:Policy.Values.ContainsKey('DisablePassivePolling')) 'Absent legacy passive policy must be removed'
        if ($absent) { Assert-True (-not $script:Policy.Values.ContainsKey('NoActiveProbe')) 'Absent legacy policy must be removed' }
        else { Assert-True ($script:Policy.Values.NoActiveProbe -eq 0) 'Legacy policy value mismatch' }
        Assert-True ($script:Policy.Values.UnrelatedPolicy -eq 42) 'Legacy restore must preserve unrelated policies'
    }
    Write-Host 'PASS: legacy backups with existing and absent policies'

    Reset-Scenario
    $directory = New-LegacyBackup $true
    Remove-Item -LiteralPath (Join-Path $directory 'policy-key-absent.flag')
    Assert-True ((Invoke-IconMode Restore) -eq 1) 'Incomplete legacy backup must stop restore'
    Assert-NoWrites
    Write-Host 'PASS: incomplete legacy backup stops safely'

    Reset-Scenario
    $script:Internet.Values.EnableActiveProbing = 0
    $script:Policy.Values.NoActiveProbe = 1
    $script:Policy.Values.DisablePassivePolling = 1
    $script:Policy.Kinds.DisablePassivePolling = [Microsoft.Win32.RegistryValueKind]::DWord
    Assert-True ((Invoke-IconMode Restore) -eq 0) 'No pointer must use documented fallback'
    Assert-True ($script:Internet.Values.EnableActiveProbing -eq 1) 'Fallback must enable active probing'
    Assert-True (-not $script:Policy.Values.ContainsKey('NoActiveProbe') -and -not $script:Policy.Values.ContainsKey('DisablePassivePolling')) 'Fallback must remove both mode policies'
    Write-Host 'PASS: no-backup fallback'

    if ($env:OS -eq 'Windows_NT') {
        $folder = Join-Path $scratch ('space (&) ! ' + [char]0x6D4B + [char]0x8BD5)
        New-Item -ItemType Directory -Path $folder | Out-Null
        foreach ($modeSource in @($source, $restoreSource)) {
            foreach ($code in @(0, 1)) {
                $testBat = Join-Path $folder ('mode-' + [Guid]::NewGuid().ToString('N') + '.bat')
                $replacement = "Write-Status 'mode launcher smoke test'; `$global:NcsiFixExitCode = $code"
                $testSource = $modeSource.Replace('$global:NcsiFixExitCode = Invoke-IconMode -Mode $env:NCSI_ICON_MODE', $replacement)
                [IO.File]::WriteAllText($testBat, ($testSource -replace '\r?\n', "`r`n"), [Text.UTF8Encoding]::new($false))
                $start = [Diagnostics.ProcessStartInfo]::new()
                $start.FileName = $env:ComSpec
                $start.Arguments = '/d /c ""' + $testBat + '""'
                $start.UseShellExecute = $false
                $start.RedirectStandardInput = $true
                $start.RedirectStandardOutput = $true
                $start.RedirectStandardError = $true
                $start.EnvironmentVariables['TEMP'] = $scratch
                $process = [Diagnostics.Process]::Start($start)
                $process.StandardInput.WriteLine('x')
                $process.StandardInput.Close()
                $stdout = $process.StandardOutput.ReadToEndAsync()
                $stderr = $process.StandardError.ReadToEndAsync()
                if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Mode launcher timed out' }
                $text = $stdout.Result + $stderr.Result
                Assert-True ($process.ExitCode -eq $code) ('Mode launcher exit code mismatch: ' + $text)
                Assert-True ($text -match 'mode launcher smoke test' -and $text -match 'Press any key') ('Mode launcher output/pause missing: ' + $text)
                $process.Dispose()
            }
        }
        Write-Host 'PASS: real Windows enable/restore launchers with complex paths'
    } else { Write-Host 'SKIP: cmd.exe launchers require Windows' }
} finally {
    $env:NCSI_FIX_SCRIPT = $oldScript
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
Write-Host 'All offline mode checks passed.'
exit 0
