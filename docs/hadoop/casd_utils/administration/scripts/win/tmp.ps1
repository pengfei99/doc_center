<#
    Description : Configuration OpenSSH (GSSAPI/Kerberos) et injection de la fonction kscp.
    Optimisé pour : Déploiement multi-utilisateur (RDS/Serveur de rebond).
    Sécurité : Respect de l'intégrité des profils utilisateurs.
#>

# --- 1. Initialisation et Variables Natives ---
$sshDir      = Join-Path $HOME ".ssh"
$configPath  = Join-Path $sshDir "config"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"

# Sécurité du chemin de profil : Utilisation de la variable système native
if (-not $PROFILE) {
    Write-Error "Le profil PowerShell n'est pas disponible dans cette session."
    Exit
}
$profileDir = Split-Path $PROFILE -Parent

# --- 2. Configuration OpenSSH ---
if (-not (Test-Path $sshDir)) {
    New-Item -Path $sshDir -ItemType Directory -Force | Out-Null
}

# Sauvegarde intelligente du fichier config SSH
if (Test-Path $configPath) {
    Rename-Item -Path $configPath -NewName "config-$timestamp.bak" -Force
}

$sshConfigText = @"
Host *.casd.fr
    User                        $env:USERNAME
    GSSAPIAuthentication        yes
    GSSAPIDelegateCredentials   yes
    PreferredAuthentications    gssapi-with-mic
"@

$sshConfigText | Set-Content $configPath -Encoding utf8

# Application stricte des permissions NTFS (Requis par OpenSSH)
$acl = Get-Acl $configPath
$acl.SetAccessRuleProtection($true, $false) # Suppression de l'héritage
$identity = "$env:USERDOMAIN\$env:USERNAME"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, "FullControl", "Allow")
$acl.AddAccessRule($accessRule)
Set-Acl $configPath $acl

Write-Host "✓ Configuration SSH sécurisée pour $env:USERNAME" -ForegroundColor Green


# --- 3. Configuration du Profil PowerShell (Non-destructive) ---
if (-not (Test-Path $profileDir)) {
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
}

# Bloc de code à injecter (Utilisation de scp natif amélioré)
$aliasBlock = @'

# --- Début de la configuration CASD ---
Set-Alias kscp kscpGSSAPI
function kscpGSSAPI {
    <#
        .SYNOPSIS
            Copie de fichier simplifiée via SCP avec authentification GSSAPI.
        .EXAMPLE
            kscp document.txt machine.casd.fr
    #>
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Source,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$TargetHost
    )

    # Nettoyage au cas où l'utilisateur a tapé le ":" par habitude
    $TargetHost = $TargetHost -replace ':$', ''

    Write-Host "Transfert sécurisé GSSAPI vers ${TargetHost}..." -ForegroundColor Cyan
    scp -o GSSAPIAuthentication=yes "$Source" "${env:USERNAME}@${TargetHost}:/home/${env:USERNAME}/"
}
# --- Fin de la configuration CASD ---
'@

# INJECTION NON-DESTRUCTIVE : On ajoute à la fin du fichier s'il existe déjà
if (Test-Path $PROFILE) {
    $currentContent = Get-Content $PROFILE -Raw
    if ($currentContent -notlike "*kscpGSSAPI*") {
        # Sauvegarde de sécurité du profil avant modification
        Copy-Item -Path $PROFILE -Destination "$PROFILE-$timestamp.bak" -Force
        Add-Content -Path $PROFILE -Value "`n$aliasBlock" -Encoding utf8
        Write-Host "✓ Fonction kscp ajoutée à votre profil existant." -ForegroundColor Green
    } else {
        Write-Host "i La fonction kscp est déjà présente dans votre profil." -ForegroundColor Yellow
    }
} else {
    # Si le profil n'existait pas, on le crée proprement
    $aliasBlock | Set-Content $PROFILE -Encoding utf8
    Write-Host "✓ Profil PowerShell créé avec la fonction kscp." -ForegroundColor Green
}

# Rechargement discret du profil pour la session en cours
. $PROFILE