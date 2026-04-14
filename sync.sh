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
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color
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

# Show help and available sync directions
show_help() {
    cat << EOF
${BOLD}Mintis Sync${NORMAL} v${SCRIPT_VERSION}
Sync database and uploads between Bedrock WordPress environments.

${BOLD}USAGE${NORMAL}
  sync.sh [OPTIONS] <FROM> <TO>
  composer sync <FROM> <TO> [-- OPTIONS]

${BOLD}ENVIRONMENTS${NORMAL}
  production      Production environment
  staging         Staging environment
  development     Development environment (local)

${BOLD}AVAILABLE SYNC DIRECTIONS${NORMAL}
  ${GREEN}production development${NC}    ⬇️  Veilig  (pull from production to local)
  ${GREEN}staging development${NC}       ⬇️  Veilig  (pull from staging to local)
  ${GREEN}development staging${NC}       ⬆️  Veilig  (push from local to staging)
  ${YELLOW}development production${NC}    ⬆️  ⚠️  Vereist bevestiging (push to production!)
  ${GREEN}production staging${NC}        ↔️  Veilig  (sync production to staging)
  ${YELLOW}staging production${NC}        ↔️  ⚠️  Vereist bevestiging (overwrite production!)

${BOLD}OPTIONS${NORMAL}
  --skip-db         Skip database sync (only sync uploads)
  --skip-assets     Skip uploads sync (only sync database)
  --dry-run         Preview changes without executing
  --local           Use local rsync (no remote copy)
  --help, -h        Show this help message

${BOLD}EXAMPLES${NORMAL}
  # Pull production database and uploads to local
  composer sync production development

  # Push local changes to staging
  composer sync development staging

  # Pull production database only (skip uploads)
  composer sync production development -- --skip-assets

  # Preview what would happen
  composer sync staging development -- --dry-run

  # Sync production to staging (e.g., after hotfix)
  composer sync production staging

${BOLD}COMPOSER SHORTCUTS${NORMAL}
  composer sync:production-development
  composer sync:staging-development
  composer sync:development-staging
  composer sync:development-production
  composer sync:production-staging
  composer sync:staging-production

${BOLD}VEREISTEN${NORMAL}
  - WP-CLI (local + remote)
  - rsync
  - SSH access to servers
  - Configured .env file

For more info: https://github.com/Dreejt/mintis-sync
EOF
    exit 0
}

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

# Maintenance mode helpers
activate_maintenance_mode() {
    wp_to_cmd maintenance-mode activate --skip-plugins --skip-themes 2>/dev/null && \
        success "Maintenance mode geactiveerd op $TO" || \
        warning "Maintenance mode kon niet worden geactiveerd op $TO — sync gaat door"
}

deactivate_maintenance_mode() {
    wp_to_cmd maintenance-mode deactivate --skip-plugins --skip-themes 2>/dev/null && \
        success "Maintenance mode gedeactiveerd op $TO" || \
        warning "Maintenance mode kon niet worden gedeactiveerd op $TO — controleer handmatig"
}

# Plugin management: activate/deactivate plugins gebaseerd op de doelomgeving
# Configureer via .sync: PLUGINS_ACTIVATE_ON_PRODUCTION=("updraftplus") etc.
# Niet-bestaande plugins worden overgeslagen — nooit fataal
manage_plugins() {
    local env_upper
    env_upper=$(echo "$TO" | tr '[:lower:]' '[:upper:]')
    local activate_ref="PLUGINS_ACTIVATE_ON_${env_upper}[@]"
    local deactivate_ref="PLUGINS_DEACTIVATE_ON_${env_upper}[@]"
    local plugins_activate=("${!activate_ref}")
    local plugins_deactivate=("${!deactivate_ref}")

    if [[ ${#plugins_activate[@]} -eq 0 && ${#plugins_deactivate[@]} -eq 0 ]]; then
        return 0
    fi

    # Haal lijst van geïnstalleerde plugins op — niet fataal als het mislukt
    local installed_plugins
    installed_plugins=$(wp_to_cmd plugin list --field=name --skip-plugins --skip-themes 2>/dev/null) || true

    if [[ -z "$installed_plugins" ]]; then
        warning "Kon plugin-lijst niet ophalen van $TO — plugin management overgeslagen"
        return 0
    fi

    for plugin in "${plugins_activate[@]}"; do
        if echo "$installed_plugins" | grep -qx "$plugin"; then
            wp_to_cmd plugin activate "$plugin" --skip-plugins --skip-themes 2>/dev/null && \
                success "Plugin geactiveerd: $plugin" || \
                warning "Plugin activeren mislukt: $plugin"
        else
            warning "Plugin niet gevonden op $TO, overgeslagen: $plugin"
        fi
    done

    for plugin in "${plugins_deactivate[@]}"; do
        if echo "$installed_plugins" | grep -qx "$plugin"; then
            wp_to_cmd plugin deactivate "$plugin" --skip-plugins --skip-themes 2>/dev/null && \
                success "Plugin gedeactiveerd: $plugin" || \
                warning "Plugin deactiveren mislukt: $plugin"
        else
            warning "Plugin niet gevonden op $TO, overgeslagen: $plugin"
        fi
    done
}

# Database sync with backup, import, search-replace, and multisite fix
sync_database() {
    # Create timestamped backup of target database
    local timestamp
    timestamp=$(date +%Y-%m-%d_%H%M%S)
    local backup_dir="$PROJECT_ROOT/backups"
    local backup_file="$backup_dir/${TO}-backup-${timestamp}.sql"
    mkdir -p "$backup_dir"
    info "Lokale backup maken van ${TO}-database..."
    if wp_to_cmd db export --default-character-set=utf8mb4 - > "$backup_file" 2>/dev/null; then
        if [ -s "$backup_file" ]; then
            success "Lokale backup opgeslagen: $backup_file ($(du -h "$backup_file" | cut -f1))"
        else
            rm -f "$backup_file"
            warning "${TO}-database is leeg — geen backup nodig"
        fi
    else
        rm -f "$backup_file"
        error "Lokale backup van ${TO}-database mislukt — sync afgebroken"
        info "Los het backup-probleem op, of gebruik --skip-db om de database over te slaan"
        exit 1
    fi

    # Also create a remote backup on the target server itself
    if [[ "$TO" == "staging" || "$TO" == "production" ]]; then
        local to_domain
        [[ "$TO" == "staging" ]] && to_domain="$STAGING_DOMAIN" || to_domain="$PROD_DOMAIN"
        local remote_backup_dir="${SERVER_BASE_PATH}/${to_domain}/backups"
        local remote_backup_file="${remote_backup_dir}/${TO}-backup-${timestamp}.sql"
        info "Remote backup maken op de ${TO}-server (${to_domain})..."
        if ssh "${SERVER_USER}@${SERVER_IP}" "mkdir -p '${remote_backup_dir}'" 2>/dev/null && \
           wp "@${TO}" db export "${remote_backup_file}" 2>/dev/null; then
            success "Remote backup opgeslagen op ${TO}-server: ${remote_backup_file}"
        else
            error "Remote backup op ${TO}-server (${to_domain}) mislukt — sync afgebroken"
            info "Controleer schrijfrechten op: ${remote_backup_dir}"
            info "Of gebruik --skip-db om de database-sync over te slaan"
            exit 1
        fi
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
    # --url=$FROMSITE: WP-CLI weet dat de DB nog dev-URLs heeft na import
    # --skip-plugins --skip-themes: voorkomt dat plugin/theme-code de bootstrap breekt
    wp_to_cmd search-replace "$FROMSITE" "$TOSITE" --all-tables-with-prefix --url="$FROMSITE" --skip-plugins --skip-themes
    success "Search-replace completed"

    # Fix multisite domains in wp_blogs and wp_site tables (alleen bij multisite)
    local FROMDOM TODOM
    FROMDOM=$(echo "$FROMSITE" | sed -e 's|https\?://||' -e 's|/||g')
    TODOM=$(echo "$TOSITE" | sed -e 's|https\?://||' -e 's|/||g')
    if wp_to_cmd db tables --url="$TOSITE" --skip-plugins --skip-themes 2>/dev/null | grep -q 'wp_blogs'; then
        info "Multisite gedetecteerd — updating domains from $FROMDOM to $TODOM..."
        wp_to_cmd db query "UPDATE wp_blogs SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" --skip-plugins --skip-themes 2>/dev/null || true
        wp_to_cmd db query "UPDATE wp_site SET domain = '$TODOM' WHERE domain = '$FROMDOM';" --url="$TOSITE" --skip-plugins --skip-themes 2>/dev/null || true
        success "Multisite domains updated"
    fi

    # Flush cache
    wp_to_cmd cache flush --url="$TOSITE" --skip-plugins --skip-themes 2>/dev/null || true
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
COMMAND_ONLY=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h|help)
      show_help
      ;;
    list)
      show_help
      ;;
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
    --command-only)
      COMMAND_ONLY=true
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
  show_help
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
  *) echo "usage: $0 [[--skip-db] [--skip-assets] [--local] [--dry-run] [--command-only]] production development | staging development | development staging | development production | staging production | production staging" && exit 1 ;;
esac

# Plugin management arrays voor de doelomgeving (geladen vanuit .sync config)
_PM_ENV=$(echo "$TO" | tr '[:lower:]' '[:upper:]')
_PM_AREF="PLUGINS_ACTIVATE_ON_${_PM_ENV}[@]"
_PM_DREF="PLUGINS_DEACTIVATE_ON_${_PM_ENV}[@]"
_PM_ACTIVATE=("${!_PM_AREF}")
_PM_DEACTIVATE=("${!_PM_DREF}")

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

# Command-only mode: toon commando's en exit zonder bevestigingsprompt
if [[ "$COMMAND_ONLY" == true ]]; then
  echo
  info "Command-only mode — this would execute:"
  echo
  if [[ "$SKIP_DB" == false ]]; then
    echo "  ${BOLD}[DB Backup & Sync]${NORMAL}"
    echo "    wp @${TO} maintenance-mode activate --skip-plugins --skip-themes"
    echo "    wp @${TO} db export --default-character-set=utf8mb4 - > backups/${TO}-\$(date +%Y%m%d-%H%M%S).sql"
    echo "    wp @${TO} db reset --yes"
    echo "    wp @${FROM} db export --default-character-set=utf8mb4 - | wp @${TO} db import -"
    echo "    wp @${TO} search-replace \"${FROMSITE}\" \"${TOSITE}\" --all-tables-with-prefix --url=\"${FROMSITE}\" --skip-plugins --skip-themes"
    echo "    wp @${TO} cache flush --url=\"${TOSITE}\" --skip-plugins --skip-themes"
    echo "    wp @${TO} maintenance-mode deactivate --skip-plugins --skip-themes"
    echo
  fi
  if [[ "$SKIP_ASSETS" == false ]]; then
    echo "  ${BOLD}[Assets Sync]${NORMAL}"
    if [[ $DIR == "horizontally"* ]]; then
      _CO_FROMHOST="${FROMDIR%%:*}"
      _CO_FROMPATH="${FROMDIR#*:}"
      _CO_TOHOST="${TODIR%%:*}"
      _CO_TOPATH="${TODIR#*:}"
      if [[ "$_CO_FROMHOST" == "$_CO_TOHOST" ]]; then
        echo "    ssh $_CO_FROMHOST \"rsync -a --progress $_CO_FROMPATH $_CO_TOPATH\""
      else
        echo "    ssh -o ForwardAgent=yes $_CO_FROMHOST \"rsync -aze 'ssh -o StrictHostKeyChecking=no' --progress $_CO_FROMPATH $_CO_TOHOST:$_CO_TOPATH\""
      fi
    else
      echo "    rsync -az --progress \"${FROMDIR}\" \"${TODIR}\""
    fi
    echo
  fi
  if [[ ${#_PM_ACTIVATE[@]} -gt 0 || ${#_PM_DEACTIVATE[@]} -gt 0 ]]; then
    echo "  ${BOLD}[Plugin Management op ${TO}]${NORMAL}"
    for _p in "${_PM_ACTIVATE[@]}"; do
      echo "    wp @${TO} plugin activate $_p --skip-plugins --skip-themes"
    done
    for _p in "${_PM_DEACTIVATE[@]}"; do
      echo "    wp @${TO} plugin deactivate $_p --skip-plugins --skip-themes"
    done
    echo
  fi
  echo "  ${BOLD}[Post-sync checks]${NORMAL}"
  echo "    wp @${TO} option get blogname --skip-plugins --skip-themes"
  echo "    wp @${TO} core verify-checksums --skip-plugins --skip-themes"
  echo "    curl --silent --head --max-time 10 \"${TOSITE}\""
  echo
  exit 0
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

  # Stappen en statusvariabelen bijhouden
  _DB_DONE=false
  _ASSETS_DONE=false
  _MAINT_ACTIVE=false
  TOTAL_STEPS=4  # connect + maint-on + maint-off + post-sync checks
  [[ "$SKIP_DB" == false ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [[ "$SKIP_ASSETS" == false ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  [[ ${#_PM_ACTIVATE[@]} -gt 0 || ${#_PM_DEACTIVATE[@]} -gt 0 ]] && TOTAL_STEPS=$((TOTAL_STEPS + 1))
  _STEP=0
  step() { _STEP=$((_STEP + 1)); info "[${_STEP}/${TOTAL_STEPS}] $1"; }

  # Bij onverwachte crash: toon wat er nog niet gedaan is en deactiveer maintenance
  trap '
    echo
    error "Sync werd onderbroken!"
    [[ "$_DB_DONE" == false && "$SKIP_DB" == false ]] && warning "Database is mogelijk niet volledig gesynchroniseerd"
    [[ "$_ASSETS_DONE" == false && "$SKIP_ASSETS" == false ]] && warning "Assets (uploads) zijn NIET gesynchroniseerd — voer opnieuw uit met: composer sync $FROM $TO -- --skip-db"
    if [[ "$_MAINT_ACTIVE" == true ]]; then
      warning "Maintenance mode deactiveren na fout..."
      wp_to_cmd maintenance-mode deactivate --skip-plugins --skip-themes 2>/dev/null || true
    fi
    echo
  ' ERR

  # Make sure both environments are available before we continue
  step "Verbinding controleren ($FROM → $TO)..."
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

  step "Maintenance mode activeren op $TO..."
  activate_maintenance_mode
  _MAINT_ACTIVE=true

  if [ "$SKIP_DB" = false ]
  then
    step "Database synchroniseren ($FROM → $TO)..."
    sync_database
    _DB_DONE=true
  fi

  if [ "$SKIP_ASSETS" = false ]
  then
    step "Assets synchroniseren ($FROM → $TO)..."
    # Verwijder .DS_Store bestanden vóór rsync (macOS artefacten horen niet op server)
    find "${PROJECT_ROOT}/web/app/uploads/" -name ".DS_Store" -delete 2>/dev/null || true
    # Sync uploads directory
    chmod -R 755 web/app/uploads/ &&
    if [[ $DIR == "horizontally"* ]]; then
      [[ $FROMDIR =~ ^(.*): ]] && FROMHOST=${BASH_REMATCH[1]}
      [[ $FROMDIR =~ ^(.*):(.*)$ ]] && FROMDIR=${BASH_REMATCH[2]}
      [[ $TODIR =~ ^(.*): ]] && TOHOST=${BASH_REMATCH[1]}
      [[ $TODIR =~ ^(.*):(.*)$ ]] && TODIR=${BASH_REMATCH[2]}

      if [[ "$FROMHOST" == "$TOHOST" ]]; then
        # Zelfde server: lokale rsync, geen SSH-naar-zichzelf nodig
        ssh $FROMHOST "rsync -a --progress $FROMDIR $TODIR" &&
        success "Assets synced (same server, local copy)"
      else
        # Verschillende servers: rsync via SSH met agent forwarding
        ssh -o ForwardAgent=yes $FROMHOST "rsync -aze 'ssh -o StrictHostKeyChecking=no' --progress $FROMDIR $TOHOST:$TODIR" &&
        success "Assets synced"
      fi
    else
      rsync -az --progress "$FROMDIR" "$TODIR" &&
      success "Assets synced"
    fi
    _ASSETS_DONE=true
  fi

  # Plugin management: plugins activeren/deactiveren op de doelomgeving
  if [[ ${#_PM_ACTIVATE[@]} -gt 0 || ${#_PM_DEACTIVATE[@]} -gt 0 ]]; then
    step "Plugin management op $TO..."
    manage_plugins
  fi

  trap - ERR

  step "Maintenance mode deactiveren op $TO..."
  deactivate_maintenance_mode
  _MAINT_ACTIVE=false

  # Slack notification when sync direction is up or horizontal
  # if [[ $DIR != "down"* ]]; then
  #   USER="$(git config user.name)"
  #   curl -X POST -H "Content-type: application/json" --data "{\"attachments\":[{\"fallback\": \"\",\"color\":\"#36a64f\",\"text\":\"🔄 Sync from ${FROMSITE} to ${TOSITE} by ${USER} complete \"}],\"channel\":\"#site\"}" https://hooks.slack.com/services/xx/xx/xx
  # fi

  step "Post-sync controles ($TO)..."
  echo

  # WordPress health check via WP-CLI
  info "WordPress bereikbaarheid controleren..."
  _health_output=$(wp_to_cmd option get blogname --skip-plugins --skip-themes 2>&1) || true
  if echo "$_health_output" | grep -qi "autoloader\|composer install"; then
    warning "Site geeft 'autoloader' fout — composer install is nodig op de server"
    info "Voer dit uit om de site te herstellen:"
    echo
    if [[ "$TO" == "staging" ]]; then
      echo "  ssh ${SERVER_USER}@${SERVER_IP} 'cd ${SERVER_BASE_PATH}/${STAGING_DOMAIN} && composer install --no-dev --optimize-autoloader'"
    elif [[ "$TO" == "production" ]]; then
      echo "  ssh ${SERVER_USER}@${SERVER_IP} 'cd ${SERVER_BASE_PATH}/${PROD_DOMAIN} && composer install --no-dev --optimize-autoloader'"
    fi
    echo
  elif echo "$_health_output" | grep -qi "error\|command not found"; then
    warning "Site reageert niet zoals verwacht na sync — controleer handmatig: $TOSITE"
  else
    success "WordPress reageert correct op $TO"
  fi

  # WordPress core bestandsintegriteit controleren
  info "WordPress core bestandsintegriteit controleren..."
  _checksums_output=$(wp_to_cmd core verify-checksums --skip-plugins --skip-themes 2>&1) || true
  if echo "$_checksums_output" | grep -qi "Error\|failed\|invalid\|doesn't verify"; then
    warning "Core bestandsintegriteit kon niet worden geverifieerd — controleer handmatig"
  else
    success "WordPress core bestanden zijn intact"
  fi

  # HTTP bereikbaarheidscheck
  if command -v curl &>/dev/null; then
    info "HTTP bereikbaarheid controleren..."
    _http_status=$(curl --silent --head --max-time 10 "$TOSITE" 2>/dev/null | grep -i "^HTTP" | tail -1) || true
    if echo "$_http_status" | grep -qE "^HTTP.* (200|301|302)"; then
      success "Site is bereikbaar: $_http_status"
    elif [[ -n "$_http_status" ]]; then
      warning "Site geeft onverwachte HTTP status: $_http_status"
    else
      warning "Site niet bereikbaar via HTTP — controleer handmatig: $TOSITE"
    fi
  fi

  echo
  success "Sync from $FROM to $TO complete"
  echo
  echo "    ${BOLD}$TOSITE${NORMAL}"
  echo
fi