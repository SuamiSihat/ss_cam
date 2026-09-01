#!/usr/bin/env bash
# ==============================================================================
# SS-CAM Linux Native Desktop Application Installer & Launcher Setup
# Supported Distros: Fedora, Ubuntu, Debian, Arch Linux, Pop!_OS, RHEL
# ==============================================================================

set -e

APP_NAME="ss-cam"
DISPLAY_NAME="SuamiSihat Creative Assets Management"
VERSION="4.6.0"
INSTALL_DIR="/opt/ss-cam"
BIN_LINK="/usr/local/bin/ss-cam"
DESKTOP_DIR="/usr/share/applications"
ICON_SCALABLE_DIR="/usr/share/icons/hicolor/scalable/apps"
ICON_256_DIR="/usr/share/icons/hicolor/256x256/apps"

RELEASE_TAR_URL="https://github.com/SuamiSihat/ss_cam/releases/latest/download/SS-CAM-v${VERSION}-linux-x64.tar.gz"
FALLBACK_TAR_URL="https://github.com/SuamiSihat/ss_cam/releases/latest/download/ss-cam-linux-x64.tar.gz"
ICON_URL="https://raw.githubusercontent.com/SuamiSihat/ss_cam/SS-Master/installer/assets/ss-cam.svg"

echo "=========================================================="
echo "  Installing SS-CAM Native Linux Desktop v${VERSION}..."
echo "=========================================================="

# Check root/sudo
if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: Please run as root or with sudo: sudo ./install-linux.sh"
  exit 1
fi

# 1. Create target directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$ICON_SCALABLE_DIR"
mkdir -p "$ICON_256_DIR"
mkdir -p "$DESKTOP_DIR"

# 2. Check if running inside local git repo or downloading precompiled binary
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || echo "")"

INSTALLED=0

if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/src/SS-CAM.Linux/SS-CAM.Linux.csproj" ] && command -v dotnet &> /dev/null; then
    echo "[+] Building native Linux Avalonia desktop binary from local source (.NET)..."
    dotnet publish "$REPO_ROOT/src/SS-CAM.Linux/SS-CAM.Linux.csproj" \
        -c Release \
        -r linux-x64 \
        --self-contained true \
        -p:PublishSingleFile=true \
        -o "$INSTALL_DIR"
    INSTALLED=1
elif [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/dist/SS-CAM-v${VERSION}-linux-x64.tar.gz" ]; then
    echo "[+] Extracting local release archive ($REPO_ROOT/dist/SS-CAM-v${VERSION}-linux-x64.tar.gz)..."
    tar -xzf "$REPO_ROOT/dist/SS-CAM-v${VERSION}-linux-x64.tar.gz" -C "$INSTALL_DIR"
    INSTALLED=1
else
    echo "[+] Downloading pre-compiled native desktop binary from GitHub Releases..."
    TEMP_TAR="/tmp/ss-cam-linux-x64.tar.gz"
    
    if curl -fsSL --connect-timeout 15 -o "$TEMP_TAR" "$RELEASE_TAR_URL" 2>/dev/null; then
        echo "[+] Downloaded SS-CAM v${VERSION} release package."
    elif curl -fsSL --connect-timeout 15 -o "$TEMP_TAR" "$FALLBACK_TAR_URL" 2>/dev/null; then
        echo "[+] Downloaded SS-CAM fallback release package."
    else
        echo "[-] Direct release download failed. Attempting git source build if dotnet is installed..."
        if command -v dotnet &> /dev/null && command -v git &> /dev/null; then
            TMP_BUILD_DIR="/tmp/ss-cam-build-$$"
            mkdir -p "$TMP_BUILD_DIR"
            git clone --depth 1 https://github.com/SuamiSihat/ss_cam.git "$TMP_BUILD_DIR"
            dotnet publish "$TMP_BUILD_DIR/src/SS-CAM.Linux/SS-CAM.Linux.csproj" \
                -c Release \
                -r linux-x64 \
                --self-contained true \
                -p:PublishSingleFile=true \
                -o "$INSTALL_DIR"
            rm -rf "$TMP_BUILD_DIR"
            INSTALLED=1
        fi
    fi

    if [ -f "$TEMP_TAR" ] && [ $INSTALLED -eq 0 ]; then
        echo "[+] Extracting application binaries to $INSTALL_DIR..."
        tar -xzf "$TEMP_TAR" -C "$INSTALL_DIR"
        rm -f "$TEMP_TAR"
        INSTALLED=1
    fi
fi

# Ensure executable permissions
if [ -f "$INSTALL_DIR/SS-CAM.Linux" ]; then
    chmod +x "$INSTALL_DIR/SS-CAM.Linux"
else
    echo "[-] Warning: /opt/ss-cam/SS-CAM.Linux executable not found."
fi

# 3. Setup Brand Application Icon
if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/installer/assets/ss-cam.svg" ]; then
    cp -f "$REPO_ROOT/installer/assets/ss-cam.svg" "$ICON_SCALABLE_DIR/ss-cam.svg"
else
    curl -fsSL "$ICON_URL" -o "$ICON_SCALABLE_DIR/ss-cam.svg" 2>/dev/null || true
fi

# 4. Create Native Desktop CLI Launcher Wrapper
cat << 'EOF' > "$BIN_LINK"
#!/usr/bin/env bash
if [ -f "/opt/ss-cam/SS-CAM.Linux" ]; then
    exec /opt/ss-cam/SS-CAM.Linux "$@"
else
    echo "[-] Error: SS-CAM native desktop binary not found at /opt/ss-cam/SS-CAM.Linux"
    echo "[-] Please run: curl -fsSL https://raw.githubusercontent.com/SuamiSihat/ss_cam/SS-Master/installer/install-linux.sh | sudo bash"
    exit 1
fi
EOF

chmod +x "$BIN_LINK"

# 5. Create Desktop Application Launcher (.desktop entry for GNOME / KDE / XFCE)
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

# Refresh icon & desktop caches if tools exist
if command -v gtk-update-icon-cache &> /dev/null; then
    gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v update-desktop-database &> /dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi

echo "=========================================================="
echo "  [SUCCESS] SS-CAM Native Desktop App v${VERSION} installed!"
echo "  - Terminal command : ss-cam"
echo "  - Desktop App Menu : Added to Applications (Graphics/Office)"
echo "  - Target Binary    : /opt/ss-cam/SS-CAM.Linux"
echo "=========================================================="
