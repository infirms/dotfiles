Get-Service ssh-agent | Set-Service -StartupType Automatic; Start-Service ssh-agent

$sshpath = (Get-Command ssh.exe).path -replace '\\','/'
git config --global core.sshCommand $sshpath