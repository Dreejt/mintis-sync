# GitHub Repository Setup

Je lokale git repository is klaar! Kies één van de volgende methoden:

## Optie 1: Via GitHub Website (Snelst)

1. **Ga naar GitHub en maak nieuwe repo aan:**
   - https://github.com/new
   - Repository name: `mintis-sync`
   - Description: `Production-ready sync script for Bedrock WordPress projects`
   - **Public** (of Private als je wilt)
   - ❌ **NIET** initialiseren met README, .gitignore of license (we hebben die al!)

2. **Push je lokale code:**
   ```bash
   cd /Users/tjeerd/Sites/mintis-sync
   git remote add origin git@github.com:JOUW-USERNAME/mintis-sync.git
   git branch -M main
   git push -u origin main
   ```

## Optie 2: Via GitHub CLI (Voor later)

Installeer eerst GitHub CLI:
```bash
brew install gh
gh auth login
```

Dan:
```bash
cd /Users/tjeerd/Sites/mintis-sync
gh repo create mintis-sync --public --source=. --remote=origin --push
```

## Na het pushen

### Update install.sh URLs
Vervang in [install.sh](install.sh) en [README.md](README.md):
```bash
# Van:
https://raw.githubusercontent.com/YOUR-USERNAME/mintis-sync/main/

# Naar:
https://raw.githubusercontent.com/mintisagency/mintis-sync/main/
# (of jouw username)
```

### Test de installer
```bash
curl -fsSL https://raw.githubusercontent.com/JOUW-USERNAME/mintis-sync/main/install.sh | bash
```

## Volgende stappen

1. **Add topics op GitHub:**
   - `wordpress`
   - `bedrock`
   - `wp-cli`
   - `database-sync`
   - `multisite`
   - `trellis`

2. **Maak een GitHub Release:**
   - Ga naar: https://github.com/JOUW-USERNAME/mintis-sync/releases/new
   - Tag: `v1.3.0`
   - Title: `v1.3.0 - Trellis-inspired improvements`
   - Description: Copy from CHANGELOG.md

3. **Optioneel: GitHub Actions voor testing:**
   - Syntax check
   - ShellCheck linting

## Voor je team

Nu kunnen collega's het gebruiken:
```bash
curl -fsSL https://raw.githubusercontent.com/mintisagency/mintis-sync/main/install.sh | bash
```

Of handmatig in hun project:
```bash
curl -o scripts/sync.sh https://raw.githubusercontent.com/mintisagency/mintis-sync/main/sync.sh
curl -o scripts/setup-wp-cli.php https://raw.githubusercontent.com/mintisagency/mintis-sync/main/setup-wp-cli.php
chmod +x scripts/sync.sh
```
