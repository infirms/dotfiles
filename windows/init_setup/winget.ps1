winget update
winget install --id=Microsoft.WindowsTerminal -e --accept-source-agreements
winget install --id=Microsoft.PowerShell -e --accept-source-agreements
winget install --id=VideoLAN.VLC -e --accept-source-agreements
winget install --id=Giorgiotani.Peazip -e --accept-source-agreements
winget install --id=DuongDieuPhap.ImageGlass -e --accept-source-agreements
winget install --id=ShareX.ShareX  -e --accept-source-agreements
# note: inf: Upgrade EdgeWebView2Runtime for apps that is using it and uninstall Microsoft.Edge,
# this trick will only work if you have region that allows it to be uninstalled(Germany in my case)
# and windows might be updated to the last version, because base windows installation doesn't have this EU regulation
winget upgrade Microsoft.EdgeWebView2Runtime
Stop-Process -Name "msedge" -Force
winget uninstall Microsoft.Edge

# note: inf: Xbox Identity Provider and Gaming Services are critical for Xbox
winget install 9WZDNCRD1HKW --accept-package-agreements --source msstore
winget install 9MWPM2CQNLHN --accept-package-agreements --source msstore

# note: inf: Xbox and GameBar are critical for Gaming Mode
winget install 9MV0B5HZVK9Z --accept-package-agreements --source msstore
winget install 9NZKPSTSNW4P --accept-package-agreements --source msstore