#!/bin/sh
#############################################
# AISubtitles Plugin Installer for Enigma2
# Version: 2.7
# Author: HAMDY_AHMED
############################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Script configuration
PLUGIN_NAME="AISubtitles"
VERSION="2.7"
GITHUB_RAW="https://raw.githubusercontent.com/Ham-ahmed/703/refs/heads/main"
PACKAGE_URL="${GITHUB_RAW}/${PLUGIN_NAME}-${VERSION}.tar.gz"
TEMP_DIR="/var/volatile/tmp"
PACKAGE="${TEMP_DIR}/${PLUGIN_NAME}-${VERSION}.tar.gz"
INSTALL_LOG="${TEMP_DIR}/${PLUGIN_NAME}_install.log"
ENIGMA2_PLUGINS_DIR="/usr/lib/enigma2/python/Plugins/Extensions"
PLUGIN_DIR="${ENIGMA2_PLUGINS_DIR}/${PLUGIN_NAME}"

# =======================================
# Function: Cleanup temporary files
# =======================================
cleanup() {
    rm -f "${PACKAGE}" 2>/dev/null
    rm -f "${TEMP_DIR}"/*.ipk "${TEMP_DIR}"/*.tar.gz 2>/dev/null
    rm -rf ./CONTROL ./control ./postinst ./preinst ./prerm ./postrm 2>/dev/null
    rm -f "${INSTALL_LOG}" 2>/dev/null
}

# ============================
# Function: Print banner
# ============================
print_banner() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}              ${PLUGIN_NAME} Plugin Installer v${VERSION}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ===========================================
# Function: Check internet connectivity
# ==========================================
check_internet() {
    echo -e "${BLUE}▶ Checking internet connection...${NC}"
    
    # Try to connect to GitHub using the downloader tool
    local connected=false
    
    if [ "${DOWNLOADER}" = "wget" ]; then
        if wget --spider --timeout=5 -q https://github.com; then
            connected=true
            echo -e "${GREEN}✓ Internet connection OK (GitHub reachable)${NC}"
        else
            echo -e "${YELLOW}⚠ GitHub not reachable, checking general internet...${NC}"
            if wget --spider --timeout=5 -q https://google.com; then
                connected=true
                echo -e "${GREEN}✓ Internet connection OK (Google reachable)${NC}"
            fi
        fi
    elif [ "${DOWNLOADER}" = "curl" ]; then
        if curl -s --head --connect-timeout 5 https://github.com >/dev/null 2>&1; then
            connected=true
            echo -e "${GREEN}✓ Internet connection OK (GitHub reachable)${NC}"
        else
            echo -e "${YELLOW}⚠ GitHub not reachable, checking general internet...${NC}"
            if curl -s --head --connect-timeout 5 https://google.com >/dev/null 2>&1; then
                connected=true
                echo -e "${GREEN}✓ Internet connection OK (Google reachable)${NC}"
            fi
        fi
    fi
    
    if [ "$connected" = false ]; then
        echo -e "${RED}✗ No internet connection detected${NC}"
        echo -e "${YELLOW}  Please check your network settings and try again${NC}"
        exit 1
    fi
}

# =======================================
# Function: Check system requirements
# ======================================
check_requirements() {
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}✗ This script must be run as root${NC}"
        exit 1
    fi
    
    # Check Enigma2 environment
    if [ ! -d "/usr/lib/enigma2" ]; then
        echo -e "${YELLOW}⚠ Warning: This doesn't appear to be an Enigma2 device${NC}"
        echo -e "${YELLOW}  Installation may fail${NC}"
        sleep 2
    fi
    
    # Check available disk space (need at least 10MB)
    AVAILABLE_SPACE=$(df /usr | awk 'NR==2 {print $4}')
    if [ "${AVAILABLE_SPACE}" -lt 10240 ]; then
        echo -e "${RED}✗ Insufficient disk space. Need at least 10MB${NC}"
        exit 1
    fi
    
    # Check for required download tools
    if command -v wget >/dev/null 2>&1; then
        DOWNLOADER="wget"
        echo -e "${GREEN}✓ Using wget for download${NC}"
    elif command -v curl >/dev/null 2>&1; then
        DOWNLOADER="curl"
        echo -e "${GREEN}✓ Using curl for download${NC}"
    else
        echo -e "${RED}✗ Neither wget nor curl found. Please install one.${NC}"
        exit 1
    fi
    
    # Check internet connectivity
    check_internet
}

# =============================================
# Function: Download package with progress
# =============================================
download_package() {
    echo -e "${BLUE}▶ Downloading ${PLUGIN_NAME} v${VERSION}...${NC}"
    
    # Create temp directory if it doesn't exist
    mkdir -p "${TEMP_DIR}"
    
    # Download based on available tool
    case "${DOWNLOADER}" in
        wget)
            # Check if URL exists
            if ! wget --spider --timeout=10 -q "${PACKAGE_URL}"; then
                echo -e "${RED}✗ Package URL not accessible${NC}"
                echo -e "${YELLOW}  URL: ${PACKAGE_URL}${NC}"
                exit 1
            fi
            
            echo -e "${YELLOW}  Download progress:${NC}"
            wget --no-check-certificate \
                 --timeout=20 \
                 --tries=3 \
                 --show-progress \
                 -O "${PACKAGE}" \
                 "${PACKAGE_URL}"
            ;;
            
        curl)
            # Check if URL exists
            if ! curl -s --head --connect-timeout 10 "${PACKAGE_URL}" | grep -q "200 OK"; then
                echo -e "${RED}✗ Package URL not accessible${NC}"
                echo -e "${YELLOW}  URL: ${PACKAGE_URL}${NC}"
                exit 1
            fi
            
            echo -e "${YELLOW}  Download progress:${NC}"
            curl -# -L -k --connect-timeout 20 --retry 3 -o "${PACKAGE}" "${PACKAGE_URL}"
            ;;
    esac
    
    # Verify download
    echo ""
    if [ ! -f "${PACKAGE}" ]; then
        echo -e "${RED}✗ Download failed - package not found${NC}"
        exit 1
    fi
    
    if [ ! -s "${PACKAGE}" ]; then
        echo -e "${RED}✗ Downloaded package is empty${NC}"
        rm -f "${PACKAGE}"
        exit 1
    fi
    
    # Verify it's a valid tar.gz file
    if ! tar -tzf "${PACKAGE}" >/dev/null 2>&1; then
        echo -e "${RED}✗ Downloaded file is not a valid tar.gz archive${NC}"
        rm -f "${PACKAGE}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Download completed successfully${NC}"
    echo -e "  📦 Package: $(basename ${PACKAGE})"
    echo -e "  📊 Size: $(du -h ${PACKAGE} | cut -f1)"
}

# ==============================
# Function: Remove old version
# ==============================
remove_old_version() {
    if [ -d "${PLUGIN_DIR}" ]; then
        echo -e "${YELLOW}⚠ Previous installation detected${NC}"
        echo -e "${BLUE}  Automatically removing old version...${NC}"
        
        # Backup any configuration if needed
        if [ -f "${PLUGIN_DIR}/etc/config.xml" ]; then
            mkdir -p "${TEMP_DIR}/${PLUGIN_NAME}_backup"
            cp -r "${PLUGIN_DIR}/etc" "${TEMP_DIR}/${PLUGIN_NAME}_backup/" 2>/dev/null
            echo -e "${BLUE}  Configuration backed up to ${TEMP_DIR}/${PLUGIN_NAME}_backup${NC}"
        fi
        
        # Remove old version
        rm -rf "${PLUGIN_DIR}"
        
        # Also remove from other possible locations
        rm -rf "/usr/lib/enigma2/python/Plugins/Extensions/${PLUGIN_NAME}" 2>/dev/null
        rm -rf "/home/root/${PLUGIN_NAME}" 2>/dev/null
        
        echo -e "${GREEN}✓ Old version removed successfully${NC}"
    fi
}

# ==============================
# Function: Install package
# ==============================
install_package() {
    echo -e "${BLUE}▶ Installing ${PLUGIN_NAME}...${NC}"
    
    # Remove any old version automatically
    remove_old_version
    
    # Create plugin directory if it doesn't exist
    mkdir -p "${ENIGMA2_PLUGINS_DIR}"
    
    # Extract package
    echo -e "${BLUE}▶ Extracting files...${NC}"
    if ! tar -xzf "${PACKAGE}" -C / > "${INSTALL_LOG}" 2>&1; then
        echo -e "${RED}✗ Extraction failed${NC}"
        echo -e "${YELLOW}  Error details:${NC}"
        cat "${INSTALL_LOG}"
        exit 1
    fi
    
    # Verify installation
    if [ ! -d "${PLUGIN_DIR}" ]; then
        echo -e "${RED}✗ Installation failed - plugin directory not created${NC}"
        echo -e "${YELLOW}  Expected: ${PLUGIN_DIR}${NC}"
        exit 1
    fi
    
    # Restore configuration if backup exists
    if [ -d "${TEMP_DIR}/${PLUGIN_NAME}_backup" ]; then
        echo -e "${BLUE}▶ Restoring configuration...${NC}"
        cp -r "${TEMP_DIR}/${PLUGIN_NAME}_backup/"* "${PLUGIN_DIR}/" 2>/dev/null
        rm -rf "${TEMP_DIR}/${PLUGIN_NAME}_backup"
        echo -e "${GREEN}✓ Configuration restored${NC}"
    fi
    
    # Set proper permissions
    echo -e "${BLUE}▶ Setting permissions...${NC}"
    find "${PLUGIN_DIR}" -type f -exec chmod 644 {} \;
    find "${PLUGIN_DIR}" -type d -exec chmod 755 {} \;
    
    # Make Python files executable
    find "${PLUGIN_DIR}" -name "*.py" -exec chmod 755 {} \;
    find "${PLUGIN_DIR}" -name "*.sh" -exec chmod 755 {} \;
    
    # Run post-install script if exists
    if [ -f "${PLUGIN_DIR}/postinst" ]; then
        echo -e "${BLUE}▶ Running post-installation script...${NC}"
        chmod 755 "${PLUGIN_DIR}/postinst"
        "${PLUGIN_DIR}/postinst"
    fi
    
    # Run any custom install script
    if [ -f "${PLUGIN_DIR}/install.sh" ]; then
        echo -e "${BLUE}▶ Running custom install script...${NC}"
        chmod 755 "${PLUGIN_DIR}/install.sh"
        "${PLUGIN_DIR}/install.sh"
    fi
    
    # Count installed files
    FILE_COUNT=$(find "${PLUGIN_DIR}" -type f | wc -l)
    echo -e "${GREEN}✓ Installation completed (${FILE_COUNT} files installed)${NC}"
}

# ==========================================
# Function: Display completion message
# ==========================================
show_completion() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           ✅ INSTALLATION SUCCESSFUL!                         ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}   Plugin:     ${CYAN}${PLUGIN_NAME}${NC}"
    echo -e "${WHITE}   Version:    ${CYAN}${VERSION}${NC}"
    echo -e "${WHITE}   Location:   ${YELLOW}${PLUGIN_DIR}${NC}"
    echo -e "${WHITE}   Files:      ${YELLOW}$(find ${PLUGIN_DIR} -type f | wc -l) files${NC}"
    echo -e "${WHITE}   Developer:  ${MAGENTA}HAMDY_AHMED${NC}"
    echo -e "${WHITE}   Facebook:   ${BLUE}https://www.facebook.com/share/g/18qCRuHz26/${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Show backup info if any
    if [ -d "${TEMP_DIR}/${PLUGIN_NAME}_backup" ]; then
        echo -e "${YELLOW}⚠ Backup folder exists at ${TEMP_DIR}/${PLUGIN_NAME}_backup${NC}"
        echo -e "${WHITE}  You can manually restore files from there if needed${NC}"
        echo ""
    fi
}

# ==============================
# Function: Restart Enigma2
# =============================
restart_enigma2() {
    echo -e "${YELLOW}⏳ Enigma2 will restart in 5 seconds...${NC}"
    echo -e "${WHITE}   Press Ctrl+C to cancel restart${NC}"
    
    # Countdown
    for i in 5 4 3 2 1; do
        echo -ne "\r${YELLOW}   Restarting in ${i} seconds...${NC} "
        sleep 1
    done
    echo ""
    
    echo -e "${BLUE}▶ Restarting Enigma2...${NC}"
    
    # Try different methods to restart Enigma2
    if command -v init >/dev/null 2>&1; then
        # Method 1: init (most common in Enigma2)
        echo -e "${BLUE}  Using init method...${NC}"
        init 4
        sleep 2
        init 3
    elif command -v systemctl >/dev/null 2>&1; then
        # Method 2: systemctl
        echo -e "${BLUE}  Using systemctl method...${NC}"
        systemctl restart enigma2
    elif command -v killall >/dev/null 2>&1; then
        # Method 3: killall
        echo -e "${BLUE}  Using killall method...${NC}"
        killall enigma2
    elif [ -f "/etc/init.d/enigma2" ]; then
        # Method 4: init script
        echo -e "${BLUE}  Using init script method...${NC}"
        /etc/init.d/enigma2 restart
    else
        # Method 5: wget to webif (if available)
        echo -e "${YELLOW}⚠ Could not restart automatically${NC}"
        echo -e "${WHITE}  Please restart Enigma2 manually:${NC}"
        echo -e "${WHITE}  - Using remote: Menu → Standby/Restart → Restart Enigma2${NC}"
        echo -e "${WHITE}  - Or via Telnet: killall enigma2${NC}"
        exit 0
    fi
}

# ===============================
# Main installation process
# ===============================
main() {
    # Set trap for cleanup
    trap cleanup EXIT INT TERM
    
    # Print banner
    print_banner
    
    # Run initial cleanup
    cleanup
    
    # Check requirements
    check_requirements
    
    # Download package
    download_package
    
    # Install package
    install_package
    
    # Show completion message
    show_completion
    
    # Restart Enigma2
    restart_enigma2
    
    exit 0
}

# =========================
# Execute main function
# ========================
main "$@"