#!/bin/bash

# Add log file for debugging in headless environments
LOGFILE="/var/log/nextcloud_install.log"
exec > >(tee -a $LOGFILE) 2>&1

echo "Starting Nextcloud installation script at $(date)" | tee -a $LOGFILE

# Network connectivity check
echo "Checking for network connectivity..."
MAX_RETRIES=20
RETRY_INTERVAL=15
RETRY_COUNT=0

check_network() {
    # Try multiple reliable domains
    for domain in google.com github.com cloudflare.com; do
        if ping -c1 -W3 $domain &>/dev/null; then
            return 0
        fi
    done
    return 1
}

while ! check_network; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Network connectivity could not be established after $MAX_RETRIES attempts. Exiting."
        exit 1
    fi
    echo "Waiting for network connectivity... (Attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

echo "Network connectivity established. Proceeding with installation..."

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
            "config") echo -ne "Setting up Nextcloud config...  ";;
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

# Function to detect OS with retry mechanism
detect_os() {
    local max_tries=5
    local try=1
    
    while [ $try -le $max_tries ]; do
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            VERSION_ID=$VERSION_ID
            echo "Detected OS: $OS $VERSION_ID"
            return 0
        else
            echo "OS detection attempt $try failed, retrying in 5 seconds..."
            sleep 5
            try=$((try+1))
        fi
    done
    
    error "Unable to detect operating system after multiple attempts"
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
    
    # Wait for package manager to be available
    log "Waiting for package manager to be available..."
    
    case $OS in
        "ubuntu"|"debian")
            # Wait for apt to be available (no other process using it)
            for i in {1..30}; do
                if ! fuser /var/lib/dpkg/lock >/dev/null 2>&1 && \
                   ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && \
                   ! fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
                    break
                fi
                log "Package manager is busy. Waiting... ($i/30)"
                sleep 10
            done
            
            # Update package lists with retry mechanism
            for i in {1..5}; do
                log "Updating package lists (attempt $i/5)..."
                if apt-get update -qq; then
                    break
                fi
                sleep 10
            done
            
            # Install packages with retry mechanism
            log "Installing required packages..."
            for i in {1..5}; do
                if apt-get install -qq -y apache2 mariadb-server libapache2-mod-php \
                    php-gd php-json php-mysql php-curl php-mbstring php-intl \
                    php-imagick php-xml php-zip wget unzip bzip2; then
                    break
                fi
                log "Package installation failed. Retrying in 10 seconds... (attempt $i/5)"
                sleep 10
            done
            ;;
        *)
            error "Unsupported operating system: $OS"
            ;;
    esac
}

# Function to configure database
configure_database() {
    log "Configuring database..."
    
    # Ensure MariaDB is installed and ready
    log "Waiting for MariaDB service to be available..."
    local retries=0
    local max_retries=30
    
    # Wait for MariaDB to be installed fully
    while [ $retries -lt $max_retries ]; do
        if command -v mysql &>/dev/null; then
            break
        fi
        log "Waiting for MySQL/MariaDB to be installed... ($retries/$max_retries)"
        sleep 5
        retries=$((retries+1))
    done
    
    if [ $retries -eq $max_retries ]; then
        error "MySQL/MariaDB installation timed out"
    fi
    
    # Ensure MariaDB is running
    log "Starting MariaDB service..."
    systemctl start mariadb || error "Failed to start MariaDB service"
    
    # Wait for MariaDB to be ready
    retries=0
    while [ $retries -lt $max_retries ]; do
        if mysqladmin ping &>/dev/null; then
            break
        fi
        log "Waiting for MariaDB to be ready... ($retries/$max_retries)"
        sleep 5
        retries=$((retries+1))
    done
    
    if [ $retries -eq $max_retries ]; then
        error "MariaDB did not become ready in time"
    fi
    
    log "Enabling MariaDB at startup..."
    systemctl enable mariadb
    
    # Create database and user
    log "Creating Nextcloud database and user..."
    if ! mysql -e "CREATE DATABASE IF NOT EXISTS nextcloud;"; then
        error "Failed to create database"
    fi
    
    if ! mysql -e "CREATE USER IF NOT EXISTS 'nextcloud'@'localhost' IDENTIFIED BY '$DB_USER_PASS';"; then
        error "Failed to create database user"
    fi
    
    if ! mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';"; then
        error "Failed to grant privileges to database user"
    fi
    
    if ! mysql -e "FLUSH PRIVILEGES;"; then
        error "Failed to flush privileges"
    fi
    
    log "Database configuration completed successfully"
}

# Function to download and extract Nextcloud
download_nextcloud() {
    log "Downloading Nextcloud..."
    cd /var/www || error "Failed to change directory to /var/www"
    
    # Backup any existing html directory
    if [ -d "html" ] && [ "$(ls -A html)" ]; then
        log "Backing up existing web root directory..."
        mv html html_backup_$(date +%Y%m%d%H%M%S)
    fi
    
    # Create fresh html directory
    mkdir -p html
    cd html || error "Failed to change directory to /var/www/html"
    
    # Download with retry mechanism
    log "Downloading Nextcloud package..."
    local downloaded=false
    local max_retries=5
    local retry=0
    
    while [ "$downloaded" = false ] && [ $retry -lt $max_retries ]; do
        if wget -q https://download.nextcloud.com/server/releases/latest.tar.bz2; then
            downloaded=true
            log "Download successful"
        else
            retry=$((retry+1))
            log "Download failed. Retrying in 10 seconds... (Attempt $retry/$max_retries)"
            sleep 10
        fi
    done
    
    if [ "$downloaded" = false ]; then
        error "Failed to download Nextcloud after multiple attempts"
    fi
    
    log "Extracting Nextcloud package..."
    if ! tar -xjf latest.tar.bz2; then
        error "Failed to extract Nextcloud package"
    fi
    
    # Move all files from nextcloud directory to html (web root)
    log "Moving Nextcloud files to web root..."
    mv nextcloud/* .
    mv nextcloud/.* . 2>/dev/null || true  # Move hidden files too, ignore errors
    rmdir nextcloud  # Remove the now empty nextcloud directory
    
    # Set correct permissions
    log "Setting proper file permissions..."
    chown -R www-data:www-data .
    
    rm -f latest.tar.bz2
    log "Nextcloud files successfully prepared"
}

# Function to configure web server
configure_webserver() {
    log "Configuring web server..."
    
    # Get system IP for virtual host configuration
    SYSTEM_IP=$(get_system_ip)
    
    case $OS in
        "ubuntu"|"debian")
            cat > /etc/apache2/sites-available/nextcloud.conf << EOF
<VirtualHost *:80>
    DocumentRoot /var/www/html
    ServerName $SYSTEM_IP
    ServerAlias localhost

    <Directory /var/www/html/>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
        SetEnv HOME /var/www/html
        SetEnv HTTP_HOME /var/www/html
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog \${APACHE_LOG_DIR}/nextcloud_access.log combined
</VirtualHost>
EOF
            a2ensite nextcloud.conf
            a2enmod rewrite headers env dir mime
            systemctl restart apache2
            ;;
        *)
            error "Unsupported operating system for web server configuration."
            ;;
    esac
}

# Function to install Nextcloud via CLI
install_nextcloud() {
    log "Installing Nextcloud via command line..."
    
    SYSTEM_IP=$(get_system_ip)
    
    cd /var/www/html || error "Failed to change directory to Nextcloud directory"

    # Use the occ command to install Nextcloud
    sudo -u www-data php occ maintenance:install \
        --database "mysql" \
        --database-name "nextcloud" \
        --database-user "nextcloud" \
        --database-pass "$DB_USER_PASS" \
        --admin-user "admin" \
        --admin-pass "$ADMIN_PASS"
    
    # Add trusted domains configuration 
    sudo -u www-data php occ config:system:set trusted_domains 1 --value="$SYSTEM_IP"
    
    # Set the overwrite.cli.url
    sudo -u www-data php occ config:system:set overwrite.cli.url --value="http://$SYSTEM_IP"
    
    # Disable the app recommendations page that's causing the redirect
    sudo -u www-data php occ app:disable recommendedapps
    
    # Ensure proper permissions on config directory
    chown -R www-data:www-data /var/www/html/config/
}

# Function to apply additional configurations
apply_additional_configs() {
    log "Applying additional configurations..."
    
    SYSTEM_IP=$(get_system_ip)
    
    # Ensure config directory exists
    if [ ! -d "/var/www/html/config" ]; then
        mkdir -p /var/www/html/config
        chown -R www-data:www-data /var/www/html/config
    fi
    
    # Update .htaccess file for proper redirects
    if [ -f "/var/www/html/.htaccess" ]; then
        chown www-data:www-data /var/www/html/.htaccess
        chmod 644 /var/www/html/.htaccess
    fi
    
    # Set the correct protocol
    sudo -u www-data php /var/www/html/occ config:system:set overwriteprotocol --value="http"
}

# Function to create installation details
create_install_details() {
    local SYSTEM_IP
    SYSTEM_IP=$(get_system_ip)
    
    cat > /root/nextcloud_details.txt << EOF
╔════════════════════════════════════════════╗
║        Nextcloud Installation Details      ║
╠════════════════════════════════════════════╣
║ URL: http://$SYSTEM_IP
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

    log "Nextcloud installation completed successfully!"
    log "Access it at http://$SYSTEM_IP with the following credentials:"
    log "Username: admin"
    log "Password: $ADMIN_PASS"
    log "(These details are also saved in /root/nextcloud_details.txt)"
}

# Main script start
{
    log "=== Nextcloud Installation Script Started ==="
    log "Current date/time: $(date)"
    
    # Record start time for overall execution timing
    SCRIPT_START_TIME=$(date +%s)
    
    check_root
    detect_os
    
    # Start the installation process
    generate_passwords
    install_dependencies
    show_progress 15 "deps"
    configure_database
    show_progress 15 "database"
    download_nextcloud
    show_progress 15 "download"
    configure_webserver
    show_progress 15 "webserver"
    install_nextcloud
    show_progress 20 "config"
    apply_additional_configs
    show_progress 10 "config"
    create_install_details
    show_progress 10 "final"
    
    # Display final message with system IP
    SYSTEM_IP=$(get_system_ip)
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                Nextcloud Installation Complete!                    ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Access your Nextcloud at: ${CYAN}http://$SYSTEM_IP${NC}"
    echo -e "${GREEN}║${NC} Username: ${CYAN}admin${NC}"
    echo -e "${GREEN}║${NC} Password: ${CYAN}$ADMIN_PASS${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    
    # Record end time and calculate total execution time
    SCRIPT_END_TIME=$(date +%s)
    TOTAL_RUNTIME=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
    log "=== Nextcloud Installation Script Completed ==="
    log "Total execution time: $(printf '%dh:%dm:%ds\n' $(($TOTAL_RUNTIME/3600)) $(($TOTAL_RUNTIME%3600/60)) $(($TOTAL_RUNTIME%60)))"
    log "Installation log saved to: $LOGFILE"
    
    # Create a successful installation marker
    touch /var/nextcloud_install_success
} || {
    # This block executes if any command in the main block fails
    log "=== Nextcloud Installation Failed ==="
    log "Please check the log file at $LOGFILE for details"
    touch /var/nextcloud_install_failed
}
