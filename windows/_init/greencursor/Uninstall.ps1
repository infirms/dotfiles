[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$ThemeName = 'GreenCursor'
$ThemeFolderName = 'GreenCursor'
$LegacyThemeName = 'Green Cursor (Windows 11 Mixed)'
$InstallDir = Join-Path $env:LOCALAPPDATA "CursorThemes\$ThemeFolderName"
$BackupPath = Join-Path $InstallDir 'preinstall-backup.json'
$CursorKeyPath = 'Control Panel\Cursors'
$SchemesKeyPath = 'Control Panel\Cursors\Schemes'
$MachineDefaultPath = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\Cursors\Default'

$Roles = @(
    'Arrow','Help','AppStarting','Wait','Crosshair','IBeam','NWPen','No',
    'SizeNS','SizeWE','SizeNWSE','SizeNESW','SizeAll','UpArrow','Hand','Pin','Person'
)

$FallbackDefaults = @{
    Arrow='%SystemRoot%\Cursors\aero_arrow.cur'; Help='%SystemRoot%\Cursors\aero_helpsel.cur'
    AppStarting='%SystemRoot%\Cursors\aero_working.ani'; Wait='%SystemRoot%\Cursors\aero_busy.ani'
    Crosshair=''; IBeam=''; NWPen='%SystemRoot%\Cursors\aero_pen.cur'; No='%SystemRoot%\Cursors\aero_unavail.cur'
    SizeNS='%SystemRoot%\Cursors\aero_ns.cur'; SizeWE='%SystemRoot%\Cursors\aero_ew.cur'
    SizeNWSE='%SystemRoot%\Cursors\aero_nwse.cur'; SizeNESW='%SystemRoot%\Cursors\aero_nesw.cur'
    SizeAll='%SystemRoot%\Cursors\aero_move.cur'; UpArrow='%SystemRoot%\Cursors\aero_up.cur'
    Hand='%SystemRoot%\Cursors\aero_link.cur'; Pin='%SystemRoot%\Cursors\aero_pin.cur'; Person='%SystemRoot%\Cursors\aero_person.cur'
}

function Convert-RegistryKind {
    param([string]$Kind)
    if ([string]::IsNullOrWhiteSpace($Kind)) { return [Microsoft.Win32.RegistryValueKind]::String }
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

function Restore-WindowsDefault {
    $lm = [Microsoft.Win32.Registry]::LocalMachine
    $cu = [Microsoft.Win32.Registry]::CurrentUser
    $defaultKey = $lm.OpenSubKey($MachineDefaultPath, $false)
    $cursorKey = $cu.CreateSubKey($CursorKeyPath, $true)
    try {
        foreach ($role in $Roles) {
            $value = $null
            if ($defaultKey) {
                $value = $defaultKey.GetValue($role, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
            if ($null -eq $value) { $value = $FallbackDefaults[$role] }
            $cursorKey.SetValue($role, [string]$value, [Microsoft.Win32.RegistryValueKind]::ExpandString)
        }
        $cursorKey.SetValue('', 'Windows Default', [Microsoft.Win32.RegistryValueKind]::String)
        $cursorKey.SetValue('Scheme Source', 0, [Microsoft.Win32.RegistryValueKind]::DWord)
    }
    finally {
        if ($defaultKey) { $defaultKey.Close() }
        if ($cursorKey) { $cursorKey.Close() }
    }
}

function Refresh-Cursors {
    if (-not ('GreenCursor.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace GreenCursor {
    public static class NativeMethods {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
    }
}
'@
    }

    $ok = [GreenCursor.NativeMethods]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0)
    if (-not $ok) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        $ex = New-Object System.ComponentModel.Win32Exception -ArgumentList @($code, 'Windows could not reload the restored cursor scheme.')
        throw $ex
    }
}

try {
    $cu = [Microsoft.Win32.Registry]::CurrentUser

    if (Test-Path -LiteralPath $BackupPath -PathType Leaf) {
        $backup = Get-Content -LiteralPath $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json

        $cursorKey = $cu.CreateSubKey($CursorKeyPath, $true)
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
        try {
            Restore-SnapshotValue -Key $schemesKey -Name $ThemeName -Snapshot $backup.SchemeValue
            if (($backup.PSObject.Properties.Name -contains 'MigratedFromLegacyInstaller') -and $backup.MigratedFromLegacyInstaller) {
                Restore-SnapshotValue -Key $schemesKey -Name $LegacyThemeName -Snapshot $backup.LegacySchemeValue
            }
        }
        finally {
            $schemesKey.Close()
        }

        $restoredMessage = 'Restored the exact cursor settings saved before GreenCursor was first installed.'
    }
    else {
        Restore-WindowsDefault
        $schemesKey = $cu.CreateSubKey($SchemesKeyPath, $true)
        try { $schemesKey.DeleteValue($ThemeName, $false) } finally { $schemesKey.Close() }
        $restoredMessage = 'Backup was unavailable, so Windows Default cursor definitions were restored.'
    }

    Refresh-Cursors

    Write-Host ''
    Write-Host 'GreenCursor has been uninstalled.' -ForegroundColor Green
    Write-Host $restoredMessage
    Write-Host 'No original Windows cursor files were modified.'

    # Remove installed files after this PowerShell process exits.
    if (Test-Path -LiteralPath $InstallDir) {
        $quotedDir = $InstallDir.Replace('"','""')
        $cmd = "/c ping 127.0.0.1 -n 3 >nul & rmdir /s /q `"$quotedDir`""
        Start-Process -FilePath $env:ComSpec -ArgumentList $cmd -WindowStyle Hidden
    }

    Write-Host ''
    Write-Host 'Press Enter to close.'
    [void](Read-Host)
}
catch {
    Write-Host ''
    Write-Host 'UNINSTALL FAILED' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    Write-Host 'The GreenCursor backup and files were left in place for recovery.'
    Write-Host 'Press Enter to close.'
    [void](Read-Host)
    exit 1
}
