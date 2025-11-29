# Omarchy Linux Config Backup

Configuration backup for Omarchy Linux. This repository contains scripts to backup and version control specific configuration directories from `~/.config/`.

## Quick Start

### Running a Backup

```bash
cd ~/Projects/omarchy-backups
./backup.sh
```

After running the backup, review and commit your changes:

```bash
git status          # See what changed
git diff            # Review changes in detail
git add .
git commit -m "Backup: $(date +%Y-%m-%d)"
git push
```

### Preview Mode (Dry Run)

Test the backup without making changes:

```bash
./backup.sh --dry-run
```

### Verbose Output

See detailed information about what's being backed up:

```bash
./backup.sh --verbose
```

## What Gets Backed Up

The script backs up the following directories from `~/.config/`:

- **`hypr`** - Hyprland window manager configuration
- **`ghostty`** - Ghostty terminal emulator configuration
- **`omarchy`** - Omarchy-specific configurations
- **`nvim`** - Neovim editor configuration

All directories are backed up to the `config/` directory in this repository.

## Customization

### Adding Directories to Backup

Edit `config.sh` to customize what directories get backed up:

```bash
CONFIG_DIRS=(
    "hypr"
    "ghostty"
    "omarchy"
    "nvim"
    "Code"        # Add this
)
```

Always test with `--dry-run` after making changes!

## Restoring Configurations

### Manual Restore

To restore directories to your system:

```bash
# Restore a single config directory
cp -r config/nvim ~/.config/

# Restore all config directories
cp -r config/* ~/.config/
```

### Fresh System Setup

On a fresh Omarchy Linux installation:

1. Clone this repository:
   ```bash
   git clone git@github.com:JonTelep/omarchy-backups.git
   cd omarchy-backups
   ```

2. Review what will be restored:
   ```bash
   ls -la config/
   ```

3. Copy directories to ~/.config/:
   ```bash
   cp -r config/* ~/.config/
   ```

## Repository Structure

```
omarchy-backups/
├── backup.sh              # Main backup script
├── config.sh              # Configuration (what to backup)
├── .gitignore            # Exclusion patterns for Git
├── README.md             # This file
└── config/               # Backed up config directories
    ├── hypr/
    ├── ghostty/
    ├── omarchy/
    └── nvim/
```

## Usage Examples

### Regular Backup Workflow

```bash
# Navigate to repo
cd ~/Projects/omarchy-backups

# Run backup
./backup.sh

# Review changes
git status
git diff home/.config/nvim/

# Commit changes
git add .
git commit -m "Backup: Updated nvim and hyprland configs"

# Push to GitHub
git push
```

### After Configuration Changes

After modifying your config files:

```bash
# Run backup
./backup.sh

# Review and commit
git add .
git commit -m "Backup: Updated configs"
git push
```

## Troubleshooting

### Permission Denied Errors

If you get permission errors:

```bash
chmod +x backup.sh
```

### rsync Not Found

Install rsync:

```bash
sudo pacman -S rsync
```

### Backup Too Large

Check what's taking up space:

```bash
du -sh config/*
```

## Command Reference

```bash
./backup.sh              # Run backup
./backup.sh --dry-run    # Preview without changes
./backup.sh --verbose    # Detailed output
./backup.sh --quiet      # Minimal output
./backup.sh --help       # Show help message
```

## Maintenance

- Run backup after making configuration changes
- Review and commit changes regularly
- Test restore process periodically

## Author

Jonathan Telep

---

**Last Updated**: 2025-11-26
