<#
.SYNOPSIS
    Restructure un projet Symfony fraichement cree en structure dual :
    un dossier code Symfony + un dossier webroot.

.DESCRIPTION
    Apres un `composer create-project`, ce script deplace le code Symfony
    dans un sous-dossier et isole le webroot (public/) dans un dossier
    separe a la racine. Les chemins critiques (index.php, composer.json)
    sont ajustes automatiquement.

.PARAMETER SymfonyDir
    Nom du dossier qui contiendra le code Symfony. Defaut : symfony

.PARAMETER PublicDir
    Nom du dossier qui contiendra le webroot. Defaut : public_html

.EXAMPLE
    .\bootstrap.ps1
    .\bootstrap.ps1 -SymfonyDir "symfony" -PublicDir "public_html"
    .\bootstrap.ps1 -SymfonyDir "symfony" -PublicDir "monsousdomaine.example.com.public_html"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SymfonyDir = "symfony",

    [Parameter()]
    [string]$PublicDir = "public_html"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Validation ---

# Verifier qu'on est a la racine d'un projet Symfony
$requiredItems = @("composer.json", "src", "public", "bin")
foreach ($item in $requiredItems) {
    if (-not (Test-Path $item)) {
        Write-Error "Fichier ou dossier '$item' introuvable. Ce script doit etre execute a la racine d'un projet Symfony fraichement cree."
        exit 1
    }
}

# Verifier que les dossiers cibles n'existent pas deja
if (Test-Path $SymfonyDir) {
    Write-Error "Le dossier '$SymfonyDir' existe deja. Le bootstrap a peut-etre deja ete execute."
    exit 1
}
if (Test-Path $PublicDir) {
    Write-Error "Le dossier '$PublicDir' existe deja. Le bootstrap a peut-etre deja ete execute."
    exit 1
}

Write-Host ""
Write-Host "=== Bootstrap SHbyJM ===" -ForegroundColor Cyan
Write-Host "Structure cible :"
Write-Host "  Code Symfony : $SymfonyDir/"
Write-Host "  Webroot      : $PublicDir/"
Write-Host ""

# --- Etape 1 : Creer le dossier Symfony ---

Write-Host "[1/5] Creation du dossier '$SymfonyDir/'..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $SymfonyDir | Out-Null

# --- Etape 2 : Deplacer tout sauf les exclusions ---

Write-Host "[2/5] Deplacement du code Symfony dans '$SymfonyDir/'..." -ForegroundColor Yellow

# Elements a exclure du deplacement
$scriptName = Split-Path -Leaf $PSCommandPath
$excludeNames = @($SymfonyDir, "public", ".git", "claude.md", "CLAUDE.md", $scriptName)

# Deplacer les fichiers et dossiers (y compris les fichiers caches)
$items = Get-ChildItem -Path "." -Force | Where-Object {
    $excludeNames -notcontains $_.Name
}

foreach ($item in $items) {
    Move-Item -Path $item.FullName -Destination (Join-Path $SymfonyDir $item.Name) -Force
}

# --- Etape 3 : Renommer public/ en {PublicDir}/ ---

Write-Host "[3/5] Renommage de 'public/' en '$PublicDir/'..." -ForegroundColor Yellow
Rename-Item -Path "public" -NewName $PublicDir

# --- Etape 4 : Ajuster les chemins critiques ---

Write-Host "[4/5] Ajustement des chemins critiques..." -ForegroundColor Yellow

# 4a. composer.json : ajouter extra.public-dir
$composerPath = Join-Path $SymfonyDir "composer.json"
$composerContent = Get-Content -Path $composerPath -Raw

# Ajouter ou mettre a jour public-dir dans extra.symfony
$publicDirRelative = "../$PublicDir"
if ($composerContent -match '"public-dir"') {
    # Remplacer la valeur existante
    $composerContent = $composerContent -replace '"public-dir"\s*:\s*"[^"]*"', "`"public-dir`": `"$publicDirRelative`""
} else {
    # Ajouter apres "require": "7.4.*"
    $composerContent = $composerContent -replace '("require"\s*:\s*"7\.4\.\*")', "`$1,`n            `"public-dir`": `"$publicDirRelative`""
}

Set-Content -Path $composerPath -Value $composerContent -NoNewline

# 4b. auto-scripts : retirer assets:install (inutile avec Webpack Encore, problematique avec la structure dual)
$composerContent = Get-Content -Path $composerPath -Raw
$composerContent = $composerContent -replace ',?\s*"assets:install %PUBLIC_DIR%"\s*:\s*"symfony-cmd"\s*,?', ''
# Nettoyer une eventuelle virgule pendante avant le } fermant de auto-scripts
$composerContent = $composerContent -replace ',(\s*})', '$1'
Set-Content -Path $composerPath -Value $composerContent -NoNewline

# 4c. index.php : ajuster le chemin vers autoload_runtime.php
$indexPath = Join-Path $PublicDir "index.php"
if (Test-Path $indexPath) {
    $indexContent = Get-Content -Path $indexPath -Raw
    # Remplacer le require de autoload_runtime.php
    $indexContent = $indexContent -replace "require_once\s+dirname\(__DIR__\)\s*\.\s*'/vendor/autoload_runtime\.php'", "require_once dirname(__DIR__) . '/$SymfonyDir/vendor/autoload_runtime.php'"
    Set-Content -Path $indexPath -Value $indexContent -NoNewline
}

# --- Etape 5 : Message final ---

Write-Host ""
Write-Host "[5/5] Bootstrap termine !" -ForegroundColor Green
Write-Host ""
Write-Host "Structure finale :" -ForegroundColor Cyan
Write-Host "  ./"
Write-Host "  +-- $SymfonyDir/          Code Symfony (src/, config/, vendor/, bin/...)"
Write-Host "  +-- $PublicDir/        Webroot (index.php, assets...)"
Write-Host "  +-- claude.md             Conventions projet"
Write-Host "  +-- .git/                 Historique Git"
Write-Host ""
Write-Host "Prochaines etapes :" -ForegroundColor Cyan
Write-Host "  cd $SymfonyDir"
Write-Host "  composer install"
Write-Host "  composer require shbyjm/admin-shell    # si besoin du back-office"
Write-Host ""
Write-Host "Hebergement PlanetHoster :" -ForegroundColor Cyan
Write-Host "  Configurer le webroot du site pour pointer vers '$PublicDir/'"
Write-Host ""

# --- Auto-suppression du script ---

$response = Read-Host "Supprimer le script bootstrap.ps1 ? (o/N)"
if ($response -eq "o" -or $response -eq "O") {
    Remove-Item -Path $PSCommandPath -Force
    Write-Host "bootstrap.ps1 supprime." -ForegroundColor DarkGray
} else {
    Write-Host "bootstrap.ps1 conserve." -ForegroundColor DarkGray
}
