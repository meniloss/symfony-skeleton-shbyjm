# Symfony Skeleton SHbyJM

Base Symfony minimaliste avec l'endpoint Flex SHbyJM pré-configuré. Aucun module SHbyJM n'est inclus par défaut — chaque package s'ajoute à la demande via `composer require`.

## Prérequis

### PHP

- PHP >= 8.2 avec les extensions `ctype` et `iconv`
- Composer 2.x

### Authentification GitHub (repos privés)

Les packages SHbyJM (`shbyjm/admin-shell`, `shbyjm/lead-forwarding`) sont hébergés dans des repos privés `meniloss/*`. Composer doit disposer d'un token GitHub ayant accès à ces repos.

Configurer le fichier `auth.json` de Composer (global) :

```bash
composer config --global github-oauth.github.com ghp_VOTRE_TOKEN_GITHUB
```

Le token doit avoir le scope `repo` pour accéder aux dépôts privés de l'organisation `meniloss`.

## Installation

```bash
composer create-project meniloss/symfony-skeleton-shbyjm mon-nouveau-site
```

Cela crée un projet Symfony 7.4 vierge avec :
- L'endpoint Flex SHbyJM déjà configuré
- Les repositories VCS GitHub déclarés pour les packages SHbyJM privés
- La config Messenger SHbyJM (deux bus, middleware doctrine_transaction, transport async Doctrine)

## Structure dual avec bootstrap.ps1

Après la création du projet, le script `bootstrap.ps1` réorganise la structure en séparant le code Symfony du webroot. C'est la structure attendue pour un déploiement sur PlanetHoster (ou tout hébergement où le webroot est un dossier distinct).

### Utilisation typique

```powershell
composer create-project meniloss/symfony-skeleton-shbyjm mon-nouveau-site
cd mon-nouveau-site
.\bootstrap.ps1
cd symfony
composer require shbyjm/admin-shell
```

### Paramètres

| Paramètre      | Défaut        | Description                          |
|-----------------|---------------|--------------------------------------|
| `-SymfonyDir`   | `symfony`     | Nom du dossier contenant le code     |
| `-PublicDir`    | `public_html` | Nom du dossier webroot               |

Les noms peuvent contenir des points et des tirets (utile pour les sous-domaines PlanetHoster) :

```powershell
.\bootstrap.ps1 -SymfonyDir "symfony" -PublicDir "blog.example.com.public_html"
```

### Structure résultante

```
mon-nouveau-site/
├── symfony/              # Code Symfony (src/, config/, vendor/, bin/...)
├── public_html/          # Webroot (index.php, assets...)
├── claude.md             # Conventions projet
└── .git/
```

Le script ajuste automatiquement :
- `composer.json` → `extra.symfony.public-dir` pointe vers le webroot
- `composer.json` → retrait de `assets:install %PUBLIC_DIR%` des auto-scripts (inutile avec Webpack Encore, incompatible avec la structure dual)
- `index.php` → le `require` de l'autoloader pointe vers `symfony/vendor/`

> **Note** : `assets:install` est retiré par convention SHbyJM. La stack utilise Webpack Encore pour la gestion des assets. Si un cas spécifique le nécessite, la commande reste disponible manuellement : `php bin/console assets:install`.

## Repositories VCS

Le `composer.json` déclare les repositories VCS GitHub des packages SHbyJM :

```json
"repositories": [
    { "type": "vcs", "url": "https://github.com/meniloss/admin-shell" },
    { "type": "vcs", "url": "https://github.com/meniloss/lead-forwarding" }
]
```

Ces déclarations indiquent à Composer où trouver les packages privés. Aucun package n'est installé automatiquement — ils restent à ajouter à la demande via `composer require`.

## Config Messenger (livrée d'office)

Le skeleton inclut `config/packages/messenger.yaml` avec la convention Messenger partagée par tous les sites SHbyJM :

- **`command.bus`** (synchrone) — middleware `doctrine_transaction`, bus par défaut
- **`async.bus`** — taches lourdes (emails, notifications differees)
- **Transport `async`** — Doctrine, retry x3
- **Transport `failed`** — dead-letter queue Doctrine

Cette config est une convention structurante documentee dans le `claude.md`. Les packages SHbyJM (`admin-shell`, `lead-forwarding`) en dependent. Elle est livree dans le skeleton plutot que via une recipe Flex car Flex refuse d'ecraser un fichier existant en mode non-interactif — la recipe officielle `symfony/messenger` pose un `messenger.yaml` par defaut avant que la recipe SHbyJM ne puisse agir.

La variable `MESSENGER_TRANSPORT_DSN` est definie dans le `.env` du skeleton.

## Ajout des modules SHbyJM

Les recipes SHbyJM s'appliquent automatiquement grâce à l'endpoint Flex configuré dans ce skeleton. Il suffit de `require` les packages souhaités :

```bash
# Back-office
composer require shbyjm/admin-shell

# Transfert de leads
composer require shbyjm/lead-forwarding
```

Chaque `composer require` déclenche la recipe associée, qui met en place la configuration, les routes, les templates, etc.

## Ajout de packages Symfony standards

Ce skeleton est volontairement minimal. Les packages courants (Doctrine, Twig, Mailer, Security, etc.) s'ajoutent de la même manière :

```bash
composer require doctrine/orm
composer require twig
composer require symfony/mailer
```

## Endpoint Flex

Ce skeleton configure deux endpoints Flex (dans `composer.json > extra.symfony.endpoint`) :

1. **`https://api.github.com/repos/meniloss/recipes/contents/index.json`** — recipes SHbyJM (admin-shell, lead-forwarding, etc.)
2. **`flex://defaults`** — recipes officielles Symfony

L'ordre est important : les recipes SHbyJM sont consultées en priorité.
