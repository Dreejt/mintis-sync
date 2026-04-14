# Changelog

All notable changes to this project will be documented in this file.

## [1.8.4] - 2026-04-14

### Fixed
- Horizontal sync (staging↔production) op dezelfde server: detecteert nu of bron- en doelhost identiek zijn en gebruikt lokale rsync in plaats van SSH-naar-zichzelf, wat failde op `Permission denied (publickey)`
- `--command-only` preview toont nu het juiste commando voor same-server en cross-server horizontal syncs
- Assets confirmatiebericht toont nu ook het doeldomein (was niet zichtbaar bij `--skip-db`)

## [1.8.3] - 2026-03-09

### Changed
- Backupbestandsnamen hebben nu het formaat `staging-backup-2026-03-09_133314.sql` (leesbare datum, duidelijke omgeving)
- Remote backup is nu fataal: als die mislukt wordt de sync afgebroken met duidelijke foutmelding en tip over schrijfrechten
- Feedback-teksten van backupstappen zijn Nederlandstalig en vermelden expliciet de omgeving en het pad

## [1.8.2] - 2026-03-09

### Added
- Remote database backup: bij sync naar staging of production wordt nu ook een backup aangemaakt op de server zelf in `backups/` — niet fataal, lokale backup blijft altijd beschikbaar

## [1.8.1] - 2026-03-09

### Fixed
- `${TO^^}` bash 4+ uppercase syntax vervangen door `tr '[:lower:]' '[:upper:]'` — crash op macOS (bash 3.2) bij plugin management

## [1.8.0] - 2026-03-09

### Added
- `--help` en `-h` flags tonen nu uitgebreide help met alle beschikbare sync-richtingen
- `help` en `list` commando's tonen hetzelfde overzicht
- Help-functie toont kleurgecodeerde veiligheid-indicatoren voor elke sync-richting
- Voorbeelden en composer shortcuts toegevoegd aan help-output
- README.md bijgewerkt met help-commando documentatie

## [1.7.0] - 2026-03-08

### Added
- Plugin management: configure which plugins to activate/deactivate per environment after sync via `.sync` arrays (`PLUGINS_ACTIVATE_ON_PRODUCTION`, `PLUGINS_DEACTIVATE_ON_DEVELOPMENT`, etc.) — missing plugins are silently skipped, never fatal
- `.DS_Store` cleanup before rsync: macOS artefacts are removed from the local uploads directory before syncing to prevent them ending up on the server
- `--command-only` block now also shows plugin management commands

## [1.6.0] - 2026-03-08

### Added
- Maintenance mode: automatically activated on the target environment before sync, deactivated after — prevents visitors from seeing a half-synced site
- Numbered step progress: output now shows `[1/6] Connecting...` through `[6/6] Post-sync checks` so you always know where you are
- `--command-only` flag: shows all WP-CLI and rsync commands that would be executed without running anything — useful for auditing and documentation
- Post-sync: `wp core verify-checksums` to verify WordPress core file integrity after sync
- Post-sync: `curl --head` HTTP check to verify the target site returns 200/301/302
- ERR trap now automatically deactivates maintenance mode if the sync crashes mid-way

## [1.5.9] - 2026-03-06

### Fixed
- Multisite domain-update toont geen `Error: Table 'wp_blogs' doesn't exist` meer op single-site installaties — tabel wordt nu eerst gecontroleerd voor de query wordt uitgevoerd
- Bij crash toont het script nu welke stappen nog niet voltooid zijn, inclusief het exacte commando om alleen de assets alsnog te syncen

## [1.5.8] - 2026-03-06

### Added
- Post-sync health check: detecteert automatisch of de site na sync reageert
- Bij 'autoloader' fout toont het script het exacte `composer install` SSH-commando om de site te herstellen

## [1.5.7] - 2026-03-06

### Fixed
- `search-replace` faalde met "Error locating autoloader" na database-import: WP-CLI probeerde WordPress te laden met de development-URL die net in de database stond. Opgelost met `--url=$FROMSITE` en `--skip-plugins --skip-themes`

## [1.5.6] - 2026-03-06

### Security
- Alle `read` prompts lezen nu van `/dev/tty` — piping van stdin kan bevestigingen niet meer omzeilen (`echo "y" | composer sync staging production` werkt niet meer)
- Sync naar production geblokkeerd als `PROD_DOMAIN` leeg of niet ingesteld is in `.env`

## [1.5.5] - 2026-03-06

### Changed
- Composer shortcuts hernoemd naar expliciete richtingsnamen (`sync:production-development` etc.)
- `composer sync production development` werkt nu direct als vrije syntax
- README: gebruik-sectie herschreven met vrije syntax en shortcuts

## [1.5.4] - 2026-03-06

### Added
- Alle 6 sync-richtingen als composer scripts (`sync:up-prod`, `sync:prod-to-stage`, `sync:stage-to-prod`) in mintis-26 en klaasjangeertsema

### Changed
- Productie-beveiliging: vereist nu het typen van de exacte domeinnaam (`PROD_DOMAIN`) i.p.v. het generieke woord 'production' — onmogelijk per ongeluk te bevestigen
- README: gebruik-sectie volledig herschreven met alle 6 richtingen en uitleg beveiliging

## [1.5.3] - 2026-03-06

### Changed
- README: alle zes sync-richtingen gedocumenteerd met overzichtstabel en voorbeelden

## [1.5.2] - 2026-03-06

### Added
- **Auto-update check** — waarschuwing bij verouderde versie (max 1× per dag, gecached in `.sync-update-check`)
- **`CLAUDE.md`** — context voor AI-assistenten met release-workflow en conventies
- **GitHub Action** (`.github/workflows/release.yml`) — automatische git tag op basis van versie in `CHANGELOG.md`; geen handmatige tags meer nodig

### Changed
- `SCRIPT_VERSION` wordt nu automatisch gelezen uit `vendor/composer/installed.json` — nooit meer handmatig bijwerken

### Fixed
- Backup-fout blokkeert nu de sync (was: waarschuwing en doorgaan)
- Betere foutmelding wanneer WP-CLI niet aanwezig is op de remote server (`command not found` wordt nu herkend)

## [1.5.1] - 2026-02-16

### Fixed
- Path resolution for Composer wrapper exec (not a symlink but a wrapper script)
- Detect vendor path by checking SCRIPT_DIR pattern instead of symlink check

## [1.5.0] - 2026-02-16

### Added
- **Composer package support** — install via `composer require dreejt/mintis-sync`
- `composer.json` with bin entries for `sync.sh` and `setup-wp-cli.php`
- Smart path resolution: works from `scripts/`, `vendor/bin/`, and `vendor/dreejt/mintis-sync/`

### Changed
- README updated for Composer-first workflow
- Version bumped to 1.5.0

## [1.4.0] - 2026-02-11

### Added
- **Database backup before sync** — timestamped `.sql` backup saved to `backups/` before resetting target DB
- **`set -eo pipefail`** — script now stops immediately on errors instead of silently continuing
- **`--dry-run` mode** — preview what would be synced without making changes
- **Production safety check** — requires typing 'production' to confirm when syncing TO production
- **`wp_from_cmd` / `wp_to_cmd` helpers** — transparent local vs remote WP-CLI command routing

### Fixed
- Removed duplicate `bold`/`normal` variable definitions (now uses `BOLD`/`NORMAL` consistently)
- Database import failure now shows backup file location for recovery

### Removed
- Unused `spinner()` function (dead code)
- 3x copy-pasted DB sync logic — replaced with single `sync_database()` function

## [1.3.0] - 2025-01-XX

### Added (Inspired by Trellis)
- **Color-coded status feedback** with green/red/yellow/blue symbols
- **Pre-flight validation** checks for WP-CLI, rsync, and required .env variables
- **Better error messages** with automatic troubleshooting hints
- **Progress spinners** for long-running operations
- **Optional config file** (.sync) for project-specific defaults
- Helper functions: `success()`, `error()`, `warning()`, `info()`

### Improved
- Error messages now include actionable troubleshooting steps
- Validates all requirements before starting sync
- Clearer visual feedback during sync process
- Better structured output with consistent formatting
- **setup-wp-cli.php now protects existing custom wp-cli.yml files**
- Added `--force` flag to setup-wp-cli.php for automated workflows

### Changed
- Version bumped to 1.3.0
- Updated README with new features and better documentation
## [1.0.0] - 2026-01-12

### Added
- Initial release
- Database sync with automatic search-replace
- Assets (uploads) sync via rsync
- Multisite support (wp_blogs & wp_site domain updates)
- SSH-based remote sync
- Skip options (--skip-db, --skip-assets)
- Auto-generated wp-cli.yml from .env
- Cache flushing after database sync

### Enhanced from Roots.io original
- Multisite domain updates
- Better .env integration
- Improved error handling
- Silent fallback for single-site installations
- Cache flushing
