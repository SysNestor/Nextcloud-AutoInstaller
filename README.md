# Nextcloud Installation Script

This bash script automates the installation of Nextcloud on Ubuntu-based systems. It simplifies the process by handling essential tasks such as installing dependencies, configuring the database, downloading and setting up Nextcloud, and configuring the Apache web server.

## Features

- **Operating System Detection**: Automatically detects and adjusts to the system's OS (Ubuntu/Debian).
- **Dependency Installation**: Installs required packages (Apache, MariaDB, PHP, and others) for running Nextcloud.
- **Database Configuration**: Sets up a MariaDB database for Nextcloud with automatically generated credentials.
- **Nextcloud Installation**: Downloads, extracts, and sets up the latest Nextcloud version.
- **Web Server Configuration**: Configures Apache web server with Nextcloud settings.
- **Progress Bar**: Provides a real-time progress bar with color feedback during installation.
- **Installation Summary**: Generates a summary file containing important details such as admin credentials and database information.

## Requirements

- A system running **Ubuntu** or **Debian**.
- A user with **root** privileges to execute the script.
- Active internet connection to download Nextcloud and dependencies.

## Installation Instructions

1. **Clone the repository**:
   git clone https://github.com/yourusername/nextcloud-installation-script.git
   cd nextcloud-installation-script

Make the script executable:


chmod +x nextcloud-install.sh
Run the script:


sudo ./nextcloud-install.sh
Follow the on-screen instructions: The script will guide you through the installation process, including system updates, dependency installation, database configuration, and Nextcloud setup.

Script Menu Options
Once the script starts, you'll be presented with a menu:

1. Update and Upgrade System: Updates the system and upgrades installed packages.
2. Install Nextcloud: Installs Nextcloud by setting up dependencies, the database, and the web server.
3. View Installation Details: Displays important installation information, including the Nextcloud URL, admin login credentials, and database details.
4. Exit: Exits the script.
Generated Installation Details
After the script completes the installation, a file named nextcloud_details.txt will be created in the root directory (/root/nextcloud_details.txt). This file contains the following details:

Nextcloud URL: The address to access Nextcloud
Admin Username: The default admin username
Admin Password: A randomly generated admin password
Database Credentials: Database name, user, and password for Nextcloud
License
This project is licensed under the MIT License - see the LICENSE file for details.

Support
If you encounter any issues or have questions, please feel free to open an issue on the GitHub repository.

Disclaimer: This script is intended for use on Ubuntu and Debian-based systems. Ensure you have backups of your data before running the script on any production systems.


### Key points to note:
- Code snippets are wrapped with triple backticks (```) for proper formatting.
- Lists are formatted with hyphens for bullets (`-`).
- Sections like `Installation Instructions` are clearly separated with headings (`##`).

## Contact

For any questions or feedback, please contact [george@networkwhois.com](mailto:george@networkwhois.com).
