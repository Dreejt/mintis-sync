#!/bin/bash
set -eo pipefail

# Syncing Trellis & Bedrock-based WordPress environments with WP-CLI aliases
# Copyright (c) Ben Word | modification by Tjeerd

# Version is read from vendor/composer/installed.json — no need to update manually
SCRIPT_VERSION="dev"
if [[ "$SCRIPT_DIR" == */vendor/* ]]; then
    _installed_json="$(cd "$SCRIPT_DIR" && cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "../../..")" && pwd)/vendor/composer/installed.json"
    if [[ -f "$_installed_json" ]]; then
        _ver=$(grep -A2 '"name": "dreejt/mintis-sync"' "$_installed_json" | grep '"version"' | head -1 | sed 's/.*": "//;s/".*//' | sed 's/^v//')
        [[ -n "$_ver" ]] && SCRIPT_VERSION="$_ver"
    fi
fi

# Color definitions (inspired by Trellis)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD=$(tput bold 2>/dev/null || echo '')
NORMAL=$(tput sgr0 2>/dev/null || echo '')

# Status symbols
SUCCESS="✓"
ERROR="✗"
WARNING="⚠"
INFO="ℹ"

# Helper functions for colored output
success() { echo -e "${GREEN}[${SUCCESS}]${NC} $1"; }
error() { echo -e "${RED}[${ERROR}]${NC} $1" >&2; }
warning() { echo -e "${YELLOW}[${WARNING}]${NC} $1"; }
info() { echo -e "${BLUE}[${INFO}]${NC} $1"; }

# Get project root - works from scripts/, vendor/bin/, or vendor/dreejt/mintis-sync/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect if running from inside vendor/ (Composer package)
if [[ "$SCRIPT_DIR" == */vendor/dreejt/mintis-sync ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
elif [[ "$SCRIPT_DIR" == */vendor/bin ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
    # Running directly from scripts/ or project root
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# Load optional config file (.sync)
if [ -f "$PROJECT_ROOT/.sync" ]; then
    source "$PROJECT_ROOT/.sync"
    info "Loaded config from .sync"
fi

# Load .env file
if [ -f "$PROJECT_ROOT/.env" ]; then
    export $(cat "$PROJECT_ROOT/.env" | grep -v '^#' | grep -v '^$' | xargs)
else
    error ".env file not found at $PROJECT_ROOT/.env"
    info "Create a .env file with the following variables:"
    echo "  - DEV_DOMAIN, STAGING_DOMAIN, PROD_DOMAIN"
    echo "  - SERVER_USER, SERVER_IP, SERVER_BASE_PATH"
    exit 1
fi

# Check if a newer version of mintis-sync is available on GitHub (max once per day)
check_for_updates() {
    # Only check when running via Composer (not during development of the package itself)
    if [[ "$SCRIPT_DIR" != */vendor/* ]]; then
        return
    fi

    local cache_file="$PROJECT_ROOT/.sync-update-check"
    local today
    today=$(date +%Y-%m-%d)

    # Skip if already checked today
    if [[ -f "$cache_file" ]] && grep -q "^$today$" "$cache_file" 2>/dev/null; then
        return
    fi

    local latest
    latest=$(curl -sf --max-time 3 "https://api.github.com/repos/dreejt/mintis-sync/tags" 2>/dev/null \
        | grep '"name"' | head -1 | sed 's/.*"name": "\(.*\)".*/\1/' | sed 's/^v//')

    if [[ -z "$latest" ]]; then
        return  # GitHub unreachable, skip silently
    fi

    echo "$today" > "$cache_file"

    # Check if latest > SCRIPT_VERSION using sort -V
    if [[ "$(printf '%s\n' "$SCRIPT_VERSION" "$latest" | sort -V | tail -1)" != "$SCRIPT_VERSION" ]]; then
        warning "mintis-sync $latest is available (you have $SCRIPT_VERSION)"
        info "Update with: composer update dreejt/mintis-sync"
        echo
    fi
}

check_for_updates

# Pre-flight validation checks
validate_requirements() {
    local has_errors=false
    
    # Check if wp-cli is installed
    if ! command -v wp &> /dev/null; then
        error "WP-CLI is not installed"
        info "Install WP-CLI: https://wp-cli.org/#installing"
        has_errors=true
    fi
    
    # Check if rsync is installed
    if ! command -v rsync &> /dev/null; then
        error "rsync is not installed"
        info "Install rsync: brew install rsync (macOS) or apt-get install rsync (Linux)"
        has_errors=true
    fi
    
    # Check required .env variables
    local required_vars=("DEV_DOMAIN" "STAGING_DOMAIN" "PROD_DOMAIN" "SERVER_USER" "SERVER_IP" "SERVER_BASE_PATH")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            error "Required .env variable $var is not set"
            has_errors=true
        fi
    done
    
    # Check if wp-cli.yml exists
    if [ ! -f "$PROJECT_ROOT/wp-cli.yml" ]; then
        warning "wp-cli.yml not found at $PROJECT_ROOT/wp-cli.yml"
        info "Run setup-wp-cli.php to generate it from .env"
    fi
    
    if [ "$has_errors" = true ]; then
        exit 1
    fi
}

validate_requirements

# WP-CLI command helpers (handle local vs remote transparently)
wp_from_cmd() {
    if [[ "$LOCAL" = true && "$FROM" == "development" ]]; then
        wp "$@"
    else
        wp "@$FROM" "$@"
    fi
}

wp_to_cmd() {
    if [[ "$LOCAL" = true && "$TO" == "development" ]]; then
        wp "$@"
    else
        wp "@$TO" "$@"
    fi
}

# Database sync with backup, import, search-replace, and multisite fix
sync_database() {
    # Create timestamped backup of target database
    local backup_dir="$PROJECT_ROOT/backups"
    local backup_file="$backup_dir/${TO}-$(date +%Y%m%d-%H%M%S).sql"
    mkdir -p "$backup_dir"
    info "Backing up $TO database before sync..."
    if wp_to_cmd db export --default-character-set=utf8mb4 - > "$backup_file" 2>/dev/null; then
        if [ -s "$backup_file" ]; then
            success "Backup saved to $backup_file ($(du -h "$backup_file" | cut -f1))"
        else
            rm -f "$backup_file"
            warning "Target database is empty — no backup needed"
        fi
    else
        rm -f "$backup_file"
        error "Backup of $TO database failed — sync aborted"
        info "Fix the backup issue first, or use --skip-db to skip the database sync"
        exit 1
    fi

    # Reset target and import source database
    info "Syncing database..."
    wp_to_cmd db reset --yes
    if ! wp_from_cmd db export --default-character-set=utf8mb4 - | wp_to_cmd db import -; then
        error "Database import failed! Backup available at: $backup_file"
        exit 1
    fi
    success "Database imported"

    # Search-replace URLs
    wp_to_cmd search-replace "$FROMSITE" "$TOSITE" --all-tables-with-prefix
    success "Search-replace completed"

    # Fix multisite domains in wp_blogs and wp_site tables
    local FROMDOM TODOM
    FROMDOM=$(echo "$FROMSITE" | sed -e 's|https\?://||' -e 's|/||g')
    TODOM=$(echo "$TOSITE" | sed -e 's|https\?://||' -e 's|/||g')
    info "Updating multisite domains from $FROMDOM to $TODOM..."
    wp_to_cmd db query "UPDATE wp_blogs SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" 2>/dev/null || true
    wp_to_cmd db query "UPDATE wp_site SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" 2>/dev/null || true
    success "Multisite domains updated"

    # Flush cache
    wp_to_cmd cache flush --url="$TOSITE" 2>/dev/null || true
    success "Cache flushed"
}

# Build URLs and paths from .env
UPLOADS_PATH="/web/app/uploads"

# Environment URLs
DEVSITE="http://${DEV_DOMAIN}"
STAGSITE="https://${STAGING_DOMAIN}"
PRODSITE="https://${PROD_DOMAIN}"

# Environment directories
DEVDIR="web/app/uploads/"
STAGDIR="${SERVER_USER}@${SERVER_IP}:${SERVER_BASE_PATH}/${STAGING_DOMAIN}${UPLOADS_PATH}/"
PRODDIR="${SERVER_USER}@${SERVER_IP}:${SERVER_BASE_PATH}/${PROD_DOMAIN}${UPLOADS_PATH}/"

LOCAL=false
SKIP_DB=false
SKIP_ASSETS=false
DRY_RUN=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-db)
      SKIP_DB=true
      shift
      ;;
    --skip-assets)
      SKIP_ASSETS=true
      shift
      ;;
    --local)
      LOCAL=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}"

if [ $# != 2 ]
then
  echo "Usage: $0 [[--skip-db] [--skip-assets] [--local] [--dry-run]] [ENV_FROM] [ENV_TO]"
exit;
fi

FROM=$1
TO=$2

case "$1-$2" in
  production-development) DIR="down ⬇️ "          FROMSITE=$PRODSITE; FROMDIR=$PRODDIR; TOSITE=$DEVSITE;  TODIR=$DEVDIR; ;;
  staging-development)    DIR="down ⬇️ "          FROMSITE=$STAGSITE; FROMDIR=$STAGDIR; TOSITE=$DEVSITE;  TODIR=$DEVDIR; ;;
  development-production) DIR="up ⬆️ "            FROMSITE=$DEVSITE;  FROMDIR=$DEVDIR;  TOSITE=$PRODSITE; TODIR=$PRODDIR; ;;
  development-staging)    DIR="up ⬆️ "            FROMSITE=$DEVSITE;  FROMDIR=$DEVDIR;  TOSITE=$STAGSITE; TODIR=$STAGDIR; ;;
  production-staging)     DIR="horizontally ↔️ ";  FROMSITE=$PRODSITE; FROMDIR=$PRODDIR; TOSITE=$STAGSITE; TODIR=$STAGDIR; ;;
  staging-production)     DIR="horizontally ↔️ ";  FROMSITE=$STAGSITE; FROMDIR=$STAGDIR; TOSITE=$PRODSITE; TODIR=$PRODDIR; ;;
  *) echo "usage: $0 [[--skip-db] [--skip-assets] [--local] [--dry-run]] production development | staging development | development staging | development production | staging production | production staging" && exit 1 ;;
esac

if [ "$SKIP_DB" = false ]
then
  DB_MESSAGE=" - ${BOLD}reset the $TO database${NORMAL} ($TOSITE)"
fi

if [ "$SKIP_ASSETS" = false ]
then
  ASSETS_MESSAGE=" - sync ${BOLD}$DIR${NORMAL} from $FROM ($FROMSITE)?"
fi

if [ "$SKIP_DB" = true ] && [ "$SKIP_ASSETS" = true ]
then
  echo "Nothing to synchronize."
  exit;
fi

echo
echo "Would you really like to "
echo $DB_MESSAGE
echo $ASSETS_MESSAGE
read -r -p " [y/N] " response < /dev/tty

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  # Extra confirmation when syncing TO production
  if [[ "$TO" == "production" ]]; then
    if [[ -z "$PROD_DOMAIN" ]]; then
      error "PROD_DOMAIN is niet ingesteld in .env — sync naar production geblokkeerd"
      exit 1
    fi
    echo
    echo -e "  ${RED}${BOLD}⛔  WAARSCHUWING: je staat op het punt PRODUCTIE te overschrijven${NORMAL}${NC}"
    echo
    echo -e "  ${BOLD}Van:${NORMAL}  $FROMSITE"
    echo -e "  ${RED}${BOLD}Naar: $TOSITE${NORMAL}${NC}"
    echo
    echo -e "  ${YELLOW}Dit vervangt de live database en uploads. Dit is onomkeerbaar.${NC}"
    echo
    echo -e "  Typ de productie-domeinnaam om te bevestigen: ${BOLD}${PROD_DOMAIN}${NORMAL}"
    read -r -p "  > " confirm_prod < /dev/tty
    if [[ "$confirm_prod" != "$PROD_DOMAIN" ]]; then
      error "Aborted. Domeinnaam kwam niet overeen."
      exit 1
    fi
  fi

  # Dry-run mode
  if [[ "$DRY_RUN" == true ]]; then
    echo
    info "Dry-run mode — no changes will be made"
    echo
    echo "  Would sync:"
    [[ "$SKIP_DB" == false ]] && echo "    - Database: $FROM → $TO (search-replace $FROMSITE → $TOSITE)"
    [[ "$SKIP_ASSETS" == false ]] && echo "    - Assets: $FROMDIR → $TODIR"
    echo
    exit 0
  fi

  # Change to project root directory
  cd "$PROJECT_ROOT" &&
  echo

  # Make sure both environments are available before we continue
  availfrom() {
    local AVAILFROM

    if [[ "$LOCAL" = true && $FROM == "development" ]]; then
      AVAILFROM=$(wp option get home 2>&1) || true
    else
      AVAILFROM=$(wp "@$FROM" option get home 2>&1) || true
    fi
    if [[ $AVAILFROM == *"command not found"* ]]; then
      error "WP-CLI is not installed on the $FROM server"
      info "Install WP-CLI on the remote server: https://wp-cli.org/#installing"
      exit 1
    elif [[ $AVAILFROM == *"Error"* ]]; then
      error "Unable to connect to $FROM"
      info "Troubleshooting tips:"
      echo "  - Check if wp-cli.yml is configured correctly"
      echo "  - Verify SSH access: ssh $SERVER_USER@$SERVER_IP"
      echo "  - Ensure WP-CLI is installed on remote server"
      exit 1
    else
      success "Connected to $FROM"
    fi
  };
  availfrom

  availto() {
    local AVAILTO
    if [[ "$LOCAL" = true && $TO == "development" ]]; then
      AVAILTO=$(wp option get home --url="$TOSITE" 2>&1) || true
    else
      AVAILTO=$(wp "@$TO" option get home 2>&1) || true
    fi

    if [[ $AVAILTO == *"command not found"* ]]; then
      error "WP-CLI is not installed on the $TO server"
      info "Install WP-CLI on the remote server: https://wp-cli.org/#installing"
      exit 1
    elif [[ $AVAILTO == *"Error"* ]]; then
      warning "Unable to fully connect to $TO (this is normal for empty databases)"
      success "Proceeding with sync..."
    else
      success "Connected to $TO"
    fi
  };
  availto

  if [ "$SKIP_DB" = false ]
  then
    sync_database
  fi

  if [ "$SKIP_ASSETS" = false ]
  then
  info "Syncing assets..."
    # Sync uploads directory
    chmod -R 755 web/app/uploads/ &&
    if [[ $DIR == "horizontally"* ]]; then
      [[ $FROMDIR =~ ^(.*): ]] && FROMHOST=${BASH_REMATCH[1]}
      [[ $FROMDIR =~ ^(.*):(.*)$ ]] && FROMDIR=${BASH_REMATCH[2]}
      [[ $TODIR =~ ^(.*): ]] && TOHOST=${BASH_REMATCH[1]}
      [[ $TODIR =~ ^(.*):(.*)$ ]] && TODIR=${BASH_REMATCH[2]}

      ssh -o ForwardAgent=yes $FROMHOST "rsync -aze 'ssh -o StrictHostKeyChecking=no' --progress $FROMDIR $TOHOST:$TODIR" &&
      success "Assets synced"
    else
      rsync -az --progress "$FROMDIR" "$TODIR" &&
      success "Assets synced"
    fi
  fi

  # Slack notification when sync direction is up or horizontal
  # if [[ $DIR != "down"* ]]; then
  #   USER="$(git config user.name)"
  #   curl -X POST -H "Content-type: application/json" --data "{\"attachments\":[{\"fallback\": \"\",\"color\":\"#36a64f\",\"text\":\"🔄 Sync from ${FROMSITE} to ${TOSITE} by ${USER} complete \"}],\"channel\":\"#site\"}" https://hooks.slack.com/services/xx/xx/xx
  # fi
  echo
  success "Sync from $FROM to $TO complete"
  echo
  echo "    ${BOLD}$TOSITE${NORMAL}"
  echo
fi