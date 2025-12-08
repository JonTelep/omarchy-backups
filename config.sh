#!/usr/bin/env bash
# Backup Configuration for Omarchy Linux
# This file defines what directories to backup from ~/.config/

# ============================================
# CONFIG DIRECTORIES (from ~/.config/)
# ============================================

CONFIG_DIRS=(
    "hypr"
    "ghostty"
    "waybar"
)

# ============================================
# CONFIG FILES (individual files from ~/.config/)
# ============================================

CONFIG_FILES=(
    "starship.toml"
)

# ============================================
# SCRIPT DIRECTORIES (from ~/Projects/)
# ============================================

SCRIPT_DIRS=(
    "scripts"
)

# ============================================
# HOME FILES (individual files from ~/)
# ============================================

HOME_FILES=(
    ".bashrc"
)

# ============================================
# BACKUP OPTIONS
# ============================================

# Backup script behavior
DRY_RUN=false              # Set via --dry-run flag
VERBOSE=false              # Set via --verbose flag
QUIET=false                # Set via --quiet flag

# ============================================
# PATHS (automatically set by backup.sh)
# ============================================
# These variables are set in backup.sh and should not be modified here:
#   BACKUP_ROOT      - Set to script directory
#   CONFIG_SOURCE    - Source: ${HOME}/.config
#   CONFIG_DEST      - Destination: ${BACKUP_ROOT}/config
#   SCRIPTS_SOURCE   - Source: ${HOME}/Projects
#   SCRIPTS_DEST     - Destination: ${BACKUP_ROOT}
#   HOME_SOURCE      - Source: ${HOME}
#   HOME_DEST        - Destination: ${BACKUP_ROOT}/home
