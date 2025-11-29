#!/bin/bash
set -Euo pipefail


TARGET_DIR="$HOME/.local/share/steam-launcher"
SWITCH_BIN="$TARGET_DIR/enter-gamesmode"
RETURN_BIN="$TARGET_DIR/leave-gamesmode"


# Try to find the user's bindings config file
BINDINGS_CONFIG=""
for location in \
    "$HOME/.config/hypr/bindings.conf" \
    "$HOME/.config/hypr/keybinds.conf" \
    "$HOME/.config/hypr/hyprland.conf"; do
  if [ -f "$location" ]; then
    BINDINGS_CONFIG="$location"
    break
  fi
done


CONFIG_FILE="/etc/gaming-mode.conf"
[[ -f "$HOME/.gaming-mode.conf" ]] && CONFIG_FILE="$HOME/.gaming-mode.conf"
# shellcheck source=/dev/null
source "$CONFIG_FILE" 2>/dev/null || {
  STEAM_LAUNCH_MODE="bigpicture"
  PERFORMANCE_MODE="enabled"
  GAME_RESOLUTION="native"
}


ADDED_BINDINGS=0
CREATED_TARGET_DIR=0


info(){ echo "[*] $*"; }
err(){ echo "[!] $*" >&2; }


die() {
  local msg="$1"; local code="${2:-1}"
  echo "FATAL: $msg" >&2
  logger -t gaming-mode "Installation failed: $msg"
  rollback_changes
  exit "$code"
}


rollback_changes() {
  [ -f "$SWITCH_BIN" ] && rm -f "$SWITCH_BIN"
  [ -f "$RETURN_BIN" ] && rm -f "$RETURN_BIN"
  if [ "$CREATED_TARGET_DIR" -eq 1 ] && [ -d "$TARGET_DIR" ]; then 
    rmdir "$TARGET_DIR" 2>/dev/null || true
  fi
  
  # Remove added bindings
  if [ "$ADDED_BINDINGS" -eq 1 ] && [ -n "$BINDINGS_CONFIG" ] && [ -f "$BINDINGS_CONFIG" ]; then
    sed -i '/# Gaming Mode bindings - added by installation script/,/# End Gaming Mode bindings/d' "$BINDINGS_CONFIG"
  fi
}


validate_environment() {
  command -v pacman  >/dev/null || die "pacman required"
  command -v hyprctl >/dev/null || die "hyprctl required"
  [ -f "$HOME/.config/hypr/hyprland.conf" ] || die "hyprland.conf not found"
  [ -n "$BINDINGS_CONFIG" ] || die "Could not find bindings config file"
}


check_package() { pacman -Qi "$1" &>/dev/null; }


setup_requirements() {
  local -a required_packages=("gamescope" "mangohud" "zenity" "python" "libcap")
  local -a packages_to_install=()
  for pkg in "${required_packages[@]}"; do 
    check_package "$pkg" || packages_to_install+=("$pkg")
  done
  
  if ((${#packages_to_install[@]})); then
    info "Installing: ${packages_to_install[*]}"
    sudo pacman -S --needed --noconfirm "${packages_to_install[@]}" || die "package install failed"
  else
    info "All required packages present."
  fi
  
  command -v steam >/dev/null || info "Steam not found – install it if needed."
  
  if [[ "${PERFORMANCE_MODE,,}" == "enabled" ]] && command -v gamescope >/dev/null 2>&1; then
    sudo setcap 'cap_sys_nice+ep' "$(command -v gamescope)" || info "setcap failed; --rt may be ignored."
  fi
}


resolve_steam_args() {
  case "${STEAM_LAUNCH_MODE,,}" in
    gamepadui) echo "-gamepadui" ;;
    bigpicture|"") echo "-tenfoot" ;;
    *) echo "-tenfoot" ;;
  esac
}


resolve_gamescope_perf_flags() {
  [[ "${PERFORMANCE_MODE,,}" == "enabled" ]] && echo "--rt --immediate-flips" || echo ""
}


deploy_launchers() {
  if [ ! -d "$TARGET_DIR" ]; then 
    mkdir -p "$TARGET_DIR" || die "cannot create $TARGET_DIR"
    CREATED_TARGET_DIR=1
  fi
  
  local steam_flags gamescope_perf
  steam_flags="$(resolve_steam_args)"
  gamescope_perf="$(resolve_gamescope_perf_flags)"


  cat > "$SWITCH_BIN" <<EOF
#!/bin/bash
set -Euo pipefail
STATE_DIR="\$HOME/.cache/gaming-session"
LOCK_FILE="\$STATE_DIR/idle-prevention.lock"
SESSION_FILE="\$STATE_DIR/session.pid"
CONFIG_FILE="/etc/gaming-mode.conf"
[[ -f "\$HOME/.gaming-mode.conf" ]] && CONFIG_FILE="\$HOME/.gaming-mode.conf"
source "\$CONFIG_FILE" 2>/dev/null || { STEAM_LAUNCH_MODE="${STEAM_LAUNCH_MODE}"; PERFORMANCE_MODE="${PERFORMANCE_MODE}"; GAME_RESOLUTION="native"; }


steam_icon() { echo "steam"; }
center_notify() {
  local msg="\$*"
  if command -v zenity >/dev/null 2>&1; then
    local ICON; ICON="\$(steam_icon)"
    if [[ -n "\$ICON" ]]; then 
      nohup bash -lc "zenity --info --window-icon='\${ICON}' --title='Gamesmode' --no-wrap --width=420 --timeout=2 --text='\${msg}'" >/dev/null 2>&1 &
    else 
      nohup bash -lc "zenity --info --title='Gamesmode' --no-wrap --width=420 --timeout=2 --text='\${msg}'" >/dev/null 2>&1 &
    fi
  fi
}


get_display() {
  local j; j="\$(hyprctl monitors -j 2>/dev/null)"
  if [[ -z "\$j" ]]; then echo "1920 1080 60"; return; fi
  printf '%s\n' "\$j" | python3 - <<'PY'
import json,sys
try:
  d=json.load(sys.stdin); m=d[0] if d else {}
  print(int(m.get("width",1920)), int(m.get("height",1080)), int(round(m.get("refreshRate",60))))
except Exception:
  print("1920 1080 60")
PY
}


read -r horizontal_res vertical_res monitor_hz <<<"\$(get_display)"
DISPLAY_WIDTH="\$horizontal_res"; DISPLAY_HEIGHT="\$vertical_res"; REFRESH_RATE="\$monitor_hz"


# Check if previous settings exist
SETTINGS_FILE="\$STATE_DIR/last-settings"
USE_PREVIOUS=false


if [[ -f "\$SETTINGS_FILE" ]]; then
  # Ask user if they want to use previous settings
  hyprctl keyword windowrulev2 "float, class:(zenity), title:(Gaming Mode - Quick Launch)" >/dev/null 2>&1
  hyprctl keyword windowrulev2 "size 600 300, class:(zenity), title:(Gaming Mode - Quick Launch)" >/dev/null 2>&1
  hyprctl keyword windowrulev2 "center, class:(zenity), title:(Gaming Mode - Quick Launch)" >/dev/null 2>&1


  QUICK_CHOICE=\$(zenity --list --radiolist \\
    --title="Gaming Mode - Quick Launch" \\
    --text="Previous settings found. How would you like to proceed?" \\
    --width=600 --height=300 \\
    --column="" --column="Option" --column="Description" \\
    TRUE "Use Previous" "Launch with your last saved settings" \\
    FALSE "Configure Now" "Choose resolution and MangoHud settings" \\
    2>/dev/null)


  hyprctl keyword windowrulev2 "unset, class:(zenity), title:(Gaming Mode - Quick Launch)" >/dev/null 2>&1


  if [[ -z "\$QUICK_CHOICE" ]]; then
    center_notify "Gaming Mode cancelled"
    exit 0
  fi


  if [[ "\$QUICK_CHOICE" == "Use Previous" ]]; then
    USE_PREVIOUS=true
    source "\$SETTINGS_FILE"
  fi
fi


if [[ "\$USE_PREVIOUS" == false ]]; then
  # Show resolution selection menu (fixed size, centered)
  # Temporarily add window rules for zenity dialog only during this session
  hyprctl keyword windowrulev2 "float, class:(zenity), title:(Gaming Mode - Resolution Settings)" >/dev/null 2>&1
  hyprctl keyword windowrulev2 "size 800 500, class:(zenity), title:(Gaming Mode - Resolution Settings)" >/dev/null 2>&1
  hyprctl keyword windowrulev2 "center, class:(zenity), title:(Gaming Mode - Resolution Settings)" >/dev/null 2>&1


  RESOLUTION_CHOICE=\$(zenity --list --radiolist \\
  --title="Gaming Mode - Resolution Settings" \\
  --text="Select your preferred gaming resolution:\\n\\nNative Display: \${DISPLAY_WIDTH}x\${DISPLAY_HEIGHT}" \\
  --width=800 --height=500 \\
  --column="" --column="Resolution" --column="Description" \\
  TRUE "Native (\${DISPLAY_WIDTH}x\${DISPLAY_HEIGHT})" "Render at native resolution (best quality)" \\
  FALSE "UHD (3840x2160)" "Render at 4K/UHD resolution" \\
  FALSE "UHD Upscaled" "Render at 1440p, upscale to 4K (balanced)" \\
  FALSE "1440p (2560x1440)" "Render at 1440p resolution" \\
  FALSE "1440p Upscaled" "Render at 1080p, upscale to 1440p (better FPS)" \\
  FALSE "1080p (1920x1080)" "Render at 1080p resolution" \\
  2>/dev/null)


# Remove the temporary window rules after dialog closes
hyprctl keyword windowrulev2 "unset, class:(zenity), title:(Gaming Mode - Resolution Settings)" >/dev/null 2>&1


  # If user cancelled, exit
  if [[ -z "\$RESOLUTION_CHOICE" ]]; then
    center_notify "Gaming Mode cancelled"
    exit 0
  fi


  # Show MangoHud preset selection
  hyprctl keyword windowrulev2 "float, class:(zenity), title:(Gaming Mode - MangoHud Settings)" >/dev/null 2>&1
  hyprctl keyword windowrulev2 "size 800 400, class:(zenity), title:(Gaming Mode - MangoHud Settings)" >/dev/null 2>&1
  hyprctl keyword windowrulev2 "center, class:(zenity), title:(Gaming Mode - MangoHud Settings)" >/dev/null 2>&1


  MANGOHUD_CHOICE=\$(zenity --list --radiolist \\
    --title="Gaming Mode - MangoHud Settings" \\
    --text="Select your preferred performance overlay:" \\
    --width=800 --height=400 \\
    --column="" --column="Preset" --column="Description" \\
    FALSE "Off" "No performance overlay (cleanest view)" \\
    TRUE "Minimal" "FPS counter only (recommended)" \\
    FALSE "Full Stats" "Detailed performance metrics (CPU, GPU, temps, frametime)" \\
    2>/dev/null)


  hyprctl keyword windowrulev2 "unset, class:(zenity), title:(Gaming Mode - MangoHud Settings)" >/dev/null 2>&1


  # If user cancelled, exit
  if [[ -z "\$MANGOHUD_CHOICE" ]]; then
    center_notify "Gaming Mode cancelled"
    exit 0
  fi


  # Save settings for next time
  mkdir -p "\$STATE_DIR"
  cat > "\$SETTINGS_FILE" <<SETTINGS
RESOLUTION_CHOICE="\$RESOLUTION_CHOICE"
MANGOHUD_CHOICE="\$MANGOHUD_CHOICE"
SETTINGS


fi


# Set game rendering and output resolution based on choice
game_width="\$DISPLAY_WIDTH"
game_height="\$DISPLAY_HEIGHT"
output_width="\$DISPLAY_WIDTH"
output_height="\$DISPLAY_HEIGHT"


case "\$RESOLUTION_CHOICE" in
  "Native (\${DISPLAY_WIDTH}x\${DISPLAY_HEIGHT})")
    game_width="\$DISPLAY_WIDTH"
    game_height="\$DISPLAY_HEIGHT"
    output_width="\$DISPLAY_WIDTH"
    output_height="\$DISPLAY_HEIGHT"
    ;;
  "UHD (3840x2160)")
    game_width=3840
    game_height=2160
    output_width=3840
    output_height=2160
    ;;
  "UHD Upscaled")
    game_width=2560
    game_height=1440
    output_width=3840
    output_height=2160
    ;;
  "1440p (2560x1440)")
    game_width=2560
    game_height=1440
    output_width=2560
    output_height=1440
    ;;
  "1440p Upscaled")
    game_width=1920
    game_height=1080
    output_width=2560
    output_height=1440
    ;;
  "1080p (1920x1080)")
    game_width=1920
    game_height=1080
    output_width=1920
    output_height=1080
    ;;
esac


mkdir -p "\$STATE_DIR"
: > "\$LOCK_FILE"
echo \$\$ > "\$SESSION_FILE"
pkill -9 hypridle 2>/dev/null || true
center_notify "Starting Gamesmode at \${game_width}x\${game_height}…"


gamescope_perf=""
[[ "\${PERFORMANCE_MODE,,}" == "enabled" ]] && gamescope_perf="--rt --immediate-flips"
steam_args=""
case "\${STEAM_LAUNCH_MODE,,}" in
  gamepadui) steam_args="-gamepadui" ;;
  bigpicture|"") steam_args="-tenfoot" ;;
  *) steam_args="-tenfoot" ;;
esac


# Configure MangoHud based on user choice
mangohud_flag=""
mangohud_config=""
case "\$MANGOHUD_CHOICE" in
  "Off")
    mangohud_flag=""
    ;;
  "Minimal")
    mangohud_flag="--mangoapp"
    mangohud_config="fps,fps_only,position=top-left,font_size=24"
    ;;
  "Full Stats")
    mangohud_flag="--mangoapp"
    mangohud_config="cpu_temp,gpu_temp,cpu_power,gpu_power,ram,vram,fps,frametime,frame_timing=1,gpu_stats,cpu_stats,position=top-left"
    ;;
esac


# Launch gamescope with MangoHud configuration
if [[ -n "\$mangohud_config" ]]; then
  MANGOHUD_CONFIG="\$mangohud_config" exec /usr/bin/gamescope \$gamescope_perf \$mangohud_flag -f -w "\$game_width" -h "\$game_height" -W "\$output_width" -H "\$output_height" -r "\$REFRESH_RATE" --force-grab-cursor -e -- /usr/bin/steam \$steam_args
else
  exec /usr/bin/gamescope \$gamescope_perf \$mangohud_flag -f -w "\$game_width" -h "\$game_height" -W "\$output_width" -H "\$output_height" -r "\$REFRESH_RATE" --force-grab-cursor -e -- /usr/bin/steam \$steam_args
fi
EOF
  chmod +x "$SWITCH_BIN" || die "cannot chmod $SWITCH_BIN"


  cat > "$RETURN_BIN" <<'EOF'
#!/bin/bash
set -Euo pipefail
STATE_DIR="$HOME/.cache/gaming-session"
LOCK_FILE="$STATE_DIR/idle-prevention.lock"
SESSION_FILE="$STATE_DIR/session.pid"


steam_icon() { echo "steam"; }
center_notify() {
  local msg="$*"
  if command -v zenity >/dev/null 2>&1; then
    local ICON; ICON="$(steam_icon)"
    if [[ -n "$ICON" ]]; then 
      nohup bash -lc "zenity --info --window-icon='${ICON}' --title='Gamesmode' --no-wrap --width=360 --timeout=2 --text='${msg}'" >/dev/null 2>&1 &
    else 
      nohup bash -lc "zenity --info --title='Gamesmode' --no-wrap --width=360 --timeout=2 --text='${msg}'" >/dev/null 2>&1 &
    fi
  fi
}


if [[ -f "$SESSION_FILE" ]]; then
  PID="$(cat "$SESSION_FILE" 2>/dev/null || true)"
  if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 0.5
    kill -9 "$PID" 2>/dev/null || true
  fi
fi
pkill -9 gamescope 2>/dev/null || true
rm -f "$LOCK_FILE" "$SESSION_FILE" 2>/dev/null || true
center_notify "Exiting Gamesmode…"
EOF
  chmod +x "$RETURN_BIN" || die "cannot chmod $RETURN_BIN"
}


configure_shortcuts() {
  info "Adding keybindings to: $BINDINGS_CONFIG"
  
  # Check if bindings already exist
  if grep -q "# Gaming Mode bindings - added by installation script" "$BINDINGS_CONFIG" 2>/dev/null; then
    info "Gaming mode bindings already exist in config, skipping..."
    return 0
  fi
  
  # Detect the binding style used in the config
  local bind_style="bindd"
  if ! grep -q "^bindd\s*=" "$BINDINGS_CONFIG" 2>/dev/null; then
    if grep -q "^bind\s*=" "$BINDINGS_CONFIG" 2>/dev/null; then
      bind_style="bind"
    fi
  fi
  
  # Add bindings to the config file
  {
    echo ""
    echo "# Gaming Mode bindings - added by installation script"
    if [ "$bind_style" = "bindd" ]; then
      echo "bindd = SUPER SHIFT, S, Steam Gaming Mode, exec, $SWITCH_BIN"
      echo "bindd = SUPER SHIFT, R, Exit Gaming Mode, exec, $RETURN_BIN"
    else
      echo "bind = SUPER SHIFT, S, exec, $SWITCH_BIN"
      echo "bind = SUPER SHIFT, R, exec, $RETURN_BIN"
    fi
    echo "# End Gaming Mode bindings"
  } >> "$BINDINGS_CONFIG" || die "failed to add bindings to $BINDINGS_CONFIG"
  
  ADDED_BINDINGS=1
  
  # Reload Hyprland config
  hyprctl reload >/dev/null 2>&1 || info "Hyprland reload may have failed; relog if binds inactive."
}


check_component() {
  case "$1" in
    launcher)
      [ -x "$SWITCH_BIN" ] && [ -x "$RETURN_BIN" ] || { 
        err "launcher check failed"
        return 1
      }
      ;;
    shortcuts)
      [ -f "$BINDINGS_CONFIG" ] && grep -q "# Gaming Mode bindings" "$BINDINGS_CONFIG" || {
        err "shortcuts check failed"
        return 1
      }
      ;;
    capabilities)
      if [[ "${PERFORMANCE_MODE,,}" == "enabled" ]]; then
        command -v gamescope >/dev/null 2>&1 && \
        getcap "$(command -v gamescope)" 2>/dev/null | grep -q 'cap_sys_nice' || {
          err "capabilities check failed"
          return 1
        }
      fi
      ;;
    *) 
      err "unknown component: $1"
      return 1
      ;;
  esac
}


validate_deployment() {
  local errors=0
  for component in launcher shortcuts capabilities; do
    check_component "$component" || ((errors++))
  done
  return $errors
}


execute_setup() {
  validate_environment
  info "Found bindings config at: $BINDINGS_CONFIG"
  setup_requirements
  deploy_launchers
  configure_shortcuts
  validate_deployment || die "deployment validation failed"
  echo ""
  info "✓ Install complete!"
  info "  Launch: Super+Shift+S"
  info "  Exit:   Super+Shift+R"
  info ""
  info "Binaries:  $TARGET_DIR"
  info "Bindings:  $BINDINGS_CONFIG"
  info "Config:    $CONFIG_FILE"
}


gaming_mode::initialize() { validate_environment; setup_requirements; }
gaming_mode::install()    { deploy_launchers; }
gaming_mode::configure()  { configure_shortcuts; validate_deployment || die "validation failed"; }


execute_setup

