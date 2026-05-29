<#
    name: gen_projet_dir_group_mapping.ps1
    description: Génération d'un fichier CSV avec les combinaisons nom du Unité_Projet et groupes G_D1_...
    example:
        dir structure attendue :
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

       output csv attendue:
       BES_ENQUETE-URGENCE,G_D1_BES_ENQUETE-URGENCE
       BES_RPU,G_D1_BES_RPU
       BCL_EEC,G_D1_BCL_EEC
       BCL_OLINPE-PRODUCTION,G_D1_BCL_OLINPE-PRODUCTION
       BCL_PRODUCTION-CSNS,G_D1_BCL_PRODUCTION-CSNS

#>

# --- Configuration ---
$rootPath = "C:\Users\pliu\Documents\git\admin_sys"
# Liste des dossiers à ignorer (Sensible à la casse : Non)
$ignoreProjects = @("COMMUN", "Shared", "Common", "Temp", "Archive")
# default chemin de sortie (relatif ou absolu)
$outputFile = ".\unites_projets_groupes.csv"

# Vérification que le dossier racine existe
if (-not (Test-Path $rootPath -PathType Container))
{
    Write-Error "Le chemin racine n'existe pas ou n'est pas un dossier : $rootPath"
    Exit
}

# --- Collecte des données ---
Write-Host "Analyse de l'arborescence en cours..." -ForegroundColor Cyan

# Récupération des dossiers de niveau 1 (Unités) et niveau 2 (Projets) en une seule passe efficace
$items = Get-ChildItem -Path $rootPath -Directory -Depth 1 -ErrorAction SilentlyContinue

# Filtrage pour ne garder que les projets (dossiers de niveau 2) qui ne sont pas à ignorer
$projectFolders = $items | Where-Object {
    $_.Parent.FullName -ne $rootPath -and
            $ignoreProjects -notcontains $_.Name
}

if (-not $projectFolders)
{
    Write-Warning "Aucun dossier projet valide n'a ete trouve."
    Exit
}

# --- Construction des objets ---
$results = foreach ($project in $projectFolders)
{
    $unitName = $project.Parent.Name.Trim()
    $projectName = $project.Name.Trim()
    $dirName = "${unitName}_${projectName}"

    # Création d'un objet structuré
    [PSCustomObject]@{
        NomDossier = $dirName
        GroupeAD = "G_D1_${dirName}"
    }
}

# Si aucun résultat → avertissement
if ($results.Count -eq 0)
{
    Write-Warning "Aucune combinaison Unite_Projet trouvee (peut-etre tous les dossiers sont exclus ?)"
}

# --- Export et Rendu ---
if ($results)
{
    # sort by the dir name,
    # covert obj to csv
    # exclusion of the first row(header)
    # remove all "
    # write to file
    $results | Sort-Object NomDossier |
            ConvertTo-Csv -NoTypeInformation |
            Select-Object -Skip 1 |
            ForEach-Object { $_ -replace '"', '' } |
            Out-File -FilePath $outputFile -Encoding UTF8 -Force

    Write-Host "`n[SUCCES] Fichier CSV genere avec succes : $outputFile" -ForegroundColor Green
    Write-Host "Nombre de lignes exportees : $( $results.Count )" -ForegroundColor Green
}