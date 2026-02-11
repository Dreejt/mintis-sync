# Changelog

All notable changes to this project will be documented in this file.

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
