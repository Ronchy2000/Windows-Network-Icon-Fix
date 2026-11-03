# Runs on Windows PowerShell 5.1 and PowerShell 7. No Pester or live registry writes.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = [IO.File]::ReadAllText((Join-Path $root 'modifyRegistryAndRestart.bat'), [Text.Encoding]::UTF8)
$marker = ':__NCSI_POWERSHELL__'
$payload = $source.Substring($source.LastIndexOf($marker) + $marker.Length)
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($payload, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($function in $ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
    . ([ScriptBlock]::Create($function.Extent.Text))
}
$productionLogger = ${function:Write-Status}
$productionExport = ${function:Export-NcsiBackup}

class FakeRegistryKey {
    [hashtable]$Values = @{}
    [hashtable]$Kinds = @{}
    [int]$SetCount = 0
    [int]$FailOnSet = 0
    [bool]$IgnoreFirstWrite = $false
    [bool]$WrongTypeOnFirstWrite = $false
    [bool]$DenyAllWrites = $false
    [bool]$Disposed = $false
    [object] GetValue([string]$name) { return $this.Values[$name] }
    [object] GetValue([string]$name, [object]$defaultValue, [Microsoft.Win32.RegistryValueOptions]$options) {
        return $this.Values[$name]
    }
    [string[]] GetValueNames() { return @($this.Values.Keys) }
    [Microsoft.Win32.RegistryValueKind] GetValueKind([string]$name) { return $this.Kinds[$name] }
    [void] SetValue([string]$name, [object]$value, [Microsoft.Win32.RegistryValueKind]$kind) {
        $this.SetCount++
        if ($this.DenyAllWrites -or $this.SetCount -eq $this.FailOnSet) { throw 'Simulated access denied' }
        if ($this.IgnoreFirstWrite -and $this.SetCount -eq 1) { return }
        $this.Values[$name] = $value
        $this.Kinds[$name] = $kind
        if ($this.WrongTypeOnFirstWrite -and $this.SetCount -eq 1) {
            $this.Kinds[$name] = [Microsoft.Win32.RegistryValueKind]::ExpandString
        }
    }
    [void] DeleteValue([string]$name, [bool]$throwOnMissing) {
        if ($this.DenyAllWrites) { throw 'Simulated delete denied' }
        $this.Values.Remove($name)
        $this.Kinds.Remove($name)
    }
    [void] Flush() {}
    [void] Dispose() { $this.Disposed = $true }
}

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Write-Status([string]$Message) { $script:Messages.Add($Message) }
function Test-IsAdministrator { return $script:IsAdmin }
function Write-NetworkDiagnostics {}
function Open-NcsiKey([string]$SubKey, [bool]$Writable = $false) {
    if ($SubKey.StartsWith('SOFTWARE\')) { return $script:Policy }
    return $script:Key
}
function Export-NcsiBackup([string]$SubKey, [string]$Path) {
    $script:BackupCount++
    Assert-True ($script:Key.SetCount -eq 0) 'Backup must precede all writes'
    if ($script:BackupFails) { throw 'Simulated backup failure' }
}
function Invoke-WebRequest {
    param($Uri, [switch]$UseBasicParsing, $TimeoutSec, $MaximumRedirection, $ErrorAction)
    Assert-True $UseBasicParsing 'Windows PowerShell must use basic parsing'
    Assert-True ($TimeoutSec -eq 10 -and $MaximumRedirection -eq 0) 'Probe must be bounded and reject redirects'
    $script:ProbeCount++
    $mode = $script:LegacyResponse
    $content = 'Microsoft NCSI'
    if ($Uri -like '*msftconnecttest.com*') { $mode = $script:ModernResponse; $content = 'Microsoft Connect Test' }
    if ($mode -eq 'error') { throw 'Simulated timeout, DNS failure or HTTP redirect' }
    if ($mode -eq 'mismatch') { $content = '<html>Sign in</html>' }
    if ($mode -eq 'wrongcase') { $content = $content.ToLowerInvariant() }
    if ($mode -eq 'newline') { $content += "`n" }
    return [pscustomobject]@{ StatusCode = 200; Content = $content }
}
function Reset-Scenario {
    $script:Messages = [Collections.Generic.List[string]]::new()
    $script:IsAdmin = $true
    $script:Policy = $null
    $script:Key = [FakeRegistryKey]::new()
    $script:Key.Values = @{ EnableActiveProbing = 0; ActiveWebProbeHost = 'original.example'; ActiveWebProbeContent = '%Original%' }
    $script:Key.Kinds = @{
        EnableActiveProbing = [Microsoft.Win32.RegistryValueKind]::DWord
        ActiveWebProbeHost = [Microsoft.Win32.RegistryValueKind]::String
        ActiveWebProbeContent = [Microsoft.Win32.RegistryValueKind]::ExpandString
    }
    $script:LegacyResponse = 'ok'
    $script:ModernResponse = 'ok'
    $script:BackupFails = $false
    $script:BackupCount = 0
    $script:ProbeCount = 0
}
function Assert-OriginalValues {
    Assert-True ($script:Key.Values.Count -eq 3) 'Rollback must remove newly created values'
    Assert-True ($script:Key.Values.EnableActiveProbing -eq 0) 'Rollback must restore DWORD'
    Assert-True ($script:Key.Values.ActiveWebProbeHost -eq 'original.example') 'Rollback must restore original host'
    Assert-True ($script:Key.Values.ActiveWebProbeContent -ceq '%Original%') 'Rollback must preserve unexpanded text'
    Assert-True ($script:Key.Kinds.ActiveWebProbeContent -eq [Microsoft.Win32.RegistryValueKind]::ExpandString) 'Rollback must restore value type'
}
function Assert-NoWrites {
    Assert-True ($script:Key.SetCount -eq 0 -and $script:BackupCount -eq 0) 'Blocked run must not write or back up'
}

$scratch = Join-Path ([IO.Path]::GetTempPath()) ('ncsi-test-' + [Guid]::NewGuid().ToString('N'))
$originalLogDir = $env:NCSI_FIX_LOG_DIR
$originalLog = $env:NCSI_FIX_LOG
New-Item -ItemType Directory -Path $scratch | Out-Null
$env:NCSI_FIX_LOG_DIR = $scratch
try {
    Reset-Scenario
    $script:IsAdmin = $false
    Assert-True ((Invoke-NcsiFix) -eq 1) 'Non-admin run must fail'
    Assert-NoWrites
    Assert-True ($script:ProbeCount -eq 0) 'Non-admin run must not probe'
    Write-Host 'PASS: missing administrator permissions'

    Reset-Scenario
    $script:Policy = [FakeRegistryKey]::new()
    $script:Policy.Values.NoActiveProbe = 1
    Assert-True ((Invoke-NcsiFix) -eq 2) 'Policy must block changes'
    Assert-NoWrites
    Assert-True $script:Policy.Disposed 'Policy handle must be closed'
    Write-Host 'PASS: group policy block'

    Reset-Scenario
    $script:Key = $null
    Assert-True ((Invoke-NcsiFix) -eq 1) 'Missing NCSI registry key must fail'
    Assert-True ($script:BackupCount -eq 0 -and $script:ProbeCount -eq 0) 'Missing key must stop before network or backup operations'
    Write-Host 'PASS: missing registry key'

    foreach ($mode in @('error', 'mismatch', 'wrongcase', 'newline')) {
        Reset-Scenario
        $script:LegacyResponse = $mode
        $script:ModernResponse = $mode
        Assert-True ((Invoke-NcsiFix) -eq 2) ('Invalid probes must block changes: ' + $mode)
        Assert-NoWrites
        Assert-True ($script:ProbeCount -eq 2) 'Both candidates must be tried'
        Assert-True $script:Key.Disposed 'Registry handle must be closed'
    }
    Write-Host 'PASS: unreachable, redirected, captive-portal and inexact probe responses'

    Reset-Scenario
    Assert-True ((Invoke-NcsiFix) -eq 0) 'Legacy probe success must write values'
    Assert-True ($script:BackupCount -eq 1 -and $script:Key.SetCount -eq 7) 'Must back up once and verify seven values'
    Assert-True ($script:Key.Values.ActiveWebProbeHost -eq 'www.msftncsi.com') 'Legacy host must match the probe'
    Assert-True ($script:Key.Values.ActiveWebProbeHostV6 -eq 'ipv6.msftncsi.com') 'IPv6 host must use the same candidate'
    Assert-True ($script:Key.Kinds.EnableActiveProbing -eq [Microsoft.Win32.RegistryValueKind]::DWord) 'Probing flag must be DWORD'
    Assert-True $script:Key.Disposed 'Success must close the registry handle'
    Write-Host 'PASS: successful backup, write and readback'

    Reset-Scenario
    $script:LegacyResponse = 'error'
    Assert-True ((Invoke-NcsiFix) -eq 0) 'Modern endpoint must be used when legacy fails'
    Assert-True ($script:Key.Values.ActiveWebProbeHost -eq 'www.msftconnecttest.com') 'Fallback host mismatch'
    Assert-True ($script:Key.Values.ActiveWebProbePath -eq 'connecttest.txt') 'Fallback path mismatch'
    Assert-True ($script:Key.Values.ActiveWebProbeContentV6 -eq 'Microsoft Connect Test') 'Fallback content mismatch'
    Write-Host 'PASS: modern endpoint fallback'

    Reset-Scenario
    $script:BackupFails = $true
    Assert-True ((Invoke-NcsiFix) -eq 1) 'Backup failure must stop the repair'
    Assert-True ($script:Key.SetCount -eq 0) 'Backup failure must leave registry unchanged'
    Write-Host 'PASS: backup failure'

    foreach ($mode in @('partial-write', 'readback', 'value-type')) {
        Reset-Scenario
        if ($mode -eq 'partial-write') { $script:Key.FailOnSet = 4 }
        if ($mode -eq 'readback') { $script:Key.IgnoreFirstWrite = $true }
        if ($mode -eq 'value-type') { $script:Key.WrongTypeOnFirstWrite = $true }
        Assert-True ((Invoke-NcsiFix) -eq 1) ('Write failure must be reported: ' + $mode)
        Assert-OriginalValues
        Write-Host ('PASS: rollback after ' + $mode + ' failure')
    }

    Reset-Scenario
    $script:Key.DenyAllWrites = $true
    Assert-True ((Invoke-NcsiFix) -eq 1) 'Persistent access denial must fail'
    Assert-True (($script:Messages -join "`n") -match '\[ERROR\].*\.reg') 'Incomplete rollback must point to the backup'
    Write-Host 'PASS: incomplete rollback warning'

    $env:NCSI_FIX_LOG = Join-Path $scratch 'diagnostic.log'
    $unicodeMessage = 'UTF-8 logging test: ' + [char]0x6D4B + [char]0x8BD5
    & $productionLogger $unicodeMessage
    Assert-True ([IO.File]::ReadAllText($env:NCSI_FIX_LOG, [Text.Encoding]::UTF8).Contains($unicodeMessage)) 'Logger must persist Unicode messages'
    $env:NCSI_FIX_LOG = Join-Path $scratch 'nonexistent-directory/diagnostic.log'
    & $productionLogger 'Simulated unavailable log directory'
    # Logging failure must remain visible without throwing and stopping rollback.
    Write-Host 'PASS: persistent logger'

    if ($env:OS -eq 'Windows_NT') {
        # Exercise the real cmd.exe launcher without touching HKLM or the network.
        # Cover spaces, cmd metacharacters and Unicode in the downloaded file path.
        $folder = Join-Path $scratch ('space (&) ! ' + [char]0x6D4B + [char]0x8BD5)
        New-Item -ItemType Directory -Path $folder | Out-Null
        foreach ($expectedCode in @(0, 2)) {
            $testBat = Join-Path $folder ('launcher-' + $expectedCode + '.bat')
            $replacement = "Write-Status 'launcher smoke test'; `$global:NcsiFixExitCode = $expectedCode"
            $testSource = $source.Replace('$global:NcsiFixExitCode = Invoke-NcsiFix', $replacement)
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
            if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Launcher did not exit within 30 seconds' }
            $text = $stdout.Result + $stderr.Result
            Assert-True ($process.ExitCode -eq $expectedCode) ('Launcher exit code mismatch: ' + $text)
            Assert-True ($text -match 'launcher smoke test' -and $text -match 'Press any key') ('Launcher did not display result and pause: ' + $text)
            $process.Dispose()
        }
        # Export only a dedicated HKCU test key with the real reg.exe; no HKLM changes.
        $testSubKey = 'Software\NcsiFixTest-' + [Guid]::NewGuid().ToString('N')
        $testKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($testSubKey)
        try {
            $testKey.SetValue('TestValue', 'before')
            $testKey.Dispose()
            $exportFunction = $productionExport.ToString().Replace('HKLM\$SubKey', 'HKCU\$SubKey')
            $backup = Join-Path $scratch 'real-export.reg'
            & ([ScriptBlock]::Create($exportFunction)) $testSubKey $backup
            Assert-True ((Get-Content -LiteralPath $backup -Raw) -match 'TestValue') 'Actual reg.exe export must include the original value'
            $didFail = $false
            try { & ([ScriptBlock]::Create($exportFunction)) ($testSubKey + '\Missing') (Join-Path $scratch 'missing.reg') } catch { $didFail = $true }
            Assert-True $didFail 'Actual reg.exe failure must stop changes'
        } finally {
            [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($testSubKey, $false)
        }
        Write-Host 'PASS: Windows launcher and real reg.exe backup success/failure'
    } else {
        Write-Host 'SKIP: cmd.exe launcher and reg.exe require Windows'
    }
} finally {
    $env:NCSI_FIX_LOG_DIR = $originalLogDir
    $env:NCSI_FIX_LOG = $originalLog
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
Write-Host 'All checks passed.'
exit 0
