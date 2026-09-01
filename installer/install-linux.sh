#!/usr/bin/env bash
# ==============================================================================
# SS-CAM Linux Native Desktop Application Interactive Installer & Setup
# Supported Distros: Fedora, Ubuntu, Debian, Pop!_OS, Arch Linux, RHEL, Manjaro
# ==============================================================================

main() {
    set -e

    # Terminal Color Palette
    local C_RESET="\033[0m"
    local C_BOLD="\033[1m"
    local C_CYAN="\033[1;36m"
    local C_BLUE="\033[1;34m"
    local C_GREEN="\033[1;32m"
    local C_YELLOW="\033[1;33m"
    local C_RED="\033[1;31m"
    local C_DIM="\033[2m"

    local APP_NAME="ss-cam"
    local DISPLAY_NAME="SuamiSihat Creative Assets Management"
    local VERSION="4.6.0"
    local DEFAULT_INSTALL_DIR="/opt/ss-cam"
    local INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    local BIN_LINK="/usr/local/bin/ss-cam"
    local DESKTOP_DIR="/usr/share/applications"
    local ICON_SCALABLE_DIR="/usr/share/icons/hicolor/scalable/apps"
    local ICON_256_DIR="/usr/share/icons/hicolor/256x256/apps"

    local RELEASE_TAR_URL="https://github.com/SuamiSihat/ss_cam/releases/download/v${VERSION}/SS-CAM-v${VERSION}-linux-x64.tar.gz"
    local FALLBACK_TAR_URL="https://github.com/SuamiSihat/ss_cam/releases/download/v${VERSION}/ss-cam-linux-x64.tar.gz"
    local ICON_URL="https://raw.githubusercontent.com/SuamiSihat/ss_cam/SS-Master/installer/assets/ss-cam.svg"

    # Interactive TTY Reader Helper (Safe for curl | bash pipes)
    prompt_input() {
        local prompt_msg="$1"
        local def_val="$2"
        local out_var="$3"

        if [ -c /dev/tty ]; then
            echo -ne "$prompt_msg" > /dev/tty 2>/dev/null || echo -ne "$prompt_msg"
            local inp=""
            read -r inp < /dev/tty 2>/dev/null || inp=""
            if [ -z "$inp" ]; then
                eval "$out_var=\"$def_val\""
            else
                eval "$out_var=\"$inp\""
            fi
        elif [ -t 0 ]; then
            echo -ne "$prompt_msg"
            local inp=""
            read -r inp || inp=""
            if [ -z "$inp" ]; then
                eval "$out_var=\"$def_val\""
            else
                eval "$out_var=\"$inp\""
            fi
        else
            eval "$out_var=\"$def_val\""
        fi
    }

    # Parse Command-Line Flags
    local UNATTENDED=0
    local DO_UNINSTALL=0
    local FORCE_BUILD=0
    local CUSTOM_DIR=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        -y|--yes|--unattended|--silent)
          UNATTENDED=1
          shift
          ;;
        -u|--uninstall)
          DO_UNINSTALL=1
          shift
          ;;
        -b|--build)
          FORCE_BUILD=1
          shift
          ;;
        -d|--dir)
          CUSTOM_DIR="$2"
          shift 2
          ;;
        -h|--help)
          echo -e "${C_BOLD}SS-CAM Linux Installer v${VERSION}${C_RESET}"
          echo "Usage: sudo ./install-linux.sh [OPTIONS]"
          echo ""
          echo "Options:"
          echo "  -y, --yes          Non-interactive / Unattended installation (Express default)"
          echo "  -u, --uninstall    Uninstall SS-CAM and remove desktop shortcuts"
          echo "  -b, --build        Force build from source via .NET SDK"
          echo "  -d, --dir PATH     Specify custom installation directory (default: /opt/ss-cam)"
          echo "  -h, --help         Show this help message"
          return 0
          ;;
        *)
          shift
          ;;
      esac
    done

    # Check Root/Sudo Privileges
    if [ "$EUID" -ne 0 ]; then
      echo -e "${C_RED}[-] Error: This installer requires root privileges.${C_RESET}"
      echo -e "${C_YELLOW}    Please run with sudo:${C_RESET} ${C_BOLD}sudo $0${C_RESET}"
      return 1
    fi

    # Detect actual invoking user (for home directory configuration)
    local TARGET_USER="${SUDO_USER:-$USER}"
    local TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "$HOME")"

    # ─── UNINSTALLATION ROUTINE ──────────────────────────────────────────────
    if [ $DO_UNINSTALL -eq 1 ]; then
        echo -e "\n${C_CYAN}==========================================================${C_RESET}"
        echo -e "${C_BOLD}  Uninstalling SS-CAM Desktop Suite...${C_RESET}"
        echo -e "${C_CYAN}==========================================================${C_RESET}\n"

        if [ $UNATTENDED -eq 0 ]; then
            prompt_input "${C_YELLOW}Are you sure you want to remove SS-CAM from this system? [y/N]: ${C_RESET}" "n" confirm_uninst
            if [[ ! "$confirm_uninst" =~ ^[Yy]$ ]]; then
                echo -e "${C_DIM}Uninstallation cancelled.${C_RESET}"
                return 0
            fi
        fi

        echo -e "${C_YELLOW}[*] Removing application files from $INSTALL_DIR...${C_RESET}"
        rm -rf "$INSTALL_DIR"

        echo -e "${C_YELLOW}[*] Removing CLI launcher $BIN_LINK...${C_RESET}"
        rm -f "$BIN_LINK"

        echo -e "${C_YELLOW}[*] Removing desktop menu entry...${C_RESET}"
        rm -f "$DESKTOP_DIR/ss-cam.desktop"
        rm -f "$ICON_SCALABLE_DIR/ss-cam.svg"
        rm -f "$ICON_256_DIR/ss-cam.png"

        if command -v update-desktop-database &> /dev/null; then
            update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
        fi
        if command -v gtk-update-icon-cache &> /dev/null; then
            gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
        fi

        echo -e "${C_GREEN}✔ [SUCCESS] SS-CAM has been cleanly removed from this system.${C_RESET}\n"
        return 0
    fi

    # ─── WELCOME BANNER ──────────────────────────────────────────────────────
    echo -e "${C_BLUE}══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}   ____ ____      ____    _    __  __ ${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}  / ___/ ___|    / ___|  / \  |  \/  |${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}  \___ \___ \   | |     / _ \ | |\/| |${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}   ___) |__) |  | |___ / ___ \| |  | |${C_RESET}"
    echo -e "${C_CYAN}${C_BOLD}  |____/____/    \____/_/   \_\_|  |_|${C_RESET}"
    echo -e "${C_BLUE}══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "  ${C_BOLD}SuamiSihat™ Creative Assets Management${C_RESET} — ${C_GREEN}v${VERSION} (Linux)${C_RESET}"
    echo -e "  ${C_DIM}Native Avalonia UI Desktop Suite for Fedora, Ubuntu & Arch${C_RESET}"
    echo -e "${C_BLUE}══════════════════════════════════════════════════════════════${C_RESET}\n"

    local INSTALL_MODE=1
    local SETUP_DESKTOP="Y"
    local SETUP_CLI="Y"
    local SETUP_SYNOLOGY="Y"
    local LAUNCH_NOW="Y"

    if [ -n "$CUSTOM_DIR" ]; then
        INSTALL_DIR="$CUSTOM_DIR"
    fi

    # ─── INTERACTIVE MENU ────────────────────────────────────────────────────
    local IS_INTERACTIVE=0
    if [ -c /dev/tty ] || [ -t 0 ]; then
        IS_INTERACTIVE=1
    fi

    if [ $UNATTENDED -eq 0 ] && [ $FORCE_BUILD -eq 0 ] && [ $IS_INTERACTIVE -eq 1 ]; then
        echo -e "${C_BOLD}Select Installation Mode:${C_RESET}"
        echo -e "  ${C_GREEN}[1] Express Install (Recommended)${C_RESET} — Fast download pre-compiled native desktop binary"
        echo -e "  ${C_CYAN}[2] Custom Directory Install${C_RESET}     — Choose custom destination path"
        echo -e "  ${C_YELLOW}[3] Build from Source (.NET SDK)${C_RESET} — Compile locally via dotnet publish"
        echo -e "  ${C_RED}[4] Uninstall SS-CAM${C_RESET}             — Cleanly remove SS-CAM from system"
        echo -e "  ${C_DIM}[5] Exit / Cancel${C_RESET}"
        echo ""

        local choice="1"
        prompt_input "${C_CYAN}Enter choice [1-5, default: 1]: ${C_RESET}" "1" choice

        case "$choice" in
            1)
                INSTALL_MODE=1
                ;;
            2)
                INSTALL_MODE=2
                local user_dir=""
                prompt_input "\n${C_BOLD}Enter custom installation directory [default: /opt/ss-cam]: ${C_RESET}" "$DEFAULT_INSTALL_DIR" user_dir
                INSTALL_DIR="${user_dir:-$DEFAULT_INSTALL_DIR}"
                ;;
            3)
                INSTALL_MODE=3
                ;;
            4)
                DO_UNINSTALL=1
                # Re-run uninstaller
                rm -rf "$INSTALL_DIR" "$BIN_LINK" "$DESKTOP_DIR/ss-cam.desktop" "$ICON_SCALABLE_DIR/ss-cam.svg"
                echo -e "${C_GREEN}✔ SS-CAM uninstalled successfully.${C_RESET}"
                return 0
                ;;
            5|q|Q)
                echo -e "${C_YELLOW}Installation cancelled.${C_RESET}"
                return 0
                ;;
            *)
                INSTALL_MODE=1
                ;;
        esac

        echo ""
        echo -e "${C_BOLD}Configuration Preferences:${C_RESET}"
        prompt_input "  Add Desktop Application shortcut (GNOME/KDE/XFCE)? [${C_GREEN}Y${C_RESET}/n]: " "Y" SETUP_DESKTOP
        prompt_input "  Create CLI command '${C_CYAN}ss-cam${C_RESET}' in /usr/local/bin? [${C_GREEN}Y${C_RESET}/n]: " "Y" SETUP_CLI
        prompt_input "  Verify local Synology Drive vault directory (~/SynologyDrive/Creative-Team)? [${C_GREEN}Y${C_RESET}/n]: " "Y" SETUP_SYNOLOGY
    fi

    if [ $FORCE_BUILD -eq 1 ]; then
        INSTALL_MODE=3
    fi

    echo -e "\n${C_BLUE}──────────────────────────────────────────────────────────────${C_RESET}"
    echo -e "${C_BOLD}Starting SS-CAM v${VERSION} Installation to:${C_RESET} ${C_CYAN}${INSTALL_DIR}${C_RESET}"
    echo -e "${C_BLUE}──────────────────────────────────────────────────────────────${C_RESET}\n"

    # 1. Create Target Directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$ICON_SCALABLE_DIR"
    mkdir -p "$ICON_256_DIR"
    mkdir -p "$DESKTOP_DIR"

    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
    local REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || echo "")"
    local INSTALLED=0

    # 2. Execute Selected Install Mode
    if [ $INSTALL_MODE -eq 3 ]; then
        echo -e "${C_YELLOW}[1/4] Building native Linux Avalonia desktop binary from source (.NET SDK)...${C_RESET}"
        if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/src/SS-CAM.Linux/SS-CAM.Linux.csproj" ] && command -v dotnet &> /dev/null; then
            dotnet publish "$REPO_ROOT/src/SS-CAM.Linux/SS-CAM.Linux.csproj" \
                -c Release \
                -r linux-x64 \
                --self-contained true \
                -p:PublishSingleFile=true \
                -p:IncludeNativeLibrariesForSelfExtract=true \
                -o "$INSTALL_DIR"
            INSTALLED=1
        else
            echo -e "${C_YELLOW}[*] Cloning repository to build from source...${C_RESET}"
            if command -v dotnet &> /dev/null && command -v git &> /dev/null; then
                local TMP_BUILD_DIR="/tmp/ss-cam-build-$$"
                mkdir -p "$TMP_BUILD_DIR"
                git clone --depth 1 https://github.com/SuamiSihat/ss_cam.git "$TMP_BUILD_DIR"
                dotnet publish "$TMP_BUILD_DIR/src/SS-CAM.Linux/SS-CAM.Linux.csproj" \
                    -c Release \
                    -r linux-x64 \
                    --self-contained true \
                    -p:PublishSingleFile=true \
                    -p:IncludeNativeLibrariesForSelfExtract=true \
                    -o "$INSTALL_DIR"
                rm -rf "$TMP_BUILD_DIR"
                INSTALLED=1
            else
                echo -e "${C_RED}[-] Error: .NET SDK and Git are required for source builds.${C_RESET}"
                echo -e "${C_YELLOW}    Falling back to pre-compiled binary download...${C_RESET}"
                INSTALL_MODE=1
            fi
        fi
    fi

    if [ $INSTALLED -eq 0 ]; then
        if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/dist/SS-CAM-v${VERSION}-linux-x64.tar.gz" ]; then
            echo -e "${C_YELLOW}[1/4] Extracting local release archive (${REPO_ROOT}/dist/SS-CAM-v${VERSION}-linux-x64.tar.gz)...${C_RESET}"
            tar -xzf "$REPO_ROOT/dist/SS-CAM-v${VERSION}-linux-x64.tar.gz" -C "$INSTALL_DIR"
            INSTALLED=1
        else
            echo -e "${C_YELLOW}[1/4] Downloading pre-compiled standalone native binary from GitHub Releases...${C_RESET}"
            local TEMP_TAR="/tmp/ss-cam-linux-x64.tar.gz"
            
            if curl -fL --progress-bar --connect-timeout 15 -o "$TEMP_TAR" "$RELEASE_TAR_URL" 2>/dev/null; then
                echo -e "${C_GREEN}✔ Downloaded SS-CAM v${VERSION} package.${C_RESET}"
            elif curl -fL --progress-bar --connect-timeout 15 -o "$TEMP_TAR" "$FALLBACK_TAR_URL" 2>/dev/null; then
                echo -e "${C_GREEN}✔ Downloaded SS-CAM fallback package.${C_RESET}"
            else
                echo -e "${C_RED}[-] Direct download failed from GitHub Releases.${C_RESET}"
            fi

            if [ -f "$TEMP_TAR" ]; then
                echo -e "${C_YELLOW}[*] Extracting binaries to ${INSTALL_DIR}...${C_RESET}"
                tar -xzf "$TEMP_TAR" -C "$INSTALL_DIR"
                rm -f "$TEMP_TAR"
                INSTALLED=1
            fi
        fi
    fi

    # Ensure executable permissions on main binary
    if [ -f "$INSTALL_DIR/SS-CAM.Linux" ]; then
        chmod +x "$INSTALL_DIR/SS-CAM.Linux"
        echo -e "${C_GREEN}✔ [2/4] Native binary configured at $INSTALL_DIR/SS-CAM.Linux${C_RESET}"
    else
        echo -e "${C_RED}[-] Warning: Executable not found at $INSTALL_DIR/SS-CAM.Linux${C_RESET}"
    fi

    # 3. Setup Brand Application Vector Icons
    echo -e "${C_YELLOW}[3/4] Installing official vector brand icons...${C_RESET}"
    if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/installer/assets/ss-cam.svg" ]; then
        cp -f "$REPO_ROOT/installer/assets/ss-cam.svg" "$ICON_SCALABLE_DIR/ss-cam.svg"
    elif [ -f "$INSTALL_DIR/ss-cam.svg" ]; then
        cp -f "$INSTALL_DIR/ss-cam.svg" "$ICON_SCALABLE_DIR/ss-cam.svg"
    else
        curl -fsSL "$ICON_URL" -o "$ICON_SCALABLE_DIR/ss-cam.svg" 2>/dev/null || true
    fi
    chmod 644 "$ICON_SCALABLE_DIR/ss-cam.svg" 2>/dev/null || true

    # 4. Configure CLI Launcher & Desktop Shortcuts
    echo -e "${C_YELLOW}[4/4] Configuring system launchers...${C_RESET}"

    if [[ "$SETUP_CLI" =~ ^[Yy]$ ]]; then
        cat << EOF > "$BIN_LINK"
#!/usr/bin/env bash
if [ -f "$INSTALL_DIR/SS-CAM.Linux" ]; then
    exec "$INSTALL_DIR/SS-CAM.Linux" "\$@"
else
    echo "[-] Error: SS-CAM binary not found at $INSTALL_DIR/SS-CAM.Linux"
    exit 1
fi
EOF
        chmod +x "$BIN_LINK"
        echo -e "${C_GREEN}✔ Registered terminal command: ${C_BOLD}${BIN_LINK}${C_RESET}"
    fi

    if [[ "$SETUP_DESKTOP" =~ ^[Yy]$ ]]; then
        cat << EOF > "$DESKTOP_DIR/ss-cam.desktop"
[Desktop Entry]
Name=${DISPLAY_NAME}
GenericName=Creative Assets Management
Comment=SuamiSihat Creative Team Desktop App for Linux
Exec=${BIN_LINK}
Icon=ss-cam
Terminal=false
Type=Application
Categories=Graphics;Office;Development;AudioVideo;
StartupWMClass=SS-CAM.Linux
Keywords=SuamiSihat;Creative;DAM;Synology;Assets;
EOF
        chmod 644 "$DESKTOP_DIR/ss-cam.desktop"
        echo -e "${C_GREEN}✔ Registered desktop application menu entry: ${C_BOLD}ss-cam.desktop${C_RESET}"
    fi

    # Refresh caches
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache &> /dev/null; then
        gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
    fi

    # 5. Synology Drive Workspace Integration Check
    if [[ "$SETUP_SYNOLOGY" =~ ^[Yy]$ ]] && [ -n "$TARGET_HOME" ]; then
        local SYNOLOGY_DIR="$TARGET_HOME/SynologyDrive/Creative-Team"
        if [ ! -d "$SYNOLOGY_DIR" ]; then
            mkdir -p "$SYNOLOGY_DIR" 2>/dev/null || true
            chown -R "$TARGET_USER:" "$TARGET_HOME/SynologyDrive" 2>/dev/null || true
            echo -e "${C_GREEN}✔ Initialized local workspace directory: ${C_BOLD}${SYNOLOGY_DIR}${C_RESET}"
        else
            echo -e "${C_GREEN}✔ Found existing Synology Drive vault at: ${C_BOLD}${SYNOLOGY_DIR}${C_RESET}"
        fi
    fi

    # ─── SUCCESS SUMMARY ─────────────────────────────────────────────────────
    echo -e "\n${C_GREEN}══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_GREEN}${C_BOLD}  ✔ SS-CAM v${VERSION} Linux Desktop Successfully Installed!${C_RESET}"
    echo -e "${C_GREEN}══════════════════════════════════════════════════════════════${C_RESET}"
    echo -e "  • ${C_BOLD}Desktop Launcher${C_RESET} : Applications Menu ➔ ${DISPLAY_NAME}"
    echo -e "  • ${C_BOLD}Terminal Command${C_RESET} : ${C_CYAN}ss-cam${C_RESET}"
    echo -e "  • ${C_BOLD}Install Location${C_RESET} : ${INSTALL_DIR}/SS-CAM.Linux"
    echo -e "  • ${C_BOLD}Local Workspace ${C_RESET} : ${TARGET_HOME}/SynologyDrive/Creative-Team"
    echo -e "${C_GREEN}══════════════════════════════════════════════════════════════${C_RESET}\n"

    if [ $UNATTENDED -eq 0 ] && [ $IS_INTERACTIVE -eq 1 ]; then
        prompt_input "${C_CYAN}Would you like to launch SS-CAM now? [Y/n]: ${C_RESET}" "Y" LAUNCH_NOW
        if [[ "$LAUNCH_NOW" =~ ^[Yy]$ ]]; then
            echo -e "${C_GREEN}Launching SS-CAM...${C_RESET}"
            if [ -n "$SUDO_USER" ]; then
                sudo -u "$SUDO_USER" "$INSTALL_DIR/SS-CAM.Linux" &>/dev/null &
            else
                "$INSTALL_DIR/SS-CAM.Linux" &>/dev/null &
            fi
        fi
    fi
}

main "$@"
