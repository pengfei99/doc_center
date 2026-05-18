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

if (Test-Path $aliasPath){
    Rename-Item -Path $aliasPath -NewName "alias-$timestamp" -Force
}

$configalias = @'
Set-Alias kscp kscpGSSAPI
function kscpGSSAPI {
    $options = @()
	$source = $null
	$hostname = $null
	foreach ($arg in $args) {
		if ($arg -match '^-') {
			$options += $arg
		} elseif (-not $source) {
			$source = $arg
		} elseif (-not $hostname) {
			$hostname = $arg
		}
	}
	scp -o GSSAPIAuthentication=yes $options $source ${env:USERNAME}@$($hostname):/home/${env:USERNAME}/
}
'@

$configalias | Set-Content $aliasPath -Encoding utf8
. $PROFILE

