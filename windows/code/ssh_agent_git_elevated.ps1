Get-Service ssh-agent | Set-Service -StartupType Automatic; Start-Service ssh-agent
git config --global core.sshCommand (Get-Command ssh.exe).Source.replace("\","/")