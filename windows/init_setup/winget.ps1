winget update
winget install --id=Microsoft.WindowsTerminal -e --accept-source-agreements
winget install --id=RustDesk.RustDesk -e --accept-source-agreements
winget install --id=VideoLAN.VLC -e --accept-source-agreements
winget install --id=Giorgiotani.Peazip -e --accept-source-agreements
winget install --id=DuongDieuPhap.ImageGlass -e --accept-source-agreements
winget install --id=Microsoft.PowerShell -e --accept-source-agreements

winget upgrade Microsoft.EdgeWebView2Runtime
winget uninstall Microsoft.Edge