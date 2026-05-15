# Conventions Symfony – Référence projet

## Stack technique de référence

| Composant  | Technologie                                        |
|------------|----------------------------------------------------|
| Framework  | Symfony 7.x                                        |
| PHP        | 8.2+                                               |
| ORM        | Doctrine ORM 3.x (mappings via attributs PHP)      |
| Templates  | Twig                                               |
| Assets     | Webpack Encore                                     |
| Formulaires| Symfony Forms + Data Objects dédiés                |
| Emails     | Symfony Mailer + templates Twig                    |
| Queue      | Symfony Messenger (transport Doctrine, asynchrone) |
| JS         | Stimulus + Turbo (UX Symfony)                      |
| Base de données | MySQL 8+ ou MariaDB 10.6+ (JSON, UUID, CTE)   |

> La stack réelle du projet courant peut déroger à ce tableau — voir la section
> "Contexte projet" en bas de ce fichier.

---

## Architecture DDD – Modules métier

### Principe fondamental : découper par domaine métier, jamais par surface UI

Un module regroupe tout le code qui appartient à un **même domaine métier**. Le critère
de découpage est la cohérence métier, pas la surface d'affichage.

**Règle de décision :**
> "Est-ce que ces concepts partagent les mêmes règles métier, les mêmes agrégats,
> les mêmes invariants ?" → Oui : même module. Non : modules séparés.

Un module peut exposer **plusieurs surfaces** (site public, admin, API, console) —
ce sont des portes d'entrée différentes vers le même domaine. Les surfaces vivent
dans `Infrastructure/Http/Controller/` du module, organisées en sous-dossiers si
nécessaire (`Controller/Public/`, `Controller/Admin/`).

**Anti-pattern — ne jamais faire :**
- Créer un module `Frontend` et un module `Admin` qui manipulent les mêmes agrégats
  → c'est un découpage par surface, pas par domaine. Le `Lead` a les mêmes règles
  qu'on le consulte depuis le site public ou depuis l'admin.
- Créer un module fourre-tout (`Frontend`, `App`, `Core`) qui contient tous les
  domaines du projet → c'est un retour au monolithe classique Symfony.

**Exemples de bons découpages :**

| Module           | Responsabilité                                        |
|------------------|-------------------------------------------------------|
| `LeadManagement` | Leads, contacts, relances, notifications              |
| `Website`        | Pages publiques, tunnels de vente, contenus statiques |
| `Identity`       | Authentification, profil, invitation, rôles           |
| `Billing`        | Factures, paiements, abonnements                      |

| Anti-pattern                  | Pourquoi c'est faux                                    |
|-------------------------------|--------------------------------------------------------|
| `Frontend` + `Admin`         | Même domaine, deux surfaces → un seul module           |
| `Frontend` (contient tout)   | Plusieurs domaines mélangés → à découper en modules    |
| `Api` (contient tout)        | Surface ≠ domaine → les endpoints vont dans les modules|

Chaque module vit sous `src/{NomDuModule}/` et respecte impérativement la structure
suivante.

### Shared Kernel — règle de séparation stricte

Le Shared Kernel (`src/Shared/`) est autorisé, mais son périmètre est strictement limité
aux concepts **techniques génériques** qui n'appartiennent à aucun domaine métier.

```
src/Shared/
├── Domain/
│   └── ValueObject/   # Uniquement : EmailAddress, PhoneNumber, Money, Uuid…
└── Application/
    └── Port/
        └── Clock/     # ClockInterface (voir section "Gestion du temps")
```

**Ce qui peut aller dans `Shared/` :**
- Value Objects purement techniques dont la logique est universelle et stable
  (format d'email, devise, identifiant…)
- Ports techniques génériques (Clock, éventuellement RandomGenerator, etc.)

**Ce qui ne peut jamais aller dans `Shared/` :**
- Modèles de domaine, Enums métier, Domain Events, Services applicatifs
- Tout concept qui a une signification métier différente selon le module
  (un `Customer` dans `Sales` ≠ un `Customer` dans `Shipping` — deux classes distinctes)

**Règle de décision :**
> "Est-ce que ce concept peut avoir une signification ou des règles différentes
> selon le module ?" → Oui : chaque module a sa propre version. Non : `Shared/`.

`Shared/` ne dépend d'aucun module. Aucun module ne dépend d'un autre.

### Structure obligatoire d'un module

```
src/{Module}/
├── Application/
│   ├── Command/        # Commandes CQRS + handlers invokables
│   ├── DTO/            # DTOs de sortie (lecture)
│   ├── Port/           # Interfaces (voir section dédiée)
│   │   ├── Repository/ # Ports d'écriture (par agrégat)
│   │   ├── ReadModel/  # Ports de lecture (pour les Providers)
│   │   └── Notifier/   # Ports de notification
│   ├── Provider/       # Fournisseurs de données applicatifs (lecture)
│   └── Service/        # Services applicatifs (orchestration)
├── Domain/
│   ├── Enum/           # Enums métier
│   ├── Event/          # Domain Events immuables
│   ├── Model/          # Modèles de domaine / agrégats
│   └── ValueObject/    # Value Objects immuables
└── Infrastructure/
    ├── Console/        # Commandes Symfony (cron, CLI)
    ├── Http/
    │   ├── Controller/ # Contrôleurs (sous-dossiers par surface si besoin : Public/, Admin/)
    │   └── Form/
    │       ├── Data/   # Form Data Objects (hydratés par Symfony Forms)
    │       └── Type/   # Classes FormType
    ├── Notification/   # Implémentations des notifiers
    └── Persistence/
        └── Doctrine/
            ├── Entity/     # Entités Doctrine (si distinctes du domaine)
            ├── Repository/ # Implémentations des Ports Repository
            └── ReadModel/  # Implémentations des Ports ReadModel
```

### Checklist de création d'un nouveau module avec entités Doctrine

1. Ajouter le mapping du namespace dans `config/packages/doctrine.yaml`
   (sinon les entités sont inconnues du gestionnaire d'entités).
2. Enregistrer les services dans `config/services.yaml` (ou exclure le
   scan auto-discovery si namespace distinct, comme pour les packages externes).
3. Si le module introduit un nouveau bus ou transport Messenger, mettre
   à jour `config/packages/messenger.yaml`.
4. Si le module ajoute des routes, les déclarer dans `config/routes.yaml`.
5. Migration Doctrine pour les nouvelles tables.

### Communication entre modules

Les modules sont **strictement indépendants**. Ils ne s'importent jamais directement.

**Mécanismes autorisés :**
- **Domain Events** : un module publie un event, un autre y réagit via un Listener.
  C'est le mécanisme principal de coordination.
- **Shared Value Objects** : via `src/Shared/Domain/ValueObject/` pour les types
  techniques communs (EmailAddress, etc.)
- **ReadModel Ports inter-modules** : les classes d'infrastructure (authenticators,
  voters, listeners, console commands) peuvent consommer les ReadModel Ports
  d'autres modules — le couplage passe par une interface publiée
  (`Application/Port/ReadModel/`), jamais par une implémentation. Ce mécanisme
  est réservé à la **lecture seule** et ne doit jamais être utilisé depuis
  `Domain/` ou `Application/Service/`.

**Interdit :**
- Importer un modèle, un service ou un port d'écriture d'un autre module
- Appeler un repository d'écriture d'un autre module
- Partager des entités Doctrine entre modules

**Exception — packages Composer externes :**
Les packages Composer avec un namespace distinct de celui du site (ex :
`Shbyjm\LeadForwarding\` vs `App\`) exposent une API publique documentée.
Leur consommation directe par les modules internes est autorisée — c'est la
raison d'être d'un package. La règle « pas d'import direct » s'applique aux
modules internes du site entre eux, pas à un package externe dont le contrat
est explicitement publié.

### Flux de données (écriture)

```
Requête HTTP
  → Controller
    → Form/Data/ (hydraté par Symfony Forms)
      → Application/Command/ (créé par le controller)
        → command.bus → Application/Command/Handler (__invoke)
          → Domain/Model/ (création + validation + enregistre un Domain Event)
            → Handler appelle Application/Port/Repository/ → Infrastructure/Persistence/
              → Middleware Doctrine : commit de la transaction
                → Les Domain Events sont dispatchés APRÈS commit
                  → Listeners (Application/ ou Infrastructure/) réagissent
```

### Flux de données (lecture)

Il n'y a pas de Command ni de Domain Model impliqué en lecture. Le controller appelle
directement un **Provider** qui interroge un **ReadModel Port** et retourne un **DTO**.

```
Requête HTTP
  → Controller
    → Application/Provider/
      → Application/Port/ReadModel/ (interface)
        → Infrastructure/Persistence/Doctrine/ReadModel/ (implémentation)
          → Application/DTO/ (données mises en forme pour la vue)
            → Controller passe le DTO à Twig
```

**Règles :**
- Les DTOs de lecture (`Application/DTO/`) sont des objets simples en lecture seule
- Un Provider ne modifie jamais l'état — il ne lit que
- Le controller ne construit jamais de requête Doctrine directement
- Les DTOs ne contiennent pas de logique métier
- **Les Providers passent toujours par une interface `Application/Port/ReadModel/`** —
  jamais d'appel direct à Doctrine depuis un Provider. Cette contrainte garantit
  la testabilité et la cohérence inter-modules.

---

## Ports — gouvernance et nommage

Les Ports sont le contrat entre la couche Application et l'Infrastructure. Ils vivent
exclusivement sous `Application/Port/` et obéissent aux règles suivantes.

### Structure

```
Application/Port/
├── Repository/   # Ports d'écriture (un par agrégat)
├── ReadModel/    # Ports de lecture (pour les Providers)
└── Notifier/     # Ports de notification (mail, SMS, webhook…)
```

D'autres catégories peuvent s'ajouter selon les besoins (`Port/ExternalApi/`,
`Port/FileStorage/`…) — toujours comme sous-dossiers thématiques.

### Règles

- **Toujours une interface, jamais une classe abstraite.** Une Port décrit un
  contrat, pas une implémentation partielle.
- **Nommage sans suffixe `Interface`** : `LeadRepository`, pas `LeadRepositoryInterface`.
  L'emplacement (`Application/Port/`) suffit à exprimer qu'il s'agit d'une interface.
  L'implémentation porte un préfixe technique : `DoctrineLeadRepository`,
  `MailerLeadNotifier`.
- **Une Port par agrégat pour l'écriture.** Jamais de repository générique
  multi-agrégats.
- **Une Port par cas d'usage de lecture si nécessaire.** Si deux Providers ont
  des besoins radicalement différents, deux ReadModel Ports distincts. La
  duplication est préférable au couplage.
- **Une implémentation par Port, par défaut.** Si plusieurs implémentations
  coexistent (ex: mail en prod, log en dev), la sélection se fait via
  configuration Symfony (`services.yaml`), jamais via logique métier.

---

## Value Objects — règles complémentaires

En plus de la règle générale d'immutabilité, les Value Objects respectent les
règles suivantes.

### Égalité

Tout Value Object doit exposer une méthode `equals(self $other): bool` permettant
de comparer deux instances par **valeur** et non par référence. Ne jamais comparer
deux VOs avec `===` dans le code métier.

### Représentation

- `__toString(): string` si le VO a une représentation textuelle naturelle et
  non ambiguë (ex: `EmailAddress`, `PhoneNumber`). Dans ce cas, `__toString()`
  retourne la forme canonique.
- Si plusieurs représentations existent (ex: `Money` → montant + devise),
  exposer des accesseurs explicites (`amount()`, `currency()`) et ne pas
  implémenter `__toString()`.

### Composition

Un Value Object peut en contenir d'autres. Exemple : `Address` contient
`PostalCode`, `Country`. Dans ce cas, la validation du VO parent se limite à
la cohérence entre ses composants — chaque VO interne valide son propre format.

### Nullabilité

**Un Value Object n'est jamais nullable dans le domaine.** Si une valeur peut
être absente, le modèle domaine porte une propriété nullable (`?PhoneNumber`),
mais le Value Object lui-même refuse les valeurs vides dans son constructeur.

- ❌ `new PhoneNumber(null)` ou `new PhoneNumber('')` autorisés
- ✅ `?PhoneNumber` dans le modèle, avec `null` si absent, instance valide sinon

### Validation

Validation **dans le constructeur uniquement**. Si invalide, lever une exception
dédiée (`InvalidEmailException`, `InvalidPhoneNumberException`) héritant de
`\InvalidArgumentException`, placée dans `Domain/Exception/` du module (ou de
`Shared/` pour les VOs partagés).

---

## Identifiants d'agrégats

- **UUID v7** par défaut pour tous les identifiants d'agrégats.
  Triable chronologiquement, bonne répartition pour les indexes Doctrine,
  supporté nativement par `Symfony\Component\Uid\Uuid::v7()`.
- Stocker en `BINARY(16)` ou colonne native `uuid` selon la base de données,
  jamais en `VARCHAR(36)` (coût d'index, coût de stockage).
- Chaque agrégat expose son propre type d'identifiant (`LeadId`, `UserId`) —
  Value Object dédié qui encapsule l'UUID. Jamais de `string` ou `Uuid` nu
  dans les signatures du domaine.
- L'identifiant est **généré côté domaine** via `XxxRepository::nextIdentity()`,
  jamais par auto-increment Doctrine, jamais dans le contrôleur.

---

## Gestion du temps

Le domaine ne doit jamais instancier directement `\DateTimeImmutable`. Cette
règle garantit que les tests sont déterministes et que le temps peut être
gelé ou avancé dans les tests.

### Règles

- **Clock Port obligatoire** : `src/Shared/Application/Port/Clock/Clock.php`,
  interface retournant une `\DateTimeImmutable` via une méthode `now()`.
- **Implémentation en production** : `SystemClock` utilisant
  `Symfony\Component\Clock\ClockInterface` (fourni par le composant `symfony/clock`).
- **Implémentation en test** : `FrozenClock` configurable, utilisée dans les
  tests unitaires pour figer le temps.
- **Injection obligatoire** : tout Domain Service, Application Service ou
  Domain Event qui manipule le temps reçoit le Clock par injection.
  Jamais de `new \DateTimeImmutable('now')` dans `Domain/` ou `Application/`.

**Exception :** dans un Value Object, `\DateTimeImmutable` peut apparaître dans
le constructeur pour représenter une date donnée (ex: `new BirthDate($date)`)
— mais jamais pour récupérer "le temps présent".

---

## Domain Events — règle obligatoire

Un Domain Event est un objet PHP immuable décrivant quelque chose qui vient de se passer
dans le domaine. Il est enregistré par le modèle et dispatché par le handler **après
commit de la transaction**.

### Règles de base

- Tout changement d'état métier significatif → un Domain Event dans `Domain/Event/`
- Le Domain Model enregistre les événements via un pattern `recordEvent()`
  (méthode protégée ou helper via trait)
- Le Handler récupère les events du modèle via `pullEvents()` et les dispatche
- Les Listeners (`Application/` ou `Infrastructure/`) réagissent aux events
- **Un handler ne doit jamais appeler un notifier directement**

### Convention de nommage

Un Domain Event se nomme **au passé** — il décrit ce qui vient de se passer, pas ce
qu'on souhaite faire.

- ✅ `UserRegistered`, `LeadSubmitted`, `OrderShipped`
- ❌ `RegisterUser`, `SubmitLead`, `ShipOrder` (ce sont des commandes, pas des events)

### Identifiant d'événement (eventId)

Tout Domain Event porte un champ `public readonly string $eventId` — UUID v7 généré
au moment de l'enregistrement dans l'agrégat (`Uuid::v7()->toRfc4122()`). Ce champ est
**non-nullable** et permet la déduplication côté consommateur (un même event dispatché
à plusieurs targets partage le même `eventId`).

### Cycle de vie et transactionnalité

- **Dispatch après commit** : les Domain Events sont dispatchés une fois la
  transaction Doctrine committée. Un listener qui échoue ne doit jamais
  invalider l'opération principale déjà enregistrée.
- Implémentation recommandée : un middleware Messenger sur le `command.bus`
  flushe la transaction avant de relayer les events collectés au dispatcher.
  La configuration précise est laissée au **contexte projet**.
- **Listeners idempotents** : un listener peut être rejoué (retry Messenger,
  panne partielle). Il doit produire le même effet quel que soit le nombre
  d'exécutions.
- **Échec de listener** : un listener qui lève une exception est mis en
  dead-letter queue (configuration Messenger projet). Il ne doit jamais
  remonter l'exception jusqu'au handler d'origine.

### Versionnement

- Un Domain Event publié est un **contrat public** entre modules. Modifier
  sa structure peut casser les listeners d'autres modules.
- **Règle d'évolution** : ne jamais supprimer ni renommer une propriété
  existante. Pour un nouveau champ, l'ajouter comme propriété optionnelle
  (valeur par défaut ou nullable). Pour un changement majeur, créer un
  nouvel event (`LeadSubmitted` → `LeadSubmittedV2`) et faire migrer les
  listeners progressivement.

---

## Transactions et unité de travail

La gestion des transactions est **explicite et centralisée** sur le `command.bus`.

### Règles

- **Une Command métier = une transaction.** Le middleware Doctrine du
  `command.bus` ouvre une transaction au début du handler, commit à la fin
  si le handler retourne normalement, rollback si une exception est levée.
- **Interdit d'ouvrir une transaction manuellement** dans un handler, un
  repository ou un contrôleur. Le middleware est le seul responsable.
- **Interdit d'appeler `flush()` en dehors du middleware.** Les repositories
  peuvent appeler `persist()` et `remove()` ; le flush global est géré par
  le middleware à la fin de la transaction.
- **Pas de transactions imbriquées.** Un handler ne dispatche jamais une
  autre Command synchrone. Les coordinations inter-agrégats passent par
  Domain Events + listeners asynchrones.
- **Exception** : les Domain Events sont dispatchés **après commit**
  (voir section Domain Events). Les effets secondaires (emails, webhooks,
  projections) se produisent donc hors transaction.

---

## Agrégats — règles

Un agrégat est un groupe d'objets traité comme une unité. Sa racine (Aggregate Root) est
le seul point d'entrée pour modifier l'état du groupe.

**Règles :**
- Chaque agrégat a une **racine unique** — on ne modifie jamais un objet interne
  directement, toujours via la racine
- **Une transaction = un agrégat** — un handler ne doit jamais modifier deux agrégats
  distincts dans la même opération. Si c'est nécessaire, c'est le signal qu'un Domain
  Event doit coordonner la chose via deux handlers séparés
- Les identifiants d'agrégats sont des **UUID v7** générés côté domaine via
  `XxxRepository::nextIdentity()` (voir section Identifiants)
- Un agrégat ne référence jamais un autre agrégat directement — uniquement par son
  identifiant (Value Object typé : `UserId`, `OrderId`…)

**Règle de décision — agrégat vs entité simple :**
> "Est-ce que cet objet a un cycle de vie propre et des invariants à protéger ?"
> Oui → c'est un agrégat. Non → c'est une entité ou un Value Object à l'intérieur
> d'un agrégat existant.

---

## Domain Service vs Application Service

| | Domain Service | Application Service |
|---|---|---|
| **Où** | `Domain/Service/` (si nécessaire) | `Application/Service/` |
| **Rôle** | Logique métier qui ne peut pas tenir dans un seul agrégat | Orchestration (appelle le domaine, coordonne infra) |
| **Connaît Symfony ?** | Non | Non |
| **Connaît Doctrine ?** | Non | Non (passe par les interfaces Port/) |

**Règle de décision :**
1. La logique peut tenir dans l'agrégat → elle va dans le modèle (`Domain/Model/`)
2. La logique implique plusieurs agrégats ou concepts domaine → `Domain/Service/`
3. La logique est de l'orchestration (appels repo, dispatch events) → `Application/Service/` ou handler

En pratique, les `Domain/Service/` sont rares. Si on en crée un souvent, c'est souvent
le signal d'un agrégat mal modélisé.

---

## Gestion des exceptions

| Couche | Type d'exception | Exemple |
|--------|-----------------|---------|
| `Domain/` | `\InvalidArgumentException` ou exception custom dans `Domain/Exception/` | `InvalidEmailException` |
| `Application/` | Exception custom dans `Application/Exception/` | `DuplicateSubmissionException` |
| `Infrastructure/` | Exceptions du framework, capturées et retransformées | `\Doctrine\ORM\...` |

**Règles :**
- Le domaine ne connaît pas les codes HTTP — il ne lève jamais de `HttpException`
- Les exceptions domaine remontent jusqu'au contrôleur, qui les traduit en réponse HTTP
  (ou via un `ExceptionListener` si le mapping est systématique)
- Ne jamais laisser une exception Doctrine remonter jusqu'à la vue — toujours la capturer
  dans l'infrastructure et la retransformer

---

## Règle Form/Data vs Application/Command

| Couche                    | Rôle                                                       | Dépend de Symfony ?  |
|---------------------------|------------------------------------------------------------|----------------------|
| `Form/Data/`              | Recevoir les données HTTP brutes (champs du form, captcha) | Oui (Infrastructure) |
| `Application/Command/`    | Représenter une intention métier, passée au handler        | Non (pur PHP)        |

Le controller mappe `FormData → Command`. Les handlers ne connaissent jamais les FormData.

---

## Conventions de code

Ces règles s'appliquent sans exception dans tout le code du projet.

- **PHP 8.2+** avec `declare(strict_types=1)` en tête de chaque fichier PHP
- **Classes `final`** par défaut — héritage autorisé seulement si explicitement justifié
- **Value Objects immuables** : validation dans le constructeur, `InvalidArgumentException` si invalide, `equals()` obligatoire (voir section VO)
- **Handlers invokables** : `public function __invoke(XxxCommand $command): array` —
  retournent obligatoirement un tuple `[mixed $result, object[] $events]` où `$result`
  est la valeur métier (identifiant créé, clé en clair…) ou `null`, et `$events` est
  le tableau issu de `$aggregate->pullEvents()`. Le middleware
  `DispatchDomainEventsMiddleware` dispatche automatiquement les events après commit.
- **Interfaces dans `Application/Port/`**, implémentations dans `Infrastructure/`
- **Pas de logique métier dans les contrôleurs** : un contrôleur crée la commande et dispatche, rien de plus
- **Pas de constantes de mapping dans les contrôleurs** : mappings, labels, slugs → `Domain/Enum/`
- **Entités Doctrine distinctes des modèles de domaine**
- **URLs en kebab-case** (`/mon-espace`, `/nos-solutions`)
- **Noms de routes en snake_case** (`context_action`, `admin_dashboard`)
- **Pas d'entité Doctrine dans le domaine** — `Domain/` ne connaît pas Doctrine
- **Pas d'import Symfony dans `Domain/`** — le domaine est du PHP pur sans framework
- **Pas d'instanciation directe de `\DateTimeImmutable` dans le domaine** — passer par le Clock Port
- **`flush()` interdit dans les contrôleurs et les handlers** — géré par le middleware de transaction
- **Jamais d'entité Doctrine directement dans un formulaire Symfony** — toujours un Form Data Object

### Ajouter un bundle ou une dépendance Composer

Toujours demander validation avant d'installer quoi que ce soit avec `composer require`.

---

## Symfony Messenger — deux bus obligatoires

Le projet utilise deux bus Messenger aux rôles strictement séparés :

| Bus | Transport | Rôle |
|-----|-----------|------|
| `command.bus` | Synchrone | Commands métier — traitées immédiatement dans la requête |
| `async.bus` | Doctrine (asynchrone) | Tâches lourdes — emails, jobs, notifications différées |

**Règles :**
- Les Commands métier passent par `command.bus` — le handler est appelé immédiatement,
  de façon synchrone, testable et traçable
- Le `command.bus` utilise un **middleware de transaction Doctrine** (voir section
  Transactions) qui gère ouverture / commit / rollback automatiquement
- Les tâches lourdes (emails, traitements différés) passent par `async.bus` — jamais
  dans le cycle de la requête HTTP
- **Une Command métier ne doit jamais être dispatchée sur `async.bus`** — on perd la
  gestion des erreurs synchrones et la testabilité
- La configuration précise des transports, dead-letter queue et retry appartient
  au **contexte projet**

**Déclencheurs possibles d'un handler :**
- Requête HTTP (cas standard)
- Tâche cron ou scheduler (déclenche une Command ou un Service applicatif)
- Message `async.bus` (traitement asynchrone)

Chaque déclencheur non-HTTP mérite d'être documenté dans le contexte projet avec son
propre flux.

**Règle obligatoire — middleware `doctrine_transaction` sur tout bus qui écrit :**
Tout bus Messenger dont les handlers peuvent écrire en base (`command.bus`,
`async.bus`, ou tout transport custom) doit avoir le middleware
`doctrine_transaction` configuré explicitement. Sans lui, les flushes
ne sont jamais committés et les écritures sont **perdues silencieusement**
(pas d'erreur visible, mais aucune persistance). Le middleware doit être
placé avant les middlewares applicatifs (comme `DispatchDomainEventsMiddleware`).

---

## Sécurité

### Voters

Toute décision d'accès métier passe par un **Voter Symfony** — jamais par une vérification
de rôle directe dans un contrôleur ou dans le domaine.

```
Infrastructure/
└── Security/
    └── Voter/   # Voters Symfony
```

**Règles :**
- Les Voters vivent dans `Infrastructure/Security/Voter/`
- Un Voter répond à une action métier explicite (`VIEW_MISSION`, `CANCEL_ORDER`…)
  pas à un rôle technique (`ROLE_ADMIN`)
- Le domaine ne connaît pas les rôles ni les Voters — zéro import Symfony Security
  dans `Domain/`
- Les contrôleurs utilisent `$this->denyAccessUnlessGranted('ACTION', $subject)`
  et ne contiennent aucune logique d'autorisation

**Règle de décision :**
> "Est-ce que cette restriction dépend d'une règle métier (propriétaire, statut,
> contexte) ?" → Voter. "Est-ce une restriction purement technique (accès à une
> section entière) ?" → `access_control` dans `security.yaml`.

### Rôles

- Les rôles sont définis dans `security.yaml` et documentés dans le contexte projet
- La hiérarchie de rôles (`ROLE_ADMIN` hérite de `ROLE_USER`…) est définie une seule
  fois dans `security.yaml`
- Jamais de `ROLE_*` en dur dans le code — toujours une constante ou un Enum dans
  `Infrastructure/Security/`

---

## Internationalisation (i18n)

Même si le projet est monolangue, l'architecture doit être préparée dès maintenant :

- Tous les textes dans les templates Twig utilisent le filtre `|trans`
- Les fichiers de traduction vont dans `translations/`
- Locale par défaut : `fr` sauf indication contraire
- Jamais de texte en dur dans les templates

---

## Contrat des repositories

Tout repository d'écriture expose une interface dans `Application/Port/Repository/`.

### Convention de nommage et de méthodes

- `save(Aggregate $aggregate): void` — unique méthode d'écriture, pour la création
  et la modification (Doctrine gère l'insert vs update via `persist()`, le flush
  est géré par le middleware de transaction)
- `nextIdentity(): AggregateId` — génère un UUID v7 côté domaine avant la persistance
- `findById(AggregateId $id): ?Aggregate` — récupère par identifiant
- Toute autre méthode de recherche doit être **nommée explicitement** selon le besoin
  métier (`findByEmail`, `findPendingOrders`…) — pas de `findBy(array $criteria)` générique

### Séparation lecture / écriture

- **Écriture** : `Application/Port/Repository/` — strictement limité à ce que le
  domaine a besoin pour persister et récupérer ses agrégats
- **Lecture** : `Application/Port/ReadModel/` — toutes les lectures complexes
  (listes paginées, filtres, rapports, jointures) passent par là. Interrogé
  exclusivement par les Providers, jamais par les handlers.

Cette séparation stricte évite qu'un handler écrive du read model ou qu'un
Provider modifie l'état d'un agrégat.

Les méthodes spécifiques à un contexte (pagination, filtres métier) se définissent
dans le contexte projet.

---

## Stratégie de tests

**Priorité 1 — Tests unitaires** (aucune base de données, aucun framework) :
- Value Objects (`Domain/ValueObject/`) — tester toutes les validations, l'égalité, et les cas limites
- Modèles de domaine (`Domain/Model/`) — tester les invariants, les états, les events enregistrés
- Domain Services (`Domain/Service/`) — avec des doubles de test pour les dépendances

**Priorité 2 — Tests unitaires avec doubles** :
- Handlers (`Application/Command/`) — doubler les repositories et notifiers via les interfaces `Port/`, utiliser un `FrozenClock`
- Services applicatifs (`Application/Service/`) — idem

**Priorité 3 — Tests d'intégration** :
- Repositories Doctrine — avec une vraie base de données (MySQL, fidèle à la prod)
- ReadModels Doctrine — idem
- Pas de SQLite en test — les dialectes diffèrent et masquent des bugs réels

**Pas de tests fonctionnels HTTP** dans l'immédiat sauf précision dans le contexte projet.

---

## Face à l'inconnu — règle universelle

**Avant toute modification de code dans un module :**
1. Lire le `DOMAIN.md` du module concerné (`src/{Module}/DOMAIN.md`)
2. Lire les `DOMAIN.md` de tous les modules connectés (colonne "Connecté à"
   dans le tableau des modules ci-dessous)
3. Ne jamais coder sans ce contexte métier

Quand une situation n'est pas couverte par ce document ou par le `DOMAIN.md` du module
concerné — architecture ambiguë, règle métier inconnue, cas limite non documenté —
**toujours poser la question avant de coder**. Ne jamais inventer un comportement ou
une convention manquante.

Cette règle s'applique à :
- Une décision d'architecture non documentée ici
- Une règle métier absente du `DOMAIN.md`
- Un cas limite sur un agrégat ou un invariant
- Un choix de nommage ambigu

---

## Règles absolues (ne jamais faire)

1. Jamais de `flush()` dans un contrôleur, un handler ou un repository — géré par le middleware de transaction
2. Jamais de logique métier dans un contrôleur
3. Jamais d'entité Doctrine dans `Domain/`
4. Jamais d'import Symfony dans `Domain/`
5. Jamais d'instanciation directe de `\DateTimeImmutable` dans `Domain/` ou `Application/` — passer par le Clock Port
6. Jamais d'instanciation directe d'un repository ou notifier dans un handler — passer par l'interface injectée
7. Jamais d'entité Doctrine directement dans un formulaire Symfony
8. Jamais d'installation de bundle sans validation préalable
9. Jamais de texte en dur dans les templates Twig
10. Jamais d'appel direct à un notifier depuis un handler — passer par un Domain Event + Listener
11. Jamais d'envoi d'email dans le cycle de la requête HTTP — toujours via `async.bus`
12. Jamais de constante de mapping dans un contrôleur — utiliser un Enum dans `Domain/Enum/`
13. Jamais de dépendance directe entre modules — les seuls éléments partageables sont les Value Objects et Ports techniques génériques dans `src/Shared/`
14. Jamais de concept métier dans `src/Shared/` — modèles, enums métier et domain events restent dans leur module
15. Jamais de vérification de rôle ou de logique d'autorisation dans le domaine ou dans un contrôleur — toujours un Voter
16. Jamais de modification manuelle du schéma en base — toujours une migration Doctrine
17. Jamais de modification d'une migration déjà exécutée en production — créer une nouvelle
18. Jamais de Provider qui attaque Doctrine directement — passer par un ReadModel Port
19. Jamais de Domain Event dispatché pendant la transaction — toujours après commit
20. Jamais d'auto-increment Doctrine pour un identifiant d'agrégat — UUID v7 généré via `nextIdentity()`
21. Jamais de bus Messenger qui écrit en base sans middleware `doctrine_transaction` — les écritures seront perdues silencieusement
22. Jamais de données sensibles (mots de passe, clés API en clair, secrets HMAC) dans un Domain Event — les propriétés publiques sont sérialisées et persistées

---

## Commandes utiles

```bash
php bin/console doctrine:migrations:migrate
php bin/console cache:clear
php bin/console debug:router
php bin/console debug:container
php bin/console messenger:consume async --limit=50
```

---

## Migrations Doctrine

**Règles :**
- Une migration = un changement cohérent — ne pas regrouper des changements sans rapport
- Les migrations sont **versionnées avec le code** — un commit de code qui modifie
  le schéma inclut toujours sa migration
- Jamais de modification manuelle du schéma en base — toujours passer par une migration
- Les migrations doivent être **réversibles** quand c'est possible (`down()` implémenté)
- Ne jamais modifier une migration déjà exécutée en production — créer une nouvelle

**En cas de migration risquée (rename, suppression de colonne, changement de type) :**
1. Déployer d'abord le code compatible avec l'ancien ET le nouveau schéma
2. Jouer la migration
3. Déployer le code qui ne supporte plus l'ancien schéma

Cette séquence évite les coupures de service lors du déploiement.

---

## Documentation métier par module — DOMAIN.md

Chaque module contient un fichier `DOMAIN.md` qui documente les règles métier
propres à ce module. Ce fichier est la **source de vérité métier** — il ne contient
aucune convention technique (celles-ci restent dans le `claude.md` racine).

```
src/{Module}/
└── DOMAIN.md   # Règles métier, ubiquitous language, invariants
```

**Ce que contient un `DOMAIN.md` :**
- **Ubiquitous Language** — définitions précises des termes métier du module
- **Règles métier** — conditions, seuils, comportements attendus
- **Invariants** — ce qui ne doit jamais être violé dans ce module
- **Flux métier** — séquences d'événements attendus (pas de code, juste la logique)
- **Domain Events publiés et consommés** — quels events ce module émet, et lesquels
  il écoute en provenance d'autres modules
- **Cas non couverts** — section obligatoire rappelant de poser la question plutôt
  qu'interpréter une règle manquante

**Ce qu'il ne contient pas :**
- Conventions de code ou d'architecture (→ `claude.md` racine)
- Détails d'implémentation technique
- Structure de dossiers

Ce fichier peut être lu par un non-développeur. Il constitue la référence partagée
entre le métier et le technique — c'est l'Ubiquitous Language au sens DDD du terme.

### Règle obligatoire de lecture

> **Avant de modifier du code dans un module, lire obligatoirement :**
> 1. Le `DOMAIN.md` du module concerné
> 2. Les `DOMAIN.md` de tous les modules listés dans la colonne "Connecté à"
>    du tableau des modules (voir section Contexte projet)
>
> Ne jamais coder sans ce contexte. Cette règle a la même importance que
> "toujours poser la question avant de coder".

---

## Contexte projet

> **À remplir après `composer create-project`** — section spécifique à chaque site SHbyJM.

### Projet
[Nom du projet] — [Description courte]
- Domaine : [domaine.tld]
- Hébergement : [PlanetHoster N0C ou autre]
- Surfaces : [liste des surfaces UI : site vitrine, admin, API, etc.]

### Structure du projet
[Arborescence du repo si elle s'écarte du skeleton]

### Modules métier
| Module | Rôle | Connecté à | DOMAIN.md |
|--------|------|------------|-----------|
| [À compléter au fur et à mesure de la création des modules] | | | |

### Surfaces UI
| Surface | URL prefix | Auth | Layout |
|---------|-----------|------|--------|
| [À compléter] | | | |

### Stack réelle
| Composant | Version |
|-----------|---------|
| Symfony | 7.x |
| PHP | 8.2+ |
| [Compléter selon le projet] | |

### Intégrations tierces
| Service | Usage | Variables d'environnement |
|---------|-------|--------------------------|
| [À compléter] | | |

### Messenger — configuration du projet

La config de base est livrée par le skeleton (`config/packages/messenger.yaml`) et
n'a pas besoin d'être recréée. Elle fournit :

| Bus | Transport | Middleware | Rôle |
|-----|-----------|-----------|------|
| `command.bus` (défaut) | Synchrone | `doctrine_transaction` | Commands métier |
| `async.bus` | Doctrine (`async`) | `allow_no_handlers` | Tâches lourdes, emails |

Les packages SHbyJM dépendent de cette convention. Ne pas la modifier sans raison.
Ajouter ici uniquement les extensions spécifiques au projet (nouveaux transports,
routings supplémentaires, etc.).

### Déploiement
[À documenter au moment du premier déploiement]

### Dettes techniques connues
| Dette | Sévérité | Action prévue |
|-------|----------|---------------|
| [À compléter au fil du temps] | | |

### Évolutions prévues
- [À compléter]

### Règles spécifiques au projet
- [À compléter selon les particularités du projet]
