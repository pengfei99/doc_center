<#
    Génération d'un fichier CSV avec les combinaisons Unité_Projet et groupes G_D1_...
    
    Structure attendue :
    V:\
      BES\
        COMMUN
        ENQUETE-URGENCE
        RPU
      BCL\
        COMMUN
        EEC
        OLINPE-PRODUCTION
        PRODUCTION-CSNS
#>

# Configuration
$rootPath       = "V:\"
$ignoreProjects = @("COMMUN", "Shared", "Common", "Temp", "Archive")  # ← Ajoutez ici tous les dossiers à ignorer

$outputFile     = ".\unites_projets_groupes.csv"   # Chemin de sortie (relatif ou absolu)

# Vérification que le dossier racine existe
if (-not (Test-Path $rootPath)) {
    Write-Error "Le chemin racine n'existe pas : $rootPath"
    exit
}

# Récupération des unités (dossiers de premier niveau)
$units = Get-ChildItem -Path $rootPath -Directory -ErrorAction SilentlyContinue

if ($units.Count -eq 0) {
    Write-Warning "Aucun dossier unité trouvé dans $rootPath"
    exit
}

# Tableau pour stocker les lignes CSV
$results = [System.Collections.Generic.List[string]]::new()

foreach ($unit in $units) {
    $unitName = $unit.Name.Trim()

    # Récupération des projets (dossiers de second niveau), en excluant ceux de la liste ignoreProjects
    $projects = Get-ChildItem -Path $unit.FullName -Directory -ErrorAction SilentlyContinue |
        Where-Object { $ignoreProjects -notcontains $_.Name }

    foreach ($project in $projects) {
        $projectName = $project.Name.Trim()

        # Création des noms
        $dirName = "${unitName}_${projectName}"
        $groupe      = "G_D1_${dirName}"

        # Ajout au résultat
        $results.Add("$dirName,$groupe")
    }
}

# Si aucun résultat → avertissement
if ($results.Count -eq 0) {
    Write-Warning "Aucune combinaison Unité_Projet trouvée (peut-être tous les dossiers sont exclus ?)"
}

# Export CSV
$results | Sort-Object | Out-File -FilePath $outputFile -Encoding UTF8 -Force

Write-Host "Fichier généré : $outputFile"
Write-Host "Nombre de lignes : $($results.Count)"