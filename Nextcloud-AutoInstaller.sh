#!/bin/bash

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Error handling
set -o errexit
set -o pipefail

# Progress bar function
show_progress() {
    local duration=$1
    local status=$2
    local step=$((duration/100))
    local progress=0
    local bar_width=50

    echo -ne "\n"
    while [ $progress -le 100 ]; do
        local filled=$((progress*bar_width/100))
        local empty=$((bar_width-filled))
        
        # Color gradient based on progress
        if [ $progress -lt 33 ]; then
            COLOR=$YELLOW
        elif [ $progress -lt 66 ]; then
            COLOR=$CYAN
        else
            COLOR=$GREEN
        fi
        
        printf "\r[${COLOR}"
        printf "%${filled}s" | tr " " "#"    # Using # instead of Unicode blocks
        printf "${NC}"
        printf "%${empty}s" | tr " " "-"     # Using - instead of Unicode blocks
        printf "] ${COLOR}%3d%%${NC} " $progress
        
        case $status in
            "update") echo -ne "Updating system...            ";;
            "deps") echo -ne "Installing dependencies...     ";;
            "database") echo -ne "Configuring database...       ";;
            "download") echo -ne "Downloading Nextcloud...      ";;
            "webserver") echo -ne "Configuring web server...     ";;
            "final") echo -ne "Finalizing installation...    ";;
            *) echo -ne "Processing...                ";;
        esac
        
        sleep $step
        progress=$((progress+1))
    done
    echo -ne "\n\n"
}

# Log function
log() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Error function
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Get system IP address
get_system_ip() {
    local ip
    ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
    if [ -z "$ip" ]; then
        ip="localhost"
    fi
    echo $ip
}

# Generate random passwords
generate_passwords() {
    DB_ROOT_PASS=$(openssl rand -base64 12)
    DB_USER_PASS=$(openssl rand -base64 12)
    ADMIN_PASS=$(openssl rand -base64 12)
}

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        error "Unable to detect operating system"
    fi
}

# Function to check root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root"
    fi
}

# Function to check and create directories
create_directories() {
    local dirs=(
        "/var/www/html"
        "/etc/apache2/sites-available"
        "/etc/httpd/conf.d"
    )

    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" || error "Failed to create directory: $dir"
        fi
    done
}

# Function to install dependencies based on OS
install_dependencies() {
    log "Installing dependencies for $OS..."
    create_directories

    case $OS in
        "ubuntu"|"debian")
            apt-get update -qq &>/dev/null || error "Failed to update package lists"
            apt-get install -qq -y apache2 mariadb-server libapache2-mod-php \
                php-gd php-json php-mysql php-curl php-mbstring php-intl \
                php-imagick php-xml php-zip wget unzip bzip2 &>/dev/null || \
                error "Failed to install dependencies"
            ;;
        *)
            error "Unsupported operating system: $OS"
            ;;
    esac
}

# Function to configure database
configure_database() {
    log "Configuring database..."
    
    # Ensure MariaDB is running
    systemctl start mariadb
    systemctl enable mariadb

    # Create database and user
    mysql -e "CREATE DATABASE IF NOT EXISTS nextcloud;"
    mysql -e "CREATE USER IF NOT EXISTS 'nextcloud'@'localhost' IDENTIFIED BY '$DB_USER_PASS';"
    mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
}

# Function to download and extract Nextcloud
download_nextcloud() {
    log "Downloading Nextcloud..."
    cd /var/www/html || error "Failed to change directory to /var/www/html"
    
    wget -q https://download.nextcloud.com/server/releases/latest.tar.bz2 || \
        error "Failed to download Nextcloud"
    
    tar -xjf latest.tar.bz2 || error "Failed to extract Nextcloud"
    
    # Set correct permissions
    case $OS in
        "ubuntu"|"debian")
            chown -R www-data:www-data nextcloud
            ;;
    esac
    
    rm -f latest.tar.bz2
}

# Function to configure web server
configure_webserver() {
    log "Configuring web server..."
    
    case $OS in
        "ubuntu"|"debian")
            cat > /etc/apache2/sites-available/nextcloud.conf << EOF
<VirtualHost *:80>
    DocumentRoot /var/www/html/nextcloud
    ServerName localhost

    <Directory /var/www/html/nextcloud/>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
        SetEnv HOME /var/www/html/nextcloud
        SetEnv HTTP_HOME /var/www/html/nextcloud
    </Directory>
</VirtualHost>
EOF
            a2ensite nextcloud.conf
            a2enmod rewrite headers env dir mime
            systemctl restart apache2
            ;;
    esac
}

# Function to create installation details
create_install_details() {
    local SYSTEM_IP
    SYSTEM_IP=$(get_system_ip)
    
    cat > /root/nextcloud_details.txt << EOF
╔════════════════════════════════════════════╗
║        Nextcloud Installation Details      ║
╠════════════════════════════════════════════╣
║ URL: http://$SYSTEM_IP/nextcloud
║ Admin Username: admin
║ Admin Password: $ADMIN_PASS
║
║ Database Details:
║ Database Name: nextcloud
║ Database User: nextcloud
║ Database Password: $DB_USER_PASS
║
║ Operating System: $OS
║
║ Please save these credentials securely!
╚════════════════════════════════════════════╝
EOF
}

# Function to show menu
show_menu() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}      ${CYAN}Nextcloud Installation Menu${NC}     ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Detected OS: ${GREEN}$OS${NC}                  ${PURPLE}║${NC}"
    echo -e "${PURPLE}╠══════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} 1. Update and Upgrade System         ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC} 2. Install Nextcloud                 ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC} 3. View Installation Details         ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC} 4. Exit                              ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════╝${NC}"
}

# Function to update system
update_system() {
    log "Starting system update..."
    case $OS in
        "ubuntu"|"debian")
            apt-get update -qq &>/dev/null
            apt-get upgrade -y -qq &>/dev/null
            ;;
    esac
    show_progress 10 "update"
    log "System update completed!"
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to install Nextcloud
install_nextcloud() {
    log "Starting Nextcloud installation..."
    generate_passwords
    
    # Install dependencies
    install_dependencies
    show_progress 20 "deps"
    
    # Configure database
    configure_database
    show_progress 20 "database"
    
    # Download and extract Nextcloud
    download_nextcloud
    show_progress 20 "download"
    
    # Configure web server
    configure_webserver
    show_progress 20 "webserver"
    
    # Create installation details
    create_install_details
    show_progress 20 "final"
    
    log "Nextcloud installation completed successfully!"
    read -n 1 -s -r -p "Press any key to continue..."
}

# Function to view installation details
view_details() {
    if [ -f /root/nextcloud_details.txt ]; then
        clear
        cat /root/nextcloud_details.txt
    else
        error "Installation details not found. Please install Nextcloud first."
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}

# Main script
check_root
detect_os

# Main loop
while true; do
    show_menu
    read -p "Enter your choice [1-4]: " choice
    case $choice in
        1) update_system ;;
        2) install_nextcloud ;;
        3) view_details ;;
        4) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
    esac
done
