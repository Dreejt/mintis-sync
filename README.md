# Mintis Sync

Sync script voor Bedrock WordPress projecten. Database en uploads synchroniseren tussen development, staging en production.

## Features

- Database sync met automatische search-replace
- Assets (uploads) sync via rsync
- Multisite ondersteuning (wp_blogs & wp_site)
- Automatische database backup vóór sync
- Dry-run modus (`--dry-run`)
- Productie-beveiliging (bevestiging vereist)
- Kleurgecodeerde feedback
- Pre-flight validatie (WP-CLI, rsync, .env)
- Auto-generatie van wp-cli.yml vanuit .env

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
STAGING_DOMAIN='test.jouwsite.nl'
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

### Via Composer (als script geconfigureerd)

```bash
composer sync production development       # Production → lokaal
composer sync staging development          # Staging → lokaal
composer sync development staging          # Lokaal → staging
```

### Direct

```bash
vendor/bin/sync.sh production development
```

### Opties

```bash
--skip-db         # Alleen uploads syncen
--skip-assets     # Alleen database syncen
--dry-run         # Preview zonder wijzigingen
```

### Voorbeelden

```bash
# Alleen database van productie naar lokaal
composer sync production development --skip-assets

# Alleen uploads van staging naar lokaal
composer sync staging development --skip-db

# Preview wat er zou gebeuren
composer sync production development --dry-run
```

## Veiligheid

- **Database backup**: voor elke sync wordt automatisch een timestamped backup gemaakt in `backups/`
- **Productie-beveiliging**: bij sync naar productie moet je 'production' typen ter bevestiging
- **Pre-flight checks**: WP-CLI, rsync, SSH-verbinding en .env variabelen worden gevalideerd

## Vereisten

- PHP ≥ 8.1
- WP-CLI (lokaal + remote)
- rsync
- SSH-toegang tot servers

## Changelog

Zie [CHANGELOG.md](CHANGELOG.md) voor versiegeschiedenis.

## Licentie

MIT — zie [LICENSE](LICENSE).

---

Gemaakt door [Mintis](https://mintis.nl)
