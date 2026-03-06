# Changelog

All notable changes to this project will be documented in this file.

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
