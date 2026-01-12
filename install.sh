#!/bin/bash

# Bedrock Sync Script Installer
# Version: 1.0.0

REPO_URL="https://raw.githubusercontent.com/YOUR-USERNAME/bedrock-sync/main"
bold=$(tput bold)
normal=$(tput sgr0)

echo "${bold}🚀 Bedrock Sync Script Installer${normal}"
echo ""

# Check if in Bedrock project
if [ ! -f "composer.json" ] || [ ! -d "web/wp" ]; then
    echo "❌ This doesn't appear to be a Bedrock project."
    echo "   Make sure you're in the project root directory."
    exit 1
fi

# Create scripts directory if needed
mkdir -p scripts

# Download sync script
echo "📥 Downloading sync.sh..."
if curl -fsSL "${REPO_URL}/sync.sh" -o scripts/sync.sh; then
    chmod +x scripts/sync.sh
    echo "✅ sync.sh installed"
else
    echo "❌ Failed to download sync.sh"
    exit 1
fi

# Download setup-wp-cli.php if not exists
if [ ! -f "scripts/setup-wp-cli.php" ]; then
    echo "📥 Downloading setup-wp-cli.php..."
    if curl -fsSL "${REPO_URL}/setup-wp-cli.php" -o scripts/setup-wp-cli.php; then
        echo "✅ setup-wp-cli.php installed"
    else
        echo "❌ Failed to download setup-wp-cli.php"
    fi
fi

echo ""
echo "${bold}✅ Installation complete!${normal}"
echo ""
echo "Next steps:"
echo "1. Add required variables to your .env file:"
echo "   ${bold}PROD_DOMAIN, STAGING_DOMAIN, DEV_DOMAIN${normal}"
echo "   ${bold}SERVER_USER, SERVER_IP, SERVER_BASE_PATH${normal}"
echo ""
echo "2. Generate wp-cli.yml:"
echo "   ${bold}php scripts/setup-wp-cli.php${normal}"
echo ""
echo "3. Test the sync:"
echo "   ${bold}bash scripts/sync.sh production development${normal}"
echo ""
