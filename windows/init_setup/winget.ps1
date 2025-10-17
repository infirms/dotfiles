winget update
winget install --id=Microsoft.WindowsTerminal -e --accept-source-agreements
winget install --id=Microsoft.PowerShell -e --accept-source-agreements
winget install --id=VideoLAN.VLC -e --accept-source-agreements
winget install --id=Giorgiotani.Peazip -e --accept-source-agreements
winget install --id=DuongDieuPhap.ImageGlass -e --accept-source-agreements

# note: inf: Upgrade EdgeWebView2Runtime for apps that is using it and uninstall Microsoft.Edge,
# this trick will only work if you have region that allows it to be uninstalled(Germany in my case)
# and windows might be updated to the last version, because base windows installation doesn't have this EU regulation
winget upgrade Microsoft.EdgeWebView2Runtime
winget uninstall Microsoft.Edge

# note: inf: Xbox and GameBar is critical for Gaming Mode
winget install 9MV0B5HZVK9Z --accept-package-agreements
winget install 9NZKPSTSNW4P --accept-package-agreements