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

Cela crée un projet Symfony 7.4 vierge avec l'endpoint Flex SHbyJM déjà configuré dans `composer.json`.

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
