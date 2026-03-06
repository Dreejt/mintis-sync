# Mintis Sync

Sync script voor Bedrock WordPress projecten. Database en uploads synchroniseren tussen development, staging en production.

## Features

- Database sync met automatische search-replace
- Assets (uploads) sync via rsync
- Multisite ondersteuning (wp_blogs & wp_site)
- Automatische database backup vóór sync (sync stopt bij mislukken backup)
- Dry-run modus (`--dry-run`)
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
- **Productie-beveiliging**: bij sync naar productie moet je 'production' typen ter bevestiging
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
