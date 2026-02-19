#!/bin/bash
# Common utilities for claude-config-sync

# Get the script root directory
CS_ROOT="${CS_ROOT:-$HOME/claude-config-sync}"

# Export key paths
export CS_ROOT
export CS_CLAUDE_DIR="$HOME/.claude"
export CS_LIB_DIR="$CS_ROOT/lib"
export CS_BIN_DIR="$CS_ROOT/bin"
export CS_CONFIG_DIR="$CS_ROOT/config"
export CS_CONTENT_DIR="$CS_ROOT/content"
export CS_LOG_DIR="$CS_ROOT/logs"

# Colors for output
export CS_COLOR_RED='\033[0;31m'
export CS_COLOR_GREEN='\033[0;32m'
export CS_COLOR_YELLOW='\033[1;33m'
export CS_COLOR_BLUE='\033[0;34m'
export CS_COLOR_GRAY='\033[0;90m'
export CS_COLOR_RESET='\033[0m'

# Detect shell config file
cs_detect_shell_rc() {
    if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        echo "$HOME/.zshrc"
    else
        echo "$HOME/.bashrc"
    fi
}

# Log file
export CS_LOG_FILE="$CS_LOG_DIR/sync.log"

# Slack config
export CS_SLACK_CONFIG="$CS_ROOT/.slack-config"

# Logging functions
cs_log() {
    local level="$1"
    shift
    local msg="*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$CS_LOG_FILE" 2>/dev/null
}

cs_info() {
    echo -e "${CS_COLOR_BLUE}ℹ${CS_COLOR_RESET} $*"
    cs_log "INFO" "$*"
}

cs_success() {
    echo -e "${CS_COLOR_GREEN}✓${CS_COLOR_RESET} $*"
    cs_log "SUCCESS" "$*"
}

cs_warn() {
    echo -e "${CS_COLOR_YELLOW}⚠${CS_COLOR_RESET} $*" >&2
    cs_log "WARN" "$*"
}

cs_error() {
    echo -e "${CS_COLOR_RED}✗${CS_COLOR_RESET} $*" >&2
    cs_log "ERROR" "$*"
}

cs_step() {
    echo -e "\n${CS_COLOR_BLUE}▶${CS_COLOR_RESET} $*"
}

# Load Slack webhook config if exists
cs_load_slack_config() {
    if [[ -f "$CS_SLACK_CONFIG" ]]; then
        source "$CS_SLACK_CONFIG"
    fi
}

# Send notification to Slack
cs_slack_notify() {
    local message="$1"
    local color="${2:-#36a64f}"  # Default green

    # Only send if webhook is configured
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        return 0
    fi

    curl -s -X POST "$SLACK_WEBHOOK_URL" \
        -H 'Content-Type: application/json' \
        -d "{
            \"attachments\": [{
                \"color\": \"$color\",
                \"title\": \"Claude Config Sync\",
                \"text\": \"$message\",
                \"footer\": \"$(hostname)\",
                \"ts\": $(date +%s)
            }]
        }" >> "$CS_LOG_FILE" 2>&1
}

# Ensure log directory exists
cs_ensure_logs() {
    mkdir -p "$CS_LOG_DIR"
}

# Change to sync directory
cs_cd_root() {
    cd "$CS_ROOT" || exit 1
}

# Check if running in the correct directory
cs_check_root() {
    if [[ ! -d "$CS_ROOT" ]]; then
        cs_error "Sync directory not found: $CS_ROOT"
        cs_error "Please ensure the repository is cloned to $CS_ROOT"
        exit 1
    fi
}

# Check if git repo is initialized
cs_check_git() {
    if [[ ! -d "$CS_ROOT/.git" ]]; then
        cs_error "Git repository not initialized"
        cs_error "Run: cd $CS_ROOT && git init"
        exit 1
    fi
}

# Check if jq is available
cs_check_jq() {
    if ! command -v jq &>/dev/null; then
        cs_warn "jq not found. Some features may not work."
        cs_warn "Install with: apt install jq  # Debian/Ubuntu"
        cs_warn "               brew install jq  # macOS"
        return 1
    fi
    return 0
}

# Lock file management
export CS_LOCK_FILE="$CS_ROOT/.sync.lock"

# Acquire lock file
cs_acquire_lock() {
    if [[ -f "$CS_LOCK_FILE" ]]; then
        # Check if lock is stale (older than 1 hour)
        local lock_age
        lock_age=$(($(date +%s) - $(stat -c %Y "$CS_LOCK_FILE" 2>/dev/null || echo "0")))

        if [[ $lock_age -gt 3600 ]]; then
            cs_warn "Removing stale lock file (older than 1 hour)"
            rm -f "$CS_LOCK_FILE"
        else
            cs_error "Sync already in progress"
            cs_error "If this is incorrect, remove: $CS_LOCK_FILE"
            return 1
        fi
    fi

    # Create lock file with PID
    echo $$ > "$CS_LOCK_FILE"
    return 0
}

# Release lock file
cs_release_lock() {
    rm -f "$CS_LOCK_FILE" 2>/dev/null || true
}

# Validate path to prevent directory traversal
cs_validate_path() {
    local path="$1"
    local name="${2:-path}"

    # Check for directory traversal
    if [[ "$path" == *".."* ]] || [[ "$path" == *"/"*"*" ]]; then
        cs_error "Invalid $name: contains dangerous characters"
        return 1
    fi

    # Check if path is absolute (for security)
    if [[ ! "$path" =~ ^/ ]] && [[ ! "$path" =~ ^~ ]]; then
        cs_error "Invalid $name: must be absolute path"
        return 1
    fi

    return 0
}
