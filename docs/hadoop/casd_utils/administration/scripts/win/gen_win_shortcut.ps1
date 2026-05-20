<#
    name: gen_win_shortcut.ps1
    Description : Configuration OpenSSH (GSSAPI/Kerberos) et injection de la fonction kscp.
#>


# --- 1. init var default value ---
$sshDir      = Join-Path $HOME ".ssh"
$configPath  = Join-Path $sshDir "config"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"

# --- 2. Configuration OpenSSH ---
Write-Host "Starting SSH Client config for $env:USERNAME" -ForegroundColor Green
# check if ssh dir exists
if (-not (Test-Path $sshDir)) {
    New-Item -Path $sshDir -ItemType Directory -Force | Out-Null
}

# if config exist already, backup the old verion
if (Test-Path $configPath) {
    Rename-Item -Path $configPath -NewName "config-$timestamp.bak" -Force
}


# 2. Define the default configuration text
$sshConfigText = @"
Host *.casd.fr
    User                        $env:USERNAME
    GSSAPIAuthentication        yes
    GSSAPIDelegateCredentials   yes
    PreferredAuthentications    gssapi-with-mic
"@

# 3. Write the file (overwrites existing, no backup for maximum simplicity)
$sshConfigText | Set-Content $configPath -Encoding utf8

# 4. Set strict permissions (Required by OpenSSH security model)
$acl = Get-Acl $configPath
# Remove inherited permissions
$acl.SetAccessRuleProtection($true, $false)
$identity = "$env:USERDOMAIN\$env:USERNAME"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, "FullControl", "Allow")
$acl.AddAccessRule($rule)
Set-Acl $configPath $acl
Write-Host "SSH Config created and secured for $env:USERNAME" -ForegroundColor Green

# --- 3. Configuration du Profil PowerShell (Non-destructive) ---
Write-Host "Starting user profil config for $env:USERNAME" -ForegroundColor Green

# use powershell native var to get profile file path
if (-not $PROFILE) {
    Write-Error "The PowerShell profil variable is not disponible in the current user session. Stopping the process ..."
    Exit
}

# get parent dir of the profile file
$profileDir = Split-Path $PROFILE -Parent

# check if the profile dir exsits:
if (-not (Test-Path $profileDir)) {
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
}

# code block to be injected into user ps profile
$aliasBlock = @'

# --- configuration CASD ---
Set-Alias kup kupGSSAPI
Set-Alias kdown kdownGSSAPI

function kupGSSAPI {
    <#
        .SYNOPSIS
            create a wrapper for uploading data(e.g. file or directory) to a remote server via SCP with GSSAPI authentification.
        .EXAMPLE
            kup document.txt machine.casd.fr
        .EXAMPLE
            kup -r .\MonDossier machine.casd.fr
        .EXAMPLE
            kup .\MonDossier machine.casd.fr -r -v
    #>

    # 1. Extraction of the option arguments (all arguments start with -)
    $options = $args | Where-Object { $_ -match '^-' }

    # 2. Extraction of the main positional arguments (1st:source, and 2nd:target)
    $positionalArgs = $args | Where-Object { $_ -notmatch '^-' }

    # 3. check if user provide all postitional arguments
    if ($positionalArgs.Count -lt 2) {
        Write-Error "Syntaxe error. Usage example : kup [options] <Source> <TargetHost>"
        return
    }

    $source     = $positionalArgs[0]
    $targetHost = $positionalArgs[1]

    # 4. check if source data exists
    if (-not (Test-Path -Path $source)) {
        Write-Error "Error : The provided data source path does not exist : $source"
        return
    }

    # 5. clean user input of the target path, remove everything after :
    $targetHost = $targetHost -replace ':$', ''

    # 6. build the scp command args table
    $scpArgs = @("-o", "GSSAPIAuthentication=yes")
    if ($options) {
        $scpArgs += $options
    }
    $scpArgs += $source
    $scpArgs += "${env:USERNAME}@${targetHost}:/home/${env:USERNAME}/"

    # 6. run the scp command
    Write-Host "Uploading data via SCP/GSSAPI to remote server ${targetHost}..." -ForegroundColor Cyan
    scp @scpArgs
}

function kdownGSSAPI {
    <#
        .SYNOPSIS
            create a wrapper for downloading data(e.g. file or directory) from a remote server to local filesystem.
        .EXAMPLE
            kdown machine.casd.fr:/tmp/rapport.pdf C:\Temp\
        .EXAMPLE
            kdown -r machine.casd.fr:/tmp/data_dir .
    #>
    $options = $args | Where-Object { $_ -match '^-' }
    $positionalArgs = $args | Where-Object { $_ -notmatch '^-' }

    if ($positionalArgs.Count -lt 2) {
        Write-Error "Syntaxe error. Usage : kdown [options] <TargetHost:SourceDistante> <DestinationLocale>"
        return
    }

    $remoteSource     = $positionalArgs[0]
    $localDestination = $positionalArgs[1]

    # complete the remote source path with user name
    if ($remoteSource -notlike "*@*") {
        $remoteSource = "${env:USERNAME}@${remoteSource}"
    }

    # check if target folder exists in the local file system
    $parentLocal = Split-Path -Path $localDestination -Parent
    if ($parentLocal -and -not (Test-Path -Path $parentLocal)) {
        Write-Error "Error : The provided directory path does not exist on the local file system : $parentLocal"
        return
    }

    # build the scp command args table
    $scpArgs = @("-o", "GSSAPIAuthentication=yes")
    if ($options) { $scpArgs += $options }
    $scpArgs += $remoteSource
    $scpArgs += $localDestination

    Write-Host "Downloading data from remote server ${remoteSource} to local file system ..." -ForegroundColor Cyan
    scp @scpArgs
}
# --- end of configuration CASD ---
'@

# inject the casd config, add the config at the end of the profile file if the file exists
if (Test-Path $PROFILE) {
    $currentContent = Get-Content $PROFILE -Raw

    # Alerte d'administration si l'ancienne fonction kscp est détectée
    if ($currentContent -like "*kscpGSSAPI*") {
        Write-Warning "Warning : The old fonction 'kscp' has been detected in the user profile file. Do not use this function anymore, it's been deprecated."
    }
    # to avoid duplication, check if profile contains the casd config or not
    if ($currentContent -notlike "*kupGSSAPI*") {
        # backup the old version of the profile file
        Copy-Item -Path $PROFILE -Destination "$PROFILE-$timestamp.bak" -Force
        Add-Content -Path $PROFILE -Value "`n$aliasBlock" -Encoding utf8
        Write-Host "The fonction kup and kdown have been added to your profile" -ForegroundColor Green
    } else {
        Write-Host "The fonction kup and kdown already in your profil. skipping" -ForegroundColor Yellow
    }
} else {
    # if the profile file does not exist, we create one
    $aliasBlock | Set-Content $PROFILE -Encoding utf8
    Write-Host "The fonction kup and kdown have been added to your profile" -ForegroundColor Green
}

# Rechargement discret du profil pour la session en cours
. $PROFILE

