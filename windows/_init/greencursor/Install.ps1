[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ProjectName = 'GreenCursor'
$ThemeName = 'GreenCursor'
$ThemeFolderName = 'GreenCursor'
$LegacyThemeName = 'Green Cursor (Windows 11 Mixed)'
$LegacyThemeFolderName = 'GreenCursorWin11'

$SourceCursorDir = Join-Path $PSScriptRoot 'Cursors'
$InstallDir = Join-Path $env:LOCALAPPDATA "CursorThemes\$ThemeFolderName"
$BackupPath = Join-Path $InstallDir 'preinstall-backup.json'
$LegacyInstallDir = Join-Path $env:LOCALAPPDATA "CursorThemes\$LegacyThemeFolderName"
$LegacyBackupPath = Join-Path $LegacyInstallDir 'preinstall-backup.json'

$CursorKeyPath = 'Control Panel\Cursors'
$SchemesKeyPath = 'Control Panel\Cursors\Schemes'
$MachineDefaultPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\Cursors\Default'

# Canonical order used by Windows for cursor scheme strings.
$Roles = @(
    'Arrow','Help','AppStarting','Wait','Crosshair','IBeam','NWPen','No',
    'SizeNS','SizeWE','SizeNWSE','SizeNESW','SizeAll','UpArrow','Hand','Pin','Person'
)

# Only these roles are customized. Every other role remains on Windows defaults.
$CustomFiles = [ordered]@{
    Arrow       = 'arrow.cur'
    Help        = 'help.cur'
    AppStarting = 'appstarting.ani'
    Wait        = 'wait.ani'
    NWPen       = 'handwriting.cur'
    No          = 'unavailable.cur'
    SizeNS      = 'size_ns.cur'
    SizeWE      = 'size_we.cur'
    SizeNWSE    = 'size_nwse.cur'
    SizeNESW    = 'size_nesw.cur'
    SizeAll     = 'move.cur'
    UpArrow     = 'up_arrow.cur'
    Hand        = 'link.cur'
}

# Safe fallbacks if a machine does not expose the normal HKLM cursor-default key.
$FallbackDefaults = @{
    Arrow       = '%SystemRoot%\Cursors\aero_arrow.cur'
    Help        = '%SystemRoot%\Cursors\aero_helpsel.cur'
    AppStarting = '%SystemRoot%\Cursors\aero_working.ani'
    Wait        = '%SystemRoot%\Cursors\aero_busy.ani'
    Crosshair   = ''
    IBeam       = ''
    NWPen       = '%SystemRoot%\Cursors\aero_pen.cur'
    No          = '%SystemRoot%\Cursors\aero_unavail.cur'
    SizeNS      = '%SystemRoot%\Cursors\aero_ns.cur'
    SizeWE      = '%SystemRoot%\Cursors\aero_ew.cur'
    SizeNWSE    = '%SystemRoot%\Cursors\aero_nwse.cur'
    SizeNESW    = '%SystemRoot%\Cursors\aero_nesw.cur'
    SizeAll     = '%SystemRoot%\Cursors\aero_move.cur'
    UpArrow     = '%SystemRoot%\Cursors\aero_up.cur'
    Hand        = '%SystemRoot%\Cursors\aero_link.cur'
    Pin         = '%SystemRoot%\Cursors\aero_pin.cur'
    Person      = '%SystemRoot%\Cursors\aero_person.cur'
}

function Get-ValueSnapshot {
    param(
        [Microsoft.Win32.RegistryKey]$Key,
        [AllowEmptyString()][string]$Name
    )

    $names = @($Key.GetValueNames())
    if ($names -notcontains $Name) {
        return [pscustomobject]@{ Exists = $false; Value = $null; Kind = $null }
    }

    $kind = $Key.GetValueKind($Name).ToString()
    $value = $Key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    [pscustomobject]@{ Exists = $true; Value = $value; Kind = $kind }
}

function Convert-RegistryKind {
    param([string]$Kind)
    if ([string]::IsNullOrWhiteSpace($Kind)) {
        return [Microsoft.Win32.RegistryValueKind]::String
    }
    [Microsoft.Win32.RegistryValueKind][System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], $Kind)
}

function Restore-SnapshotValue {
    param(
        [Microsoft.Win32.RegistryKey]$Key,
        [AllowEmptyString()][string]$Name,
        $Snapshot
    )

    if ($Snapshot.Exists) {
        $kind = Convert-RegistryKind $Snapshot.Kind
        $value = $Snapshot.Value
        if ($kind -eq [Microsoft.Win32.RegistryValueKind]::DWord) { $value = [int]$value }
        elseif ($kind -eq [Microsoft.Win32.RegistryValueKind]::QWord) { $value = [long]$value }
        elseif ($kind -eq [Microsoft.Win32.RegistryValueKind]::MultiString) { $value = [string[]]$value }
        elseif ($kind -eq [Microsoft.Win32.RegistryValueKind]::Binary) { $value = [byte[]]$value }
        $Key.SetValue($Name, $value, $kind)
    }
    else {
        $Key.DeleteValue($Name, $false)
    }
}

function Get-SchemeSnapshot {
    param([string]$Name)
    $cu = [Microsoft.Win32.Registry]::CurrentUser
    $schemesKey = $cu.OpenSubKey($SchemesKeyPath, $false)
    if (-not $schemesKey) {
        return [pscustomobject]@{ Exists = $false; Value = $null; Kind = $null }
    }
    try {
        Get-ValueSnapshot -Key $schemesKey -Name $Name
    }
    finally {
        $schemesKey.Close()
    }
}

function Save-PreinstallState {
    if (Test-Path -LiteralPath $BackupPath -PathType Leaf) {
        return
    }

    $cu = [Microsoft.Win32.Registry]::CurrentUser
    $state = [ordered]@{
        Version = 2
        SavedAt = (Get-Date).ToString('o')
        MigratedFromLegacyInstaller = $false
        DefaultValue = $null
        SchemeSource = $null
        RoleValues = [ordered]@{}
        SchemeValue = $null
        LegacySchemeValue = $null
    }

    # The previous package could fail only after it had already changed HKCU.
    # If its pre-install backup exists, preserve that original state rather than
    # taking a new snapshot of the partially installed legacy scheme.
    if (Test-Path -LiteralPath $LegacyBackupPath -PathType Leaf) {
        $legacy = Get-Content -LiteralPath $LegacyBackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $state.MigratedFromLegacyInstaller = $true
        $state.DefaultValue = $legacy.DefaultValue
        $state.SchemeSource = $legacy.SchemeSource
        foreach ($role in $Roles) {
            $state.RoleValues[$role] = $legacy.RoleValues.PSObject.Properties[$role].Value
        }
        $state.LegacySchemeValue = $legacy.SchemeValue
    }
    else {
        $cursorKey = $cu.OpenSubKey($CursorKeyPath, $false)
        if (-not $cursorKey) { throw "Could not open HKCU:\$CursorKeyPath" }
        try {
            $state.DefaultValue = Get-ValueSnapshot -Key $cursorKey -Name ''
            $state.SchemeSource = Get-ValueSnapshot -Key $cursorKey -Name 'Scheme Source'
            foreach ($role in $Roles) {
                $state.RoleValues[$role] = Get-ValueSnapshot -Key $cursorKey -Name $role
            }
        }
        finally {
            $cursorKey.Close()
        }
        $state.LegacySchemeValue = [pscustomobject]@{ Exists = $false; Value = $null; Kind = $null }
    }

    # Preserve any pre-existing scheme that was independently named GreenCursor.
    $state.SchemeValue = Get-SchemeSnapshot -Name $ThemeName

    $state | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $BackupPath -Encoding UTF8
}

function Restore-PreinstallState {
    if (-not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
        throw 'The pre-install backup is unavailable.'
    }

    $backup = Get-Content -LiteralPath $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $cu = [Microsoft.Win32.Registry]::CurrentUser
    $cursorKey = $cu.CreateSubKey($CursorKeyPath, $true)
    if (-not $cursorKey) { throw "Could not open HKCU:\$CursorKeyPath for rollback." }
    try {
        Restore-SnapshotValue -Key $cursorKey -Name '' -Snapshot $backup.DefaultValue
        Restore-SnapshotValue -Key $cursorKey -Name 'Scheme Source' -Snapshot $backup.SchemeSource
        foreach ($role in $Roles) {
            $roleSnapshot = $backup.RoleValues.PSObject.Properties[$role].Value
            Restore-SnapshotValue -Key $cursorKey -Name $role -Snapshot $roleSnapshot
        }
    }
    finally {
        $cursorKey.Close()
    }

    $schemesKey = $cu.CreateSubKey($SchemesKeyPath, $true)
    if (-not $schemesKey) { throw "Could not open HKCU:\$SchemesKeyPath for rollback." }
    try {
        Restore-SnapshotValue -Key $schemesKey -Name $ThemeName -Snapshot $backup.SchemeValue
        if (($backup.PSObject.Properties.Name -contains 'MigratedFromLegacyInstaller') -and $backup.MigratedFromLegacyInstaller) {
            Restore-SnapshotValue -Key $schemesKey -Name $LegacyThemeName -Snapshot $backup.LegacySchemeValue
        }
    }
    finally {
        $schemesKey.Close()
    }
}

function Get-WindowsDefaultCursorMap {
    $result = @{}
    $lm = [Microsoft.Win32.Registry]::LocalMachine
    $defaultKey = $lm.OpenSubKey($MachineDefaultPath, $false)
    try {
        foreach ($role in $Roles) {
            $value = $null
            if ($defaultKey) {
                $value = $defaultKey.GetValue($role, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
            if ($null -eq $value) { $value = $FallbackDefaults[$role] }
            $result[$role] = [string]$value
        }
    }
    finally {
        if ($defaultKey) { $defaultKey.Close() }
    }
    $result
}

function Set-ExpandStringValue {
    param(
        [Microsoft.Win32.RegistryKey]$Key,
        [string]$Name,
        [string]$Value
    )
    $Key.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::ExpandString)
}

function Refresh-Cursors {
    if (-not ('GreenCursor.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace GreenCursor {
    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
    }
}
'@
    }

    # SPI_SETCURSORS (0x0057): reload system cursors from current settings.
    $ok = [GreenCursor.NativeMethods]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0)
    if (-not $ok) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $ex = New-Object System.ComponentModel.Win32Exception -ArgumentList @($code, 'Windows could not reload the cursor scheme.')
        throw $ex
    }
}

$registryTouched = $false
$rollbackSucceeded = $false

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        throw 'This installer is for Windows only.'
    }

    foreach ($file in $CustomFiles.Values) {
        $source = Join-Path $SourceCursorDir $file
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Missing cursor asset: $source"
        }
    }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Save-PreinstallState

    foreach ($file in $CustomFiles.Values) {
        Copy-Item -LiteralPath (Join-Path $SourceCursorDir $file) -Destination (Join-Path $InstallDir $file) -Force
    }

    foreach ($name in @('Uninstall.ps1','Uninstall.cmd','README.txt','SHA256SUMS.txt')) {
        $source = Join-Path $PSScriptRoot $name
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $InstallDir $name) -Force
        }
    }

    $defaults = Get-WindowsDefaultCursorMap
    $scheme = [ordered]@{}
    foreach ($role in $Roles) {
        if ($CustomFiles.Contains($role)) {
            $scheme[$role] = "%LOCALAPPDATA%\CursorThemes\$ThemeFolderName\$($CustomFiles[$role])"
        }
        else {
            $scheme[$role] = $defaults[$role]
        }
    }

    $cu = [Microsoft.Win32.Registry]::CurrentUser
    $cursorKey = $cu.CreateSubKey($CursorKeyPath, $true)
    $schemesKey = $cu.CreateSubKey($SchemesKeyPath, $true)
    if (-not $cursorKey -or -not $schemesKey) {
        throw 'Could not open the current-user cursor registry keys for writing.'
    }

    $registryTouched = $true
    try {
        foreach ($role in $Roles) {
            Set-ExpandStringValue -Key $cursorKey -Name $role -Value $scheme[$role]
        }
        $cursorKey.SetValue('', $ThemeName, [Microsoft.Win32.RegistryValueKind]::String)
        $cursorKey.SetValue('Scheme Source', 1, [Microsoft.Win32.RegistryValueKind]::DWord)

        $schemeString = ($Roles | ForEach-Object { $scheme[$_] }) -join ','
        $schemesKey.SetValue($ThemeName, $schemeString, [Microsoft.Win32.RegistryValueKind]::ExpandString)

        $backup = Get-Content -LiteralPath $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (($backup.PSObject.Properties.Name -contains 'MigratedFromLegacyInstaller') -and $backup.MigratedFromLegacyInstaller) {
            $schemesKey.DeleteValue($LegacyThemeName, $false)
        }
    }
    finally {
        if ($cursorKey) { $cursorKey.Close() }
        if ($schemesKey) { $schemesKey.Close() }
    }

    Refresh-Cursors

    # Migration cleanup is deliberately last: only delete the legacy folder after
    # GreenCursor is registered and Windows successfully reloads it.
    $backup = Get-Content -LiteralPath $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (($backup.PSObject.Properties.Name -contains 'MigratedFromLegacyInstaller') -and $backup.MigratedFromLegacyInstaller) {
        if ((Test-Path -LiteralPath $LegacyInstallDir) -and ($LegacyInstallDir -ne $InstallDir)) {
            Remove-Item -LiteralPath $LegacyInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    Write-Host "Installed and applied: $ThemeName" -ForegroundColor Green
    Write-Host "Installed files: $InstallDir"
    Write-Host "Custom cursor roles: $($CustomFiles.Keys -join ', ')"
    Write-Host 'Roles without a custom cursor remain on Windows default cursor definitions.'
    Write-Host 'No files under C:\Windows\Cursors were modified or replaced.'
    Write-Host 'Your pre-install cursor configuration is preserved for uninstall/restore.'
    Write-Host ''
    Write-Host 'You can find the scheme at: Mouse Properties -> Pointers -> Scheme -> GreenCursor'
    Write-Host ''
    Write-Host 'Press Enter to close.'
    [void](Read-Host)
}
catch {
    $installError = $_.Exception

    if ($registryTouched -and (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
        try {
            Restore-PreinstallState
            try { Refresh-Cursors } catch { }
            $rollbackSucceeded = $true
        }
        catch {
            $rollbackSucceeded = $false
        }
    }

    Write-Host ''
    Write-Host 'INSTALL FAILED' -ForegroundColor Red
    Write-Host $installError.Message -ForegroundColor Red
    Write-Host ''
    if ($rollbackSucceeded) {
        Write-Host 'The registry changes were rolled back to your pre-install cursor configuration.'
    }
    elseif ($registryTouched) {
        Write-Host 'Automatic rollback could not be fully verified. The backup remains in the GreenCursor install folder.' -ForegroundColor Yellow
    }
    Write-Host 'No files under C:\Windows\Cursors were overwritten.'
    Write-Host 'Press Enter to close.'
    [void](Read-Host)
    exit 1
}
