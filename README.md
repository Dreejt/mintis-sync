# Mintis Sync

Sync script voor Bedrock WordPress projecten. Database en uploads synchroniseren tussen development, staging en production — via WP-CLI aliassen en rsync.

> Zit standaard ingebakken in [mintis-26](https://github.com/Dreejt/mintis-26) projecten.

## Quick Start

**1. Installeer het pakket**
```bash
composer require dreejt/mintis-sync
```

**2. Voeg variabelen toe aan je `.env`**
```env
SERVER_USER='ploi'
SERVER_IP='123.45.67.89'
SERVER_BASE_PATH='/home/ploi'

PROD_DOMAIN='www.jouwsite.nl'
STAGING_DOMAIN='staging.jouwsite.nl'
DEV_DOMAIN='jouwsite.test'
```

**3. Genereer `wp-cli.yml`** (één keer per project, checkin in git)
```bash
composer setup-wp-cli
```

**4. Sync**
```bash
composer sync production development   # ⬇️  pull van production naar lokaal
```

Dat is alles. De rest is optioneel.

---

## Features

- Database sync met automatische search-replace
- Assets (uploads) sync via rsync
- Multisite ondersteuning (wp_blogs & wp_site)
- **Maintenance mode** — automatisch aan vóór sync, uit erna (bezoekers zien onderhoudspagina, geen halve sync)
- Automatische database backup vóór sync (sync stopt als backup mislukt)
- Post-sync validatie: `wp core verify-checksums` + HTTP bereikbaarheidscheck
- **Plugin management** — configureer per omgeving welke plugins aan/uit gaan na sync via `.sync`
- Dry-run modus (`--dry-run`)
- Command-only modus (`--command-only`) — toon alle commando's zonder iets uit te voeren
- Genummerde stappen in output (`[1/5] Verbinding controleren...`)
- Productie-beveiliging (bevestiging vereist)
- Kleurgecodeerde feedback
- Pre-flight validatie (WP-CLI lokaal én remote, rsync, .env)
- Auto-generatie van wp-cli.yml vanuit .env
- Automatische update-melding bij nieuwe versie

---

## Installatie

### Via Composer (aanbevolen)

```bash
composer require dreejt/mintis-sync
```

### Handmatig

```bash
curl -o scripts/sync.sh https://raw.githubusercontent.com/Dreejt/mintis-sync/main/sync.sh
curl -o scripts/setup-wp-cli.php https://raw.githubusercontent.com/Dreejt/mintis-sync/main/setup-wp-cli.php
chmod +x scripts/sync.sh
```

---

## Configuratie

### `.env` variabelen

Voeg toe aan het bestaande `.env` bestand in je project root:

```env
# Server (zelfde voor staging en production als ze op dezelfde server staan)
SERVER_USER='ploi'
SERVER_IP='123.45.67.89'
SERVER_BASE_PATH='/home/ploi'

# Domeinen (zonder protocol)
PROD_DOMAIN='www.jouwsite.nl'
STAGING_DOMAIN='staging.jouwsite.nl'
DEV_DOMAIN='jouwsite.test'
```

### `wp-cli.yml` genereren

Na het invullen van `.env`, genereer je `wp-cli.yml` met de WP-CLI alias configuratie voor staging en production:

```bash
composer setup-wp-cli
```

Dit bestand (`wp-cli.yml`) commit je in git zodat het op alle machines beschikbaar is.

### `.sync` bestand (optioneel)

Wil je plugin management of standaard-opties instellen, maak dan een `.sync` bestand in je project root (op basis van `.sync.example`):

```bash
cp vendor/dreejt/mintis-sync/.sync.example .sync
```

Voorbeeld configuratie:
```bash
# .sync
PLUGINS_ACTIVATE_ON_DEVELOPMENT=("wp-mail-smtp")
PLUGINS_DEACTIVATE_ON_DEVELOPMENT=("updraftplus" "nginx-helper" "redis-cache")

PLUGINS_ACTIVATE_ON_STAGING=("wp-mail-smtp" "nginx-helper" "redis-cache")
PLUGINS_DEACTIVATE_ON_STAGING=("updraftplus")

PLUGINS_ACTIVATE_ON_PRODUCTION=("wp-mail-smtp" "updraftplus" "nginx-helper" "redis-cache")
PLUGINS_DEACTIVATE_ON_PRODUCTION=()
```

Plugins die niet bestaan op de doelomgeving worden automatisch overgeslagen. **Zonder `.sync` bestand werkt alles gewoon** — plugin management wordt dan overgeslagen.

---

## Gebruik

### Vrije syntax

```bash
composer sync production development
composer sync staging development
composer sync development staging
composer sync development production
composer sync production staging
composer sync staging production
```

### Shortcuts

```bash
composer sync:production-development   # ⬇️  veilig
composer sync:staging-development      # ⬇️  veilig
composer sync:development-staging      # ⬆️  veilig
composer sync:development-production   # ⬆️  ⚠️ vraagt domeinnaam ter bevestiging
composer sync:production-staging       # ↔️  veilig
composer sync:staging-production       # ↔️  ⚠️ vraagt domeinnaam ter bevestiging
```

### Opties

```bash
composer sync production development -- --skip-db       # Alleen uploads
composer sync production development -- --skip-assets   # Alleen database
composer sync production development -- --dry-run       # Preview, geen wijzigingen
composer sync production development -- --command-only  # Toon alle commando's, doe niets
```

### Voorbeelden

```bash
# Production naar lokaal (alleen database)
composer sync production development -- --skip-assets

# Staging naar lokaal (alleen uploads)
composer sync staging development -- --skip-db

# Preview wat er zou gebeuren
composer sync production development -- --dry-run

# Bekijk exact welke WP-CLI commando's worden uitgevoerd
composer sync production development -- --command-only

# Production naar staging (bijv. na hotfix)
composer sync production staging

# Lokaal naar staging pushen
composer sync development staging
```

### Beveiliging bij sync naar production

Bij elke sync **naar** production verschijnt een extra bevestigingsscherm:

```
⛔  WAARSCHUWING: je staat op het punt PRODUCTIE te overschrijven

  Van:  https://staging.jouwsite.nl
  Naar: https://www.jouwsite.nl

  Dit vervangt de live database en uploads. Dit is onomkeerbaar.

  Typ de productie-domeinnaam om te bevestigen: www.jouwsite.nl
  >
```

Je moet de exacte domeinnaam typen — dat is per ongeluk niet goed in te vullen.

---

## Veiligheid

- **Database backup**: voor elke sync wordt automatisch een timestamped backup gemaakt in `backups/` — sync stopt als de backup mislukt
- **Maintenance mode**: automatisch geactiveerd op de doelomgeving vóór de sync, gedeactiveerd na afloop — bij crash wordt maintenance mode alsnog uitgeschakeld
- **Post-sync validatie**: WordPress core bestanden worden geverifieerd (`wp core verify-checksums`) en de site wordt via HTTP getest
- **Productie-beveiliging**: bij sync naar productie moet je de exacte domeinnaam typen ter bevestiging
- **Pre-flight checks**: WP-CLI (lokaal én remote), rsync, SSH-verbinding en `.env` variabelen worden gevalideerd

---

## Vereisten

- PHP ≥ 8.1
- WP-CLI (lokaal + remote)
- rsync
- SSH-toegang tot servers

---

## Release workflow (voor contributors)

1. Voeg bovenaan `CHANGELOG.md` een nieuw versieblok toe
2. Commit en push naar `main`
3. GitHub Action maakt automatisch de git tag aan
4. Packagist pikt de nieuwe versie op

Zie [CLAUDE.md](CLAUDE.md) voor meer context over het project.

## Changelog

Zie [CHANGELOG.md](CHANGELOG.md) voor versiegeschiedenis.

## Licentie

MIT — zie [LICENSE](LICENSE).

---

Gemaakt door [Mintis](https://mintis.nl)


- Database sync met automatische search-replace
- Assets (uploads) sync via rsync
- Multisite ondersteuning (wp_blogs & wp_site)
- **Maintenance mode** — automatisch aan vóór sync, uit erna (bezoekers zien onderhoudspagina, geen halve sync)
- Automatische database backup vóór sync (sync stopt als backup mislukt)
- Post-sync validatie: `wp core verify-checksums` + HTTP bereikbaarheidscheck
- **Plugin management** — configureer per omgeving welke plugins aan/uit gaan na sync via `.sync`
- Dry-run modus (`--dry-run`)
- Command-only modus (`--command-only`) — toon alle commando's zonder iets uit te voeren
- Genummerde stappen in output (`[1/5] Verbinding controleren...`)
- Productie-beveiliging (bevestiging vereist)
- Kleurgecodeerde feedback
- Pre-flight validatie (WP-CLI lokaal én remote, rsync, .env)
- Auto-generatie van wp-cli.yml vanuit .env
- Automatische update-melding bij nieuwe versie

## Installatie

### Via Composer (aanbevolen)

```bash
composer require dreejt/mintis-sync
```

> **Tip:** Zit al standaard in [mintis-26](https://github.com/Dreejt/mintis-26) projecten.

### Handmatig

```bash
curl -o scripts/sync.sh https://raw.githubusercontent.com/Dreejt/mintis-sync/main/sync.sh
curl -o scripts/setup-wp-cli.php https://raw.githubusercontent.com/Dreejt/mintis-sync/main/setup-wp-cli.php
chmod +x scripts/sync.sh
```

## Configuratie

Voeg deze variabelen toe aan je `.env`:

```env
# Server
SERVER_USER='ploi'
SERVER_IP='123.45.67.89'
SERVER_BASE_PATH='/home/ploi'

# Domeinen
PROD_DOMAIN='www.jouwsite.nl'
STAGING_DOMAIN='staging.jouwsite.nl'
DEV_DOMAIN='jouwsite.test'
```

Genereer daarna `wp-cli.yml`:

```bash
# Via Composer script
composer setup-wp-cli

# Of handmatig
php vendor/dreejt/mintis-sync/setup-wp-cli.php
```

### Plugin management (optioneel)

Maak een `.sync` bestand in je projectroot (op basis van `.sync.example`) en configureer welke plugins per omgeving aan- of uitgeschakeld moeten worden na een sync:

```bash
# .sync
PLUGINS_ACTIVATE_ON_DEVELOPMENT=("wp-mail-smtp")
PLUGINS_DEACTIVATE_ON_DEVELOPMENT=("updraftplus" "nginx-helper" "redis-cache")

PLUGINS_ACTIVATE_ON_STAGING=("wp-mail-smtp" "nginx-helper" "redis-cache")
PLUGINS_DEACTIVATE_ON_STAGING=("updraftplus")

PLUGINS_ACTIVATE_ON_PRODUCTION=("wp-mail-smtp" "updraftplus" "nginx-helper" "redis-cache")
PLUGINS_DEACTIVATE_ON_PRODUCTION=()
```

Plugins die niet bestaan op de doelomgeving worden automatisch overgeslagen.

## Gebruik

### Help & overzicht

```bash
# Toon alle beschikbare sync-richtingen
composer sync help
composer sync -- --help

# Of direct via script
./vendor/dreejt/mintis-sync/sync.sh --help
```

### Vrije syntax

```bash
composer sync production development
composer sync staging development
composer sync development staging
composer sync development production
composer sync production staging
composer sync staging production
```

### Shortcuts

```bash
composer sync:production-development   # ⬇️  veilig
composer sync:staging-development      # ⬇️  veilig
composer sync:development-staging      # ⬆️  veilig
composer sync:development-production   # ⬆️  ⚠️ vraagt domeinnaam ter bevestiging
composer sync:production-staging       # ↔️  veilig
composer sync:staging-production       # ↔️  ⚠️ vraagt domeinnaam ter bevestiging
```

### Opties

```bash
composer sync production development -- --skip-db       # Alleen uploads
composer sync production development -- --skip-assets   # Alleen database
composer sync production development -- --dry-run       # Preview, geen wijzigingen
composer sync production development -- --command-only  # Toon alle commando's, doe niets
```

### Voorbeelden

```bash
# Production naar lokaal (alleen database)
composer sync production development -- --skip-assets

# Staging naar lokaal (alleen uploads)
composer sync staging development -- --skip-db

# Preview wat er zou gebeuren
composer sync production development -- --dry-run

# Production naar staging (bijv. na hotfix)
composer sync production staging

# Lokaal naar staging pushen
composer sync development staging
```

### Beveiliging bij sync naar production

Bij elke sync **naar** production verschijnt een extra scherm:

```
⛔  WAARSCHUWING: je staat op het punt PRODUCTIE te overschrijven

  Van:  https://staging.jouwsite.nl
  Naar: https://www.jouwsite.nl

  Dit vervangt de live database en uploads. Dit is onomkeerbaar.

  Typ de productie-domeinnaam om te bevestigen: www.jouwsite.nl
  >
```

Je moet de exacte domeinnaam typen — dat is per ongeluk niet goed in te vullen.

## Veiligheid

- **Database backup**: voor elke sync wordt automatisch een timestamped backup gemaakt in `backups/` — sync stopt als de backup mislukt
- **Maintenance mode**: automatisch geactiveerd op de doelomgeving vóór de sync, gedeactiveerd na afloop — bij crash wordt maintenance mode alsnog uitgeschakeld
- **Post-sync validatie**: WordPress core bestanden worden geverifieerd (`wp core verify-checksums`) en de site wordt via HTTP getest
- **Productie-beveiliging**: bij sync naar productie moet je de exacte domeinnaam typen ter bevestiging
- **Pre-flight checks**: WP-CLI (lokaal én remote), rsync, SSH-verbinding en .env variabelen worden gevalideerd

## Vereisten

- PHP ≥ 8.1
- WP-CLI (lokaal + remote)
- rsync
- SSH-toegang tot servers

## Release workflow (voor contributors)

1. Voeg bovenaan `CHANGELOG.md` een nieuw versieblok toe
2. Commit en push naar `main`
3. GitHub Action maakt automatisch de git tag aan
4. Packagist pikt de nieuwe versie op

Zie [CLAUDE.md](CLAUDE.md) voor meer context over het project.

## Changelog

Zie [CHANGELOG.md](CHANGELOG.md) voor versiegeschiedenis.

## Licentie

MIT — zie [LICENSE](LICENSE).

---

Gemaakt door [Mintis](https://mintis.nl)
