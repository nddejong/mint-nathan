#!/usr/bin/env bash

# ==============================================================================
# Linux Mint Idempotent Post-Install Automation Project
# Target OS: Linux Mint (Cinnamon / XFCE)
# Hardware Profile: Low-resource optimization (OptiPlex 990 friendly)
# Layout Style: macOS Tahoe Inspired (Dark Mode Ready)
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# --- COLOR VARIABLES FOR LOGGING ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- LOGGING FUNCTIONS ---
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- CONFIGURATION / PACKAGE ARRAYS ---
APT_PACKAGES=(
    "git"
    "curl"
    "vlc"
    "build-essential"
    "neofetch"
    "plank"        # The macOS style dock engine
    "conky-all"    # Full conky compilation with widget support
)

FLATPAK_PACKAGES=(
    "com.valvesoftware.Steam"     # Steam Gaming Engine
    "com.discordapp.Discord"       # Discord Chat Client
    "org.mozilla.Thunderbird"      # Mail Client
    "dev.zed.Zed"                  # Zed High-Performance Editor
    "com.vivaldi.Vivaldi"          # Vivaldi Custom Browser
)

# ==============================================================================
# CORE STAGES
# ==============================================================================

check_privileges() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script requires root privileges to install packages. Please run with sudo: sudo ./setup.sh"
    fi
}

backup_existing_configs() {
    TARGET_USER=${SUDO_USER:-$USER}
    USER_HOME=$(eval echo "~$TARGET_USER")
    
    if [ "$TARGET_USER" = "root" ]; then
        return
    fi

    # Create a unique timestamped folder for this specific execution loop
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="$USER_HOME/mint_setup_backups/backup_$TIMESTAMP"
    
    # Track critical asset directories that our script might alter or overwrite
    PATHS_TO_BACKUP=(
        ".config/plank"
        ".config/conky"
        ".config/autostart/plank.desktop"
        ".config/autostart/conky.desktop"
    )

    log_info "Evaluating local environment state for existing configurations..."
    INITIALIZED_BACKUP=false

    for target_path in "${PATHS_TO_BACKUP[@]}"; do
        FULL_PATH="$USER_HOME/$target_path"
        
        # IDEMPOTENT GUARD: Only create backup structures if an explicit target file/folder exists
        if [ -e "$FULL_PATH" ] || [ -L "$FULL_PATH" ]; then
            if [ "$INITIALIZED_BACKUP" = false ]; then
                log_warn "Found existing environment assets. Initializing archive directory: $BACKUP_DIR"
                sudo -u "$TARGET_USER" mkdir -p "$BACKUP_DIR"
                INITIALIZED_BACKUP=true
            fi
            
            # Preserve internal folder matrices within the backup capsule
            PARENT_SUBDIR=$(dirname "$target_path")
            sudo -u "$TARGET_USER" mkdir -p "$BACKUP_DIR/$PARENT_SUBDIR"
            
            log_info "  -> Archiving existing config: ~$target_path"
            # Move the assets cleanly out of the active runtime path
            sudo -u "$TARGET_USER" mv "$FULL_PATH" "$BACKUP_DIR/$target_path"
        fi
    done

    if [ "$INITIALIZED_BACKUP" = true ]; then
        log_success "Environment snapshot archived cleanly."
    else
        log_info "No conflicting configuration paths detected. Proceeding with clean deployment profiles."
    fi
}

system_update() {
    log_info "Refreshing package repositories and updating system base..."
    apt-get update -y && apt-get upgrade -y
    log_success "System up to date."
}

install_apt_apps() {
    log_info "Installing system applications via APT..."
    for pkg in "${APT_PACKAGES[@]}"; do
        # IDEMPOTENT GUARD: Check if the package is already marked as installed ('ii')
        if dpkg -l | grep -q "^ii  $pkg "; then
            log_info "  -> $pkg is already installed. Skipping."
        else
            log_info "  -> Installing $pkg..."
            apt-get install -y "$pkg"
        fi
    done
    log_success("APT applications evaluated successfully.")
}

install_flatpak_apps() {
    log_info "Configuring Flatpak and Flathub ecosystem remote handles..."
    # IDEMPOTENT GUARD: Safe remote handling
    flatpak remote-add --if-not-exists flathub https://flathub.org

    log_info("Installing Flatpak applications (Games, Browsers & Editors)...")
    # Get a list of already installed flatpaks to avoid redundant overhead networks
    INSTALLED_FLATPAKS=$(flatpak list --columns=application)
    
    for app in "${FLATPAK_PACKAGES[@]}"; do
        if echo "$INSTALLED_FLATPAKS" | grep -q "^$app$"; then
            log_info "  -> $app is already installed via Flatpak. Skipping."
        else
            log_info("  -> Installing $app...")
            flatpak install flathub -y "$app"
        fi
    done
    log_success "Flatpak applications evaluated successfully."
}

install_opencode_agent() {
    log_info "Evaluating OpenCode Terminal Agent installation state..."
    TARGET_USER=${SUDO_USER:-$USER}
    USER_HOME=$(eval echo "~$TARGET_USER")

    # IDEMPOTENT GUARD: Check if opencode binary is already accessible in paths
    if command -v opencode &> /dev/null; then
        log_info "  -> OpenCode terminal binary is already present. Skipping installation."
    else
        log_info "  -> Deploying OpenCode AI Agent via official installation runtime..."
        # Execute the safe installer pipeline inside the user environment space
        sudo -u "$TARGET_USER" bash -c "curl -fsSL https://opencode.ai | bash"
        log_success "OpenCode Agent successfully deployed."
    fi
}

apply_mac_tweaks() {
    log_info "Applying macOS desktop aesthetics..."
    
    TARGET_USER=${SUDO_USER:-$USER}
    USER_HOME=$(eval echo "~$TARGET_USER")
    
    if [ "$TARGET_USER" = "root" ]; then
        log_warn "Running completely as root user. Skipping user-space desktop tweaks."
        return
    fi

    # IDEMPOTENT GUARD: mkdir -p is inherently safe to run multiple times
    sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.themes"
    sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.icons"
    sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/src"
    sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/plank/dock1/settings"
    sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/conky"
    sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/autostart"

    # ==========================================
    # 1. THEMES & ICONS (GIT CLONE GUARDS)
    # ==========================================
    if [ -d "$USER_HOME/src/WhiteSur-gtk-theme/.git" ]; then
        log_info "Updating WhiteSur GTK Theme repository..."
        cd "$USER_HOME/src/WhiteSur-gtk-theme" && sudo -u "$TARGET_USER" git pull
    else
        log_info "Cloning fresh WhiteSur GTK Theme repo..."
        sudo -u "$TARGET_USER" git clone https://github.com "$USER_HOME/src/WhiteSur-gtk-theme"
    fi
    sudo -u "$TARGET_USER" "$USER_HOME/src/WhiteSur-gtk-theme/install.sh" -t all -s b -i apple -c Dark -o solid

    if [ -d "$USER_HOME/src/WhiteSur-icon-theme/.git" ]; then
        log_info "Updating WhiteSur Icon pack repository..."
        cd "$USER_HOME/src/WhiteSur-icon-theme" && sudo -u "$TARGET_USER" git pull
    else
        log_info "Cloning fresh WhiteSur Icon pack..."
        sudo -u "$TARGET_USER" git clone https://github.com "$USER_HOME/src/WhiteSur-icon-theme"
    fi
    sudo -u "$TARGET_USER" "$USER_HOME/src/WhiteSur-icon-theme/install.sh" -a

    # ==========================================
    # 2. OVERWRITING DESKTOP CONFIGS CLEANLY
    # ==========================================
    log_info "Binding dark mode theme parameters to system window manager..."
    sudo -u "$TARGET_USER" gsettings set org.cinnamon.desktop.interface gtk-theme "WhiteSur-Dark"
    sudo -u "$TARGET_USER" gsettings set org.cinnamon.desktop.interface icon-theme "WhiteSur-dark"
    sudo -u "$TARGET_USER" gsettings set org.cinnamon.desktop.wm.preferences button-layout 'close,minimize,maximize:'

    # Plank settings deployment
    sudo -u "$TARGET_USER" bash -c "cat << 'EOF' > $USER_HOME/.config/plank/dock1/settings/preferences
[PlankDockPreferences]
Monitor=
TopLevelWindow=false
Position=3
Offset=0
Alignment=3
Size=48
HideMode=1
UnidehideDelay=0
MonitorHide=false
IconAlignment=3
ZoomEnabled=true
ZoomPercent=125
Theme=WhiteSur
EOF"

    if [ -d "$USER_HOME/src/WhiteSur-gtk-theme/src/other/plank" ]; then
        sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.local/share/plank/themes"
        sudo -u "$TARGET_USER" cp -r "$USER_HOME/src/WhiteSur-gtk-theme/src/other/plank/"* "$USER_HOME/.local/share/plank/themes/"
    fi

    # Conky layout deployment
    sudo -u "$TARGET_USER" bash -c "cat << 'EOF' > $USER_HOME/.config/conky/conky.conf
conky.config = {
    alignment = 'top_right',
    background = true,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = 'white',
    font = 'Sans:size=10',
    gap_x = 30,
    gap_y = 50,
    minimum_width = 250,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_x = true,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'desktop',
    own_window_transparent = true,
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    update_interval = 1.0,
    use_xft = true,
}

conky.text = [[
\${font Sans:size=32}\${time %H:%M}\${font}
\${font Sans:size=12}\${time %A, %B %d}\${font}
\${hr}
\${font Sans:bold:size=10}SYSTEM OVERVIEW\${font}

Uptime: $uptime
CPU Usage: ${cpu cpu0}% ${cpubar 4}
RAM Usage: $mem/$memmax ($memperc%) ${membar 4}
]]
EOF"
# ==========================================
# 3. AUTOSTART INITIALIZATION
# ==========================================
sudo -u "$TARGET_USER" bash -c "cat << 'EOF' > $USER_HOME/.config/autostart/plank.desktop
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Plank
Comment=macOS Style Dock
EOF"
sudo -u "$TARGET_USER" bash -c "cat << 'EOF' > $USER_HOME/.config/autostart/conky.desktop
[Desktop Entry]
Type=Application
Exec=sh -c 'sleep 5 && conky -c $USER_HOME/.config/conky/conky.conf'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Conky
Comment=Desktop System Metrics
EOF"
# Flatpak Theme Synchronization Override
sudo flatpak override --filesystem=xdg-config/gtk-3.0:ro --filesystem=xdg-config/gtk-4.0:ro
log_success "Desktop modifications applied completely."
}
cleanup_system() {
log_info "Cleaning up package cache and redundant dependencies..."
apt-get autoremove -y && apt-get clean
log_success "System optimization complete!"
}

==============================================================================


MAIN EXECUTION LOOP


==============================================================================

main() {
echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}      Starting Linux Mint Setup Automation          ${NC}"
echo -e "${BLUE}====================================================${NC}"
check_privileges
backup_existing_configs
system_update
install_apt_apps
install_flatpak_apps
install_opencode_agent
apply_mac_tweaks
cleanup_system
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN} Setup completed successfully!                      ${NC}"
echo -e "${GREEN}====================================================${NC}"
}
main "$@"
