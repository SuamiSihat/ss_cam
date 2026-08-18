#!/usr/bin/env bash
# ==============================================================================
# SS-CAM Linux Native Installer & Launcher Setup
# Supported: Fedora, Ubuntu, Debian, Arch Linux, Pop!_OS
# ==============================================================================

set -e

APP_NAME="ss-cam"
DISPLAY_NAME="SuamiSihat Creative Assets Management"
VERSION="4.0.0"
INSTALL_DIR="/opt/ss-cam"
BIN_LINK="/usr/local/bin/ss-cam"
DESKTOP_DIR="/usr/share/applications"
ICON_DIR="/usr/share/icons/hicolor/scalable/apps"

echo "=========================================================="
echo "  Installing SS-CAM v${VERSION} on Linux Workstation..."
echo "=========================================================="

# Check root/sudo
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root or with sudo: sudo ./install-linux.sh"
  exit 1
fi

# 1. Create installation directory
mkdir -p "$INSTALL_DIR"
mkdir -p "$ICON_DIR"

# 2. Check if running from local repo or remote
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$REPO_ROOT/src/SS-CAM.Linux/SS-CAM.Linux.csproj" ]; then
    echo "[+] Building native Linux binary from local source (.NET)..."
    if command -v dotnet &> /dev/null; then
        dotnet publish "$REPO_ROOT/src/SS-CAM.Linux/SS-CAM.Linux.csproj" \
            -c Release \
            -r linux-x64 \
            --self-contained true \
            -p:PublishSingleFile=true \
            -o "$INSTALL_DIR"
    else
        echo "[-] .NET SDK not found. Installing web companion launcher..."
    fi
fi

# 3. Create CLI Launcher Wrapper
cat << 'EOF' > "$BIN_LINK"
#!/usr/bin/env bash
if [ -f "/opt/ss-cam/SS-CAM.Linux" ]; then
    exec /opt/ss-cam/SS-CAM.Linux "$@"
else
    echo "Launching SuamiSihat Creative Management Portal..."
    xdg-open "https://creative.suamisihat.myds.me" || sensible-browser "https://creative.suamisihat.myds.me"
fi
EOF

chmod +x "$BIN_LINK"

# 4. Create Desktop Application Launcher (.desktop entry)
cat << EOF > "$DESKTOP_DIR/ss-cam.desktop"
[Desktop Entry]
Name=${DISPLAY_NAME}
GenericName=Creative Assets Management
Comment=SuamiSihat Creative Team Companion & Project Manager
Exec=${BIN_LINK}
Icon=ss-cam
Terminal=false
Type=Application
Categories=Graphics;Office;Development;
StartupWMClass=SS-CAM.Linux
EOF

chmod 644 "$DESKTOP_DIR/ss-cam.desktop"

echo "=========================================================="
echo "  [SUCCESS] SS-CAM v${VERSION} installed successfully!"
echo "  - Terminal command: ss-cam"
echo "  - Desktop menu: Added to Applications menu"
echo "=========================================================="
