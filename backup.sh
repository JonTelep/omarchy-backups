#!/usr/bin/env bash
#
# Omarchy Linux Config Backup & Restore Script
# Backs up configuration directories from ~/.config/ to a Git repository
# Restores configuration files from repository back to ~/.config/
#
# Usage:
#   ./backup.sh                    # Run backup
#   ./backup.sh --restore          # Restore configs from backup
#   ./backup.sh --restore --dry-run  # Preview what would be restored
#   ./backup.sh --dry-run          # Preview what would be backed up
#   ./backup.sh --verbose          # Show detailed output
#   ./backup.sh --quiet            # Minimal output

set -euo pipefail

# ============================================
# CONFIGURATION
# ============================================

BACKUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="1.0.0"

# Source configuration file
if [[ ! -f "${BACKUP_ROOT}/config.sh" ]]; then
    echo "Error: config.sh not found in ${BACKUP_ROOT}"
    exit 1
fi

source "${BACKUP_ROOT}/config.sh"

# Set paths
CONFIG_SOURCE="${HOME}/.config"
CONFIG_DEST="${BACKUP_ROOT}/config"
SCRIPTS_SOURCE="${HOME}/Projects"
SCRIPTS_DEST="${BACKUP_ROOT}"

# Counters for summary
TOTAL_DIRS_COPIED=0
TOTAL_FILES_COPIED=0
TOTAL_SCRIPT_DIRS_COPIED=0

# ============================================
# HELPER FUNCTIONS
# ============================================

print_header() {
    echo -e "\n==> $1"
}

print_info() {
    if [[ "${QUIET}" != "true" ]]; then
        echo "  $1"
    fi
}

print_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "    [verbose] $1"
    fi
}

print_success() {
    echo -e "✓ $1"
}

print_error() {
    echo -e "✗ Error: $1" >&2
}

# List all files that would be backed up from source to destination
# Usage: list_files_to_backup <source_path> <dest_path> <item_name>
list_files_to_backup() {
    local source="$1"
    local dest="$2"
    local name="$3"

    echo ""
    echo "  Files in ${name}:"

    if [[ -d "${source}" ]]; then
        # For directories, list all files recursively
        find "${source}" -type f -printf '    - %P\n' | sort

        # Also show a simple file count
        local file_count=$(find "${source}" -type f | wc -l)
        echo "    Total: ${file_count} files"
    else
        # For single files, just show the file
        echo "    - $(basename "${source}")"
    fi
}

# ============================================
# PREREQUISITE CHECKS
# ============================================

check_prerequisites() {
    print_header "Checking prerequisites"

    local missing=()

    if ! command -v rsync &> /dev/null; then
        missing+=("rsync")
    fi

    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required commands: ${missing[*]}"
        echo "Install them with: sudo pacman -S ${missing[*]}"
        exit 1
    fi

    if [[ ! -d "${CONFIG_SOURCE}" ]]; then
        print_error "Config directory not found: ${CONFIG_SOURCE}"
        exit 1
    fi

    print_success "All prerequisites met"
}

# ============================================
# DIRECTORY SETUP
# ============================================

create_directories() {
    print_header "Creating directory structure"

    if [[ "${DRY_RUN}" == "true" ]]; then
        print_verbose "Would create: ${CONFIG_DEST}"
    else
        mkdir -p "${CONFIG_DEST}"
        print_verbose "Created: ${CONFIG_DEST}"
    fi

    print_info "Directory structure ready"
}

# ============================================
# BACKUP CONFIG DIRECTORIES
# ============================================

backup_config_dirs() {
    print_header "Backing up ~/.config/ directories"

    local copied=0
    local skipped=0

    for config_item in "${CONFIG_DIRS[@]}"; do
        local source_path="${CONFIG_SOURCE}/${config_item}"
        local dest_path="${CONFIG_DEST}/${config_item}"

        if [[ ! -e "${source_path}" ]]; then
            print_verbose "Skipped (not found): ${config_item}"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ "${DRY_RUN}" == "true" ]]; then
            # List all files that will be backed up
            list_files_to_backup "${source_path}" "${dest_path}" "${config_item}"
            copied=$((copied + 1))
        else
            # Use rsync to copy directory
            if [[ -d "${source_path}" ]]; then
                rsync -a --delete "${source_path}/" "${dest_path}/"
                print_verbose "Copied: ${config_item}"
                TOTAL_DIRS_COPIED=$((TOTAL_DIRS_COPIED + 1))
            else
                # It's a file, not a directory
                rsync -a "${source_path}" "${dest_path}"
                print_verbose "Copied: ${config_item}"
            fi

            copied=$((copied + 1))
        fi
    done

    print_info "Directories: ${copied} copied, ${skipped} skipped"
}

# ============================================
# BACKUP CONFIG FILES
# ============================================

backup_config_files() {
    print_header "Backing up ~/.config/ files"

    local copied=0
    local skipped=0

    for config_file in "${CONFIG_FILES[@]}"; do
        local source_path="${CONFIG_SOURCE}/${config_file}"
        local dest_path="${CONFIG_DEST}/${config_file}"

        if [[ ! -e "${source_path}" ]]; then
            print_verbose "Skipped (not found): ${config_file}"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ "${DRY_RUN}" == "true" ]]; then
            # List the file that will be backed up
            echo ""
            echo "  File: ${config_file}"
            echo "    - ${config_file}"
            copied=$((copied + 1))
        else
            # Use rsync to copy the file
            rsync -a "${source_path}" "${dest_path}"
            print_verbose "Copied: ${config_file}"
            TOTAL_FILES_COPIED=$((TOTAL_FILES_COPIED + 1))
            copied=$((copied + 1))
        fi
    done

    print_info "Files: ${copied} copied, ${skipped} skipped"
}

# ============================================
# BACKUP SCRIPT DIRECTORIES
# ============================================

backup_script_dirs() {
    print_header "Backing up ~/Projects/ script directories"

    local copied=0
    local skipped=0

    for script_item in "${SCRIPT_DIRS[@]}"; do
        local source_path="${SCRIPTS_SOURCE}/${script_item}"
        local dest_path="${SCRIPTS_DEST}/${script_item}"

        if [[ ! -e "${source_path}" ]]; then
            print_verbose "Skipped (not found): ${script_item}"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ "${DRY_RUN}" == "true" ]]; then
            # List all files that will be backed up
            list_files_to_backup "${source_path}" "${dest_path}" "${script_item}"
            copied=$((copied + 1))
        else
            # Use rsync to copy directory
            if [[ -d "${source_path}" ]]; then
                rsync -a --delete "${source_path}/" "${dest_path}/"
                print_verbose "Copied: ${script_item}"
                TOTAL_SCRIPT_DIRS_COPIED=$((TOTAL_SCRIPT_DIRS_COPIED + 1))
            else
                # It's a file, not a directory
                rsync -a "${source_path}" "${dest_path}"
                print_verbose "Copied: ${script_item}"
            fi

            copied=$((copied + 1))
        fi
    done

    print_info "Script directories: ${copied} copied, ${skipped} skipped"
}

# ============================================
# RESTORE CONFIG DIRECTORIES
# ============================================

restore_config_dirs() {
    print_header "Restoring ~/.config/ directories"

    local restored=0
    local skipped=0

    for config_item in "${CONFIG_DIRS[@]}"; do
        local source_path="${CONFIG_DEST}/${config_item}"
        local dest_path="${CONFIG_SOURCE}/${config_item}"

        if [[ ! -e "${source_path}" ]]; then
            print_verbose "Skipped (not in backup): ${config_item}"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ "${DRY_RUN}" == "true" ]]; then
            list_files_to_backup "${source_path}" "${dest_path}" "${config_item}"
            restored=$((restored + 1))
        else
            # Create parent directory if needed
            mkdir -p "${dest_path}"

            # Use rsync to restore directory
            if [[ -d "${source_path}" ]]; then
                rsync -a "${source_path}/" "${dest_path}/"
                print_verbose "Restored: ${config_item}"
                TOTAL_DIRS_COPIED=$((TOTAL_DIRS_COPIED + 1))
            else
                rsync -a "${source_path}" "${dest_path}"
                print_verbose "Restored: ${config_item}"
            fi

            restored=$((restored + 1))
        fi
    done

    print_info "Directories: ${restored} restored, ${skipped} skipped"
}

# ============================================
# RESTORE CONFIG FILES
# ============================================

restore_config_files() {
    print_header "Restoring ~/.config/ files"

    local restored=0
    local skipped=0

    for config_file in "${CONFIG_FILES[@]}"; do
        local source_path="${CONFIG_DEST}/${config_file}"
        local dest_path="${CONFIG_SOURCE}/${config_file}"

        if [[ ! -e "${source_path}" ]]; then
            print_verbose "Skipped (not in backup): ${config_file}"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ "${DRY_RUN}" == "true" ]]; then
            echo ""
            echo "  File: ${config_file}"
            echo "    - ${config_file}"
            restored=$((restored + 1))
        else
            # Use rsync to restore the file
            rsync -a "${source_path}" "${dest_path}"
            print_verbose "Restored: ${config_file}"
            TOTAL_FILES_COPIED=$((TOTAL_FILES_COPIED + 1))
            restored=$((restored + 1))
        fi
    done

    print_info "Files: ${restored} restored, ${skipped} skipped"
}

# ============================================
# RESTORE SCRIPT DIRECTORIES
# ============================================

restore_script_dirs() {
    print_header "Restoring ~/Projects/ script directories"

    local restored=0
    local skipped=0

    for script_item in "${SCRIPT_DIRS[@]}"; do
        local source_path="${SCRIPTS_DEST}/${script_item}"
        local dest_path="${SCRIPTS_SOURCE}/${script_item}"

        if [[ ! -e "${source_path}" ]]; then
            print_verbose "Skipped (not in backup): ${script_item}"
            skipped=$((skipped + 1))
            continue
        fi

        if [[ "${DRY_RUN}" == "true" ]]; then
            list_files_to_backup "${source_path}" "${dest_path}" "${script_item}"
            restored=$((restored + 1))
        else
            # Create parent directory if needed
            mkdir -p "${dest_path}"

            # Use rsync to restore directory
            if [[ -d "${source_path}" ]]; then
                rsync -a "${source_path}/" "${dest_path}/"
                print_verbose "Restored: ${script_item}"
                TOTAL_SCRIPT_DIRS_COPIED=$((TOTAL_SCRIPT_DIRS_COPIED + 1))
            else
                rsync -a "${source_path}" "${dest_path}"
                print_verbose "Restored: ${script_item}"
            fi

            restored=$((restored + 1))
        fi
    done

    print_info "Script directories: ${restored} restored, ${skipped} skipped"
}

# ============================================
# SUMMARY
# ============================================

show_summary() {
    print_header "Backup Summary"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo ""
        echo "  DRY RUN MODE - No files were actually copied"
        echo "  Run without --dry-run to perform the backup"
        echo ""
    fi

    echo "  Config directories backed up: ${TOTAL_DIRS_COPIED}"
    echo "  Config files backed up: ${TOTAL_FILES_COPIED}"
    echo "  Script directories backed up: ${TOTAL_SCRIPT_DIRS_COPIED}"
    echo "  Backup location: ${BACKUP_ROOT}"
    echo ""

    if [[ "${DRY_RUN}" != "true" ]]; then
        print_header "Next Steps"
        echo ""
        echo "  1. Review what was backed up:"
        echo "     git status"
        echo ""
        echo "  2. Check changes:"
        echo "     git diff"
        echo ""
        echo "  3. Commit and push (when ready):"
        echo "     git add ."
        echo "     git commit -m \"Backup: \$(date +%Y-%m-%d)\""
        echo "     git push"
        echo ""
    fi
}

show_restore_summary() {
    print_header "Restore Summary"

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo ""
        echo "  DRY RUN MODE - No files were actually restored"
        echo "  Run without --dry-run to perform the restore"
        echo ""
    fi

    echo "  Config directories restored: ${TOTAL_DIRS_COPIED}"
    echo "  Config files restored: ${TOTAL_FILES_COPIED}"
    echo "  Script directories restored: ${TOTAL_SCRIPT_DIRS_COPIED}"
    echo "  Restored from: ${BACKUP_ROOT}"
    echo ""
}

# ============================================
# MAIN EXECUTION
# ============================================

main() {
    local RESTORE_MODE=false
    local SKIP_CONFIRM=false

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --restore)
                RESTORE_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --yes|-y)
                SKIP_CONFIRM=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --restore    Restore configs from backup to local system"
                echo "  --dry-run    Preview what would be backed up/restored without copying"
                echo "  --verbose    Show detailed output"
                echo "  --quiet      Minimal output"
                echo "  -y, --yes    Skip confirmation prompt (for restore)"
                echo "  -h, --help   Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                    # Backup local configs to repository"
                echo "  $0 --restore          # Restore configs from repository to local system"
                echo "  $0 --restore --dry-run  # Preview what would be restored"
                echo "  $0 --verbose          # Backup with detailed output"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Banner
    if [[ "${QUIET}" != "true" ]]; then
        if [[ "${RESTORE_MODE}" == "true" ]]; then
            echo "======================================"
            echo "  Omarchy Config Restore v${SCRIPT_VERSION}"
            echo "======================================"
        else
            echo "======================================"
            echo "  Omarchy Config Backup v${SCRIPT_VERSION}"
            echo "======================================"
        fi
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        echo ""
        echo "  *** DRY RUN MODE ***"
        echo ""
    fi

    # Confirmation prompt for restore mode
    if [[ "${RESTORE_MODE}" == "true" && "${DRY_RUN}" != "true" && "${SKIP_CONFIRM}" != "true" ]]; then
        echo ""
        echo "  WARNING: This will overwrite local files in:"
        echo "    - ~/.config/"
        echo "    - ~/Projects/"
        echo ""
        echo "  Files will be restored from: ${BACKUP_ROOT}"
        echo ""
        read -p "  Continue with restore? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            print_error "Restore cancelled by user"
            exit 1
        fi
        echo ""
    fi

    # Execute appropriate steps
    check_prerequisites

    if [[ "${RESTORE_MODE}" == "true" ]]; then
        # Restore mode
        restore_config_dirs
        restore_config_files
        restore_script_dirs
        show_restore_summary

        # Exit successfully
        if [[ "${DRY_RUN}" == "true" ]]; then
            print_success "Dry run completed successfully"
        else
            print_success "Restore completed successfully"
        fi
    else
        # Backup mode
        create_directories
        backup_config_dirs
        backup_config_files
        backup_script_dirs
        show_summary

        # Exit successfully
        if [[ "${DRY_RUN}" == "true" ]]; then
            print_success "Dry run completed successfully"
        else
            print_success "Backup completed successfully"
        fi
    fi
}

# Run main function
main "$@"
