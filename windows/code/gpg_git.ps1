$gpgpath = (Get-Command gpg.exe).path -replace '\\','/'
git config --global gpg.program $gpgpath