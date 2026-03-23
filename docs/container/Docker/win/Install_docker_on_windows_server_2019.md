# Install docker on Windows server 2019

## 1. Enable Containers feature 
You need admin rights to run the below command successfully. Open a powershell `as administartor`.

```powershell
Install-WindowsFeature -Name Containers
Restart-Computer   # almost always required
```

## 2. Install the Docker Microsoft Provider (still needed on 2019 in many cases)

Try to run the below command. It may fail, because Install-Module is an extra module of `PowerShell`, and not all
version has this module.

```powershell
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force

# if you don't have the module, you are likely to see the below output
Install-Module : The term 'Install-Module' is not recognized as the name of a cmdlet, function, script file, or
operable program.
```
> To fix this problem, you need to add two modules(e.g. `PowerShellGet & PackageManagement`) into your Powershell.

### 2.1 Install the PowerShellGet & PackageManagement module

You need to get the modules from the official sites:

- PowerShellGet: Go to https://www.powershellgallery.com/packages/PowerShellGet (latest stable is usually 2.2.5 or higher)
- PackageManagement: Go to https://www.powershellgallery.com/packages/PackageManagement (get latest, e.g. 1.4.8+).

Copy both `.nupkg` files, then rename them to `.zip`. Then extract them to 
- C:\Program Files\WindowsPowerShell\Modules\PowerShellGet\2.2.5
- C:\Program Files\WindowsPowerShell\Modules\PackageManagement\1.4.8.1

Renew your powershell moduls:

```powershell
Import-Module PowerShellGet -Force

# check the new modules
Get-Module -ListAvailable PowerShellGet, PackageManagement

# expected output
    Directory: C:\Program Files\WindowsPowerShell\Modules


ModuleType Version    Name                                ExportedCommands
---------- -------    ----                                ----------------
Script     1.4.8.1    PackageManagement                   {Find-Package, Get-Package, Get-PackageProvider, Get-Packa...
Script     2.2.5      PowerShellGet                       {Find-Command, Find-DSCResource, Find-Module, Find-RoleCap...
```

> after this, Install-Module should work.
> 
## 3. Get the docker installer script

```powershell
# go to your home folder

cd 

# download the installer script
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -OutFile install-docker-ce.ps1
.\install-docker-ce.ps1

# Run it (may prompt for confirmation or install dependencies)
.\install-docker-ce.ps1
```

## 4. Test your docker 


```powershell
# Check Docker version (client + server should show)
docker version

# Basic info
docker info

# Quick test with a Windows base image (must match host: ltsc2019 for Server 2019)
docker run --rm mcr.microsoft.com/windows/servercore:ltsc2019 powershell -Command "Write-Host 'Docker works!'"

```

## 5. Common issues

### 5.1 The docker service does not run after reboot

```powershell
# get service status
Get-Service docker
# start it 
Start-Service docker   # if stopped
```