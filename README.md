# Mintis Bedrock Sync

Production-ready sync script for Bedrock WordPress projects. Supports both single-site and multisite installations.

**Inspired by Trellis:** Enhanced with color-coded feedback, pre-flight validation, and better error handling.

## 🚀 Features

- ✅ Database sync with automatic search-replace
- ✅ Assets (uploads) sync via rsync
- ✅ Multisite domain updates (wp_blogs & wp_site)
- ✅ SSH-based remote sync
- ✅ **Color-coded status feedback** (success, error, warning, info)
- ✅ **Pre-flight validation** (checks WP-CLI, rsync, .env)
- ✅ **Better error messages** with troubleshooting hints
- ✅ **Progress spinners** for long operations
- ✅ **Optional config file** (.sync) for project defaults
- ✅ Flexible skip options (--skip-db, --skip-assets)
- ✅ Safe: always creates backups before operations
- ✅ Auto-generate wp-cli.yml from .env

## 📋 Requirements

- WP-CLI installed
- rsync installed
- SSH access to production/staging servers
- Bedrock project structure
- `.env` file with domain configuration

## ⚡️ Quick Start

### One-line installation

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR-USERNAME/mintis-sync/main/install.sh | bash
```

### Manual installation

1. **Copy sync script**
```bash
curl -o scripts/sync.sh https://raw.githubusercontent.com/YOUR-USERNAME/mintis-sync/main/sync.sh
curl -o scripts/setup-wp-cli.php https://raw.githubusercontent.com/YOUR-USERNAME/mintis-sync/main/setup-wp-cli.php
chmod +x scripts/sync.sh
```

2. **Add to your .env**
```env
# Domain Configuration (required for sync script)
PROD_DOMAIN='www.yoursite.com'
STAGING_DOMAIN='staging.yoursite.com'
DEV_DOMAIN='yoursite.test'

# Server Configuration (required for remote sync)
SERVER_USER='ploi'
SERVER_IP='123.45.67.89'
SERVER_BASE_PATH='/home/ploi'
```

3. **Generate wp-cli.yml**
```bash
php scripts/setup-wp-cli.php
```

**⚠️ Safety feature:** If you have a custom wp-cli.yml, the script will ask for confirmation before overwriting. To force overwrite:
```bash
php scripts/setup-wp-cli.php --force
```

4. **Optional: Create config file for defaults**
```bash
cp scripts/.sync.example .sync
# Edit .sync to customize defaults
```

## 📖 Usage

### Pull from production to local
```bash
bash scripts/sync.sh production development
```

### Pull from staging to local
```bash
bash scripts/sync.sh staging development
```

### Push from local to staging
```bash
bash scripts/sync.sh development staging
```

### Skip database sync (only sync assets)
```bash
bash scripts/sync.sh production development --skip-db
```

### Skip assets sync (only sync database)
```bash
bash scripts/sync.sh production development --skip-assets
```

## 🎨 Color-Coded Feedback

The sync script provides clear visual feedback:
- **[✓]** Green: Success messages
- **[✗]** Red: Error messages with troubleshooting hints
- **[⚠]** Yellow: Warning messages
- **[ℹ]** Blue: Information messages

## 🔧 Configuration File

Create a `.sync` file in your project root for custom defaults:

```bash
# Skip options
SKIP_DB=false
SKIP_ASSETS=false

# Optional: Custom rsync options
RSYNC_OPTIONS="-az --progress --exclude=.DS_Store"

# Optional: Slack notifications
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/xxx
SLACK_CHANNEL=#site
```

## 🔍 Pre-flight Validation

Before syncing, the script validates:
- ✓ WP-CLI is installed
- ✓ rsync is installed
- ✓ Required .env variables are set
- ✓ wp-cli.yml exists
- ✓ SSH connections work

## 🔧 How It Works

### Database Sync
1. Exports source database
2. Resets destination database
3. Imports database
4. Runs search-replace for URLs
5. Updates multisite domains (wp_blogs & wp_site tables)
6. Flushes cache

### Assets Sync
- Uses rsync for efficient file transfer
- Only transfers changed files
- Preserves file permissions

## 🐛 Troubleshooting

The script provides helpful troubleshooting hints for common issues:

### "Unable to connect to production/development"
**Automatic hints provided:**
- Check if wp-cli.yml is configured correctly
- Verify SSH access: `ssh user@server-ip`
- Ensure WP-CLI is installed on remote server

### "WP-CLI is not installed"
**Automatic hint:** Install WP-CLI: https://wp-cli.org/#installing

### "rsync is not installed"
**Automatic hint:** Install rsync:
- macOS: `brew install rsync`
- Linux: `apt-get install rsync`

### Manual troubleshooting
- Test WP-CLI: `wp @production core version`
- Verify SSH: `ssh user@server-ip`

## 📝 File Structure

```
mintis-sync/
├── sync.sh              # Main sync script
├── setup-wp-cli.php     # Generates wp-cli.yml from .env
├── install.sh           # One-line installer
├── .env.example         # Example .env configuration
├── README.md            # This file
├── CHANGELOG.md         # Version history
├── CONTRIBUTING.md      # Contribution guidelines
└── LICENSE              # MIT License
```

## 🎯 For Agencies

Perfect for agencies managing multiple Bedrock projects:

1. **Consistent workflow** across all projects
2. **Safe syncs** with automatic backups
3. **Time-saving** automation
4. **Multisite support** out of the box

## 🙏 Credits

Based on the original sync script from [Roots.io](https://roots.io), enhanced with:
- Multisite support
- Better .env integration
- Improved error handling
- Cache flushing
- Auto wp-cli.yml generation

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

Made with ❤️ by [Mintis](https://mintis.nl)
