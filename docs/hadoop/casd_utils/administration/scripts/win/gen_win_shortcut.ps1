$sshDir = "$HOME\.ssh"
$configPath = "$sshDir\config"
$timestamp = Get-Date -Format "yyyy-MM-dd-HH-mm-ss"
if (-not (Test-Path $sshDir)) { mkdir $sshDir | Out-Null }

if (Test-Path $ConfigPath){
    Rename-Item -Path $configPath -NewName "config-$timestamp" -Force
}

# 2. Define the configuration text
$config = @"
Host *.casd.fr
    User                        $env:USERNAME
    GSSAPIAuthentication        yes
    GSSAPIDelegateCredentials   yes
    PreferredAuthentications    gssapi-with-mic
"@

# 3. Write the file (overwrites existing, no backup for maximum simplicity)
$config | Set-Content $configPath -Encoding utf8

# 4. Set strict permissions (Required for OpenSSH to function)
$acl = Get-Acl $configPath
$acl.SetAccessRuleProtection($true, $false) # Remove inherited permissions
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$env:USERDOMAIN\$env:USERNAME", "FullControl", "Allow")
$acl.AddAccessRule($rule)
Set-Acl $configPath $acl
Write-Host "SSH Config created and secured for $env:USERNAME" -ForegroundColor Green

$ProfileDir = "$HOME\Documents\WindowsPowerShell"
$aliasPath = "$ProfileDir\Microsoft.PowerShell_profile.ps1"

if (-not (Test-Path $ProfileDir)) { mkdir $ProfileDir | Out-Null }

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

