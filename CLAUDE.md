# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a backup system for Omarchy Linux configurations. It backs up configuration files from `~/.config/` and scripts from `~/Projects/` to this Git repository for version control and disaster recovery.

## Core Architecture

### Two-Script System

1. **backup.sh** - Main backup orchestration script
   - Sources configuration from `config.sh`
   - Executes rsync operations with `--delete` flag to mirror directories
   - Provides dry-run, verbose, and quiet modes
   - Handles both directories and individual files
   - Backs up both `~/.config/` items and `~/Projects/` script directories

2. **config.sh** - Configuration file that defines:
   - `CONFIG_DIRS[]` - Directories to backup from `~/.config/`
   - `CONFIG_FILES[]` - Individual files to backup from `~/.config/`
   - `SCRIPT_DIRS[]` - Directories to backup from `~/Projects/`

### Backup Flow

```
backup.sh execution:
  1. Source config.sh to load arrays
  2. Check prerequisites (rsync, git)
  3. Create destination directories
  4. Backup config directories from ~/.config/ → config/
  5. Backup config files from ~/.config/ → config/
  6. Backup script directories from ~/Projects/ → ./scripts/
  7. Show summary and next steps
```

### Key Implementation Details

- Uses `rsync -a --delete` for directories to maintain exact mirrors
- Uses `rsync -a` for individual files
- Directory structure: Source trailing slash (`source/`) copies contents, not the directory itself
- All paths are resolved from `BACKUP_ROOT` (script location) to support running from any directory
- The `--delete` flag means rsync removes files in destination that don't exist in source

## Development Commands

### Running Backups

```bash
# Standard backup
./backup.sh

# Preview mode (see what would be backed up)
./backup.sh --dry-run

# Verbose mode (detailed output)
./backup.sh --verbose

# Quiet mode (minimal output)
./backup.sh --quiet
```

### Adding New Backup Targets

Edit `config.sh` and add to the appropriate array:

```bash
# For directories from ~/.config/
CONFIG_DIRS=(
    "hypr"
    "ghostty"
    "waybar"
    "new-directory"  # Add here
)

# For individual files from ~/.config/
CONFIG_FILES=(
    "starship.toml"
    "new-file.conf"  # Add here
)

# For directories from ~/Projects/
SCRIPT_DIRS=(
    "scripts"
    "new-scripts"  # Add here
)
```

**Always test with `--dry-run` after modifying config.sh**

### Git Workflow

After running backup:

```bash
# Review changes
git status
git diff

# Commit changes
git add .
git commit -m "Backup: $(date +%Y-%m-%d)"

# Push to remote
git push
```

## Important Constraints

### Security via .gitignore

The `.gitignore` is critical for preventing sensitive data from being committed:
- Blocks files matching `*password*`, `*secret*`, `*credentials*`
- Blocks key files: `*.key`, `*.pem`, `*.p12`, `*.pfx`
- Blocks cache directories, logs, and build artifacts
- Blocks nested `.git/` repositories

**When modifying backup targets, verify sensitive data is properly excluded**

### rsync Behavior

- `rsync -a` preserves permissions, timestamps, symlinks
- `--delete` removes files from destination that aren't in source
- Source path with trailing slash (`path/`) syncs contents
- Source path without trailing slash (`path`) syncs the directory itself
- The script uses trailing slashes for directories: `"${source_path}/" "${dest_path}/"`

## Scripts Directory

Contains utility scripts that are backed up from `~/Projects/scripts/`:

- **ssh-git.sh** - SSH agent helper for testing GitHub authentication
  - Usage: `./scripts/ssh-git.sh ~/.ssh/id_ed25519`
  - Starts/reuses ssh-agent, adds key, tests GitHub connection
  - Use `-h` or `--help` for usage information

- **game.sh** and **WOPR.sh** - Additional utility scripts

## System Requirements

- Arch Linux (uses `pacman` package manager)
- Required packages: `rsync`, `git`
- Hyprland window manager environment
- Ghostty terminal emulator

## Restoration

To restore configurations on a new system:

```bash
# Clone repository
git clone git@github.com:JonTelep/omarchy-backups.git
cd omarchy-backups

# Restore all configs
cp -r config/* ~/.config/

# Or restore individual config
cp -r config/nvim ~/.config/
```
