#!/bin/bash

# Syncing Trellis & Bedrock-based WordPress environments with WP-CLI aliases
# Version 1.3.0
# Copyright (c) Ben Word | modification by Tjeerd

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

# Spinner for long-running operations
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " ${BLUE}[%c]${NC}  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
  echo "Usage: $0 [[--skip-db] [--skip-assets] [--local]] [ENV_FROM] [ENV_TO]"
exit;
fi

FROM=$1
TO=$2

bold=$(tput bold)
normal=$(tput sgr0)

case "$1-$2" in
  production-development) DIR="down ⬇️ "          FROMSITE=$PRODSITE; FROMDIR=$PRODDIR; TOSITE=$DEVSITE;  TODIR=$DEVDIR; ;;
  staging-development)    DIR="down ⬇️ "          FROMSITE=$STAGSITE; FROMDIR=$STAGDIR; TOSITE=$DEVSITE;  TODIR=$DEVDIR; ;;
  development-production) DIR="up ⬆️ "            FROMSITE=$DEVSITE;  FROMDIR=$DEVDIR;  TOSITE=$PRODSITE; TODIR=$PRODDIR; ;;
  development-staging)    DIR="up ⬆️ "            FROMSITE=$DEVSITE;  FROMDIR=$DEVDIR;  TOSITE=$STAGSITE; TODIR=$STAGDIR; ;;
  production-staging)     DIR="horizontally ↔️ ";  FROMSITE=$PRODSITE; FROMDIR=$PRODDIR; TOSITE=$STAGSITE; TODIR=$STAGDIR; ;;
  staging-production)     DIR="horizontally ↔️ ";  FROMSITE=$STAGSITE; FROMDIR=$STAGDIR; TOSITE=$PRODSITE; TODIR=$PRODDIR; ;;
  *) echo "usage: $0 [[--skip-db] [--skip-assets] [--local]] production development | staging development | development staging | development production | staging production | production staging" && exit 1 ;;
esac

if [ "$SKIP_DB" = false ]
then
  DB_MESSAGE=" - ${bold}reset the $TO database${normal} ($TOSITE)"
fi

if [ "$SKIP_ASSETS" = false ]
then
  ASSETS_MESSAGE=" - sync ${bold}$DIR${normal} from $FROM ($FROMSITE)?"
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
read -r -p " [y/N] " response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  # Change to project root directory
  cd "$PROJECT_ROOT" &&
  echo

  # Make sure both environments are available before we continue
  availfrom() {
    local AVAILFROM

    if [[ "$LOCAL" = true && $FROM == "development" ]]; then
      AVAILFROM=$(wp option get home 2>&1)
    else
      AVAILFROM=$(wp "@$FROM" option get home 2>&1)
    fi
    if [[ $AVAILFROM == *"Error"* ]]; then
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
      AVAILTO=$(wp option get home --url="$TOSITE" 2>&1)
    else
      AVAILTO=$(wp "@$TO" option get home 2>&1)
    fi

    if [[ $AVAILTO == *"Error"* ]]; then
      warning "Unable to fully connect to $TO (this is normal for empty databases)"
      success "Proceeding with sync..."
    else
      success "Connected to $TO"
    fi
  };
  availto

  if [ "$SKIP_DB" = false ]
  then
  info "Syncing database..."
    # Export/import database, run search & replace
    if [[ "$LOCAL" = true && $TO == "development" ]]; then
      wp db export --default-character-set=utf8mb4 &&
      wp db reset --yes &&
      wp "@$FROM" db export --default-character-set=utf8mb4 - | wp db import - &&
      success "Database imported" &&
      wp search-replace "$FROMSITE" "$TOSITE" --all-tables-with-prefix &&
      success "Search-replace completed" &&
      # Fix multisite domains in wp_blogs and wp_site tables
      FROMDOM=$(echo "$FROMSITE" | sed -e 's|https\?://||' -e 's|/||g') &&
      TODOM=$(echo "$TOSITE" | sed -e 's|https\?://||' -e 's|/||g') &&
      info "Updating multisite domains from $FROMDOM to $TODOM..." &&
      wp db query "UPDATE wp_blogs SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" 2>/dev/null &&
      wp db query "UPDATE wp_site SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" 2>/dev/null &&
      success "Multisite domains updated" &&
      wp cache flush --url="$TOSITE" 2>/dev/null &&
      success "Cache flushed"
    elif [[ "$LOCAL" = true && $FROM == "development" ]]; then
      wp "@$TO" db export --default-character-set=utf8mb4 &&
      wp "@$TO" db reset --yes &&
      wp db export --default-character-set=utf8mb4 - | wp "@$TO" db import - &&
      success "Database imported" &&
      wp "@$TO" search-replace "$FROMSITE" "$TOSITE" --all-tables-with-prefix &&
      success "Search-replace completed" &&
      # Fix multisite domains in wp_blogs and wp_site tables
      FROMDOM=$(echo "$FROMSITE" | sed -e 's|https\?://||' -e 's|/||g') &&
      TODOM=$(echo "$TOSITE" | sed -e 's|https\?://||' -e 's|/||g') &&
      info "Updating multisite domains from $FROMDOM to $TODOM..." &&
      wp "@$TO" db query "UPDATE wp_blogs SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" 2>/dev/null &&
      wp "@$TO" db query "UPDATE wp_site SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" 2>/dev/null &&
      success "Multisite domains updated" &&
      wp "@$TO" cache flush --url="$TOSITE" 2>/dev/null &&
      success "Cache flushed"
    else
      wp "@$TO" db export --default-character-set=utf8mb4 &&
      wp "@$TO" db reset --yes &&
      wp "@$FROM" db export --default-character-set=utf8mb4 - | wp "@$TO" db import - &&
      success "Database imported" &&
      wp "@$TO" search-replace "$FROMSITE" "$TOSITE" --all-tables-with-prefix &&
      success "Search-replace completed" &&
      # Fix multisite domains in wp_blogs and wp_site tables
      FROMDOM=$(echo "$FROMSITE" | sed -e 's|https\?://||' -e 's|/||g') &&
      TODOM=$(echo "$TOSITE" | sed -e 's|https\?://||' -e 's|/||g') &&
      info "Updating multisite domains from $FROMDOM to $TODOM..." &&
      wp "@$TO" db query "UPDATE wp_blogs SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" 2>/dev/null &&
      wp "@$TO" db query "UPDATE wp_site SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" 2>/dev/null &&
      success "Multisite domains updated" &&
      wp "@$TO" cache flush --url="$TOSITE" 2>/dev/null &&
      success "Cache flushed"
    fi
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