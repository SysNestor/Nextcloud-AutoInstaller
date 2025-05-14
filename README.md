# Nextcloud Automated Installation Script

This repository provides a Bash script that automates Nextcloud installation and configuration on Ubuntu/Debian systems. It covers system updates, dependency installation, database setup, web server configuration, and initial deployment—all with robust error handling, headless logging, and visual progress indicators.

> **Suggestion:** Consider adding support matrix for tested OS versions (e.g., Ubuntu 18.04/20.04/22.04,24.04, Debian 10/11/12).

## Table of Contents

* [Features](#features)
* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Usage](#usage)
* [Workflow](#workflow)
* [Logging](#logging)
* [Configuration](#configuration)
* [Customization](#customization)
* [Troubleshooting](#troubleshooting)
* [Security](#security)
* [Contributing](#contributing)
* [License](#license)

## Features

* **Automated Dependency Installation**: Installs Apache, MariaDB, PHP (and extensions) with retry logic and lock handling.
* **Database Setup**: Creates a dedicated Nextcloud database and user with secure, randomized passwords.
* **Web Server Configuration**: Generates and enables an Apache virtual host, sets permissions, and restarts the service.
* **Nextcloud Deployment**: Downloads the latest release, extracts files to `/var/www/html`, and runs the `occ` installer.
* **Progress Indicators**: Shows colored progress bars for dependencies, database, download, webserver, and configuration stages.
* **Comprehensive Logging**: Captures all output to `/var/log/nextcloud_install.log` for easier troubleshooting.
* **Retry Mechanisms**: Includes retries for network checks, package installs, downloads, and service startups.
* **OS Detection**: Automatically detects Debian-based distributions and exits if unsupported.

## Prerequisites

* **OS**: Ubuntu 18.04/20.04/22.04/24.04 or Debian 10/11/12.
* **Privileges**: Run as `root` or via `sudo`.
* **Network**: Active internet connection for package and archive retrieval.
* **Tools**: Bash, `wget`, `openssl`, `tar`, `ip`, and `ping` (commonly preinstalled).

> **Suggestion:** If you intend to use a custom domain or SSL, note it here or link to a separate SSL guide.

## Installation

```bash
git clone https://github.com/SysNestor/Nextcloud-AutoInstaller.git
cd Nextcloud-AutoInstaller
chmod +x Nextcloud-AutoInstaller.sh
sudo ./Nextcloud-AutoInstaller.sh
```

Logs are saved to `/var/log/nextcloud_install.log`.

## Usage

* **First Run**: Executes full installation with randomized credentials.
* **Re-run**: After resolving any errors, executing again regenerates credentials and repeats setup.
* **Access**: Visit `http://<server-ip>/` using the generated admin user.

> **Suggestion:** Clarify that re-running will overwrite existing credentials and data needs backup.

## Workflow

1. **Root Check**: Ensures script is run with root privileges.
2. **OS Detection**: Reads `/etc/os-release` to identify Ubuntu/Debian.
3. **Network Validation**: Pings multiple domains with retry logic.
4. **Password Generation**: Creates random base64 passwords for DB root, DB user, and admin.
5. **Dependencies**: Updates package lists; installs Apache, MariaDB, PHP, and extensions.
6. **Database Configuration**: Starts MariaDB, creates database/user, grants privileges.
7. **Download & Extraction**: Fetches latest Nextcloud tarball, extracts to web root, sets ownership.
8. **Apache Setup**: Generates virtual host, enables modules, restarts Apache.
9. **Nextcloud Install**: Invokes `php occ maintenance:install`, configures trusted domains.
10. **Additional Settings**: Updates `.htaccess`, sets protocol, applies permissions.
11. **Report Generation**: Writes `/root/nextcloud_details.txt` with access credentials.
12. **Completion Marker**: Creates success or failure flag under `/var/`.

## Logging

All output (stdout & stderr) is redirected to `/var/log/nextcloud_install.log`. Integrate with `logrotate` as needed.

## Configuration

* **Virtual Host**: Edit `/etc/apache2/sites-available/nextcloud.conf` to customize domains or enable SSL.
* **PHP**: Adjust `/etc/php/8.x/apache2/php.ini` for memory limits, upload size, and execution time.
* **HTTPS**: This script sets up HTTP only. Use Certbot or your preferred ACME client for TLS.

> **Suggestion:** Provide a link or minimal instructions for obtaining a Let's Encrypt certificate.

## Customization

* **ServerName**: Replace IP with your FQDN in the vHost template.
* **Ports**: Change `<VirtualHost *:80>` to `*:443` and add SSL directives.
* **External DB**: Modify the `install_nextcloud()` function to point to remote databases.

## Troubleshooting

* **Network Issues**: Check DNS, firewall rules, and connectivity.
* **Apt Locks**: Ensure no concurrent package operations (e.g., `apt`, `dpkg`).
* **Service Failures**: Use `systemctl status apache2` or `mariadb` to inspect logs.
* **Permissions**: Confirm `/var/www/html` is owned by `www-data:www-data`.

## Security

* Credentials are printed and stored in `/root/nextcloud_details.txt`—remove or secure after noting them.
* Ensure only ports 80/443 are open; consider enabling a firewall profile.
* Regularly update Nextcloud using `occ upgrade` and system packages via your package manager.

## License

This script is provided as-is. Use it at your own risk. 

Feel free to contribute or make improvements. For issues or enhancements, please open an issue on the GitHub repository.

## Contact

For any questions or feedback, please contact [george@sysnestor.com](mailto:george@sysnestor.com).
