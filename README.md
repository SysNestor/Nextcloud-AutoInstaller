# Nextcloud Installation Script

A Bash script for automated installation and configuration of Nextcloud on Debian/Ubuntu  Linux systems.

## Features

- Interactive menu-driven interface
- Automatic system detection and configuration
- Progress visualization for installation steps
- Support for multiple Linux distributions:
  - Ubuntu
  - Debian
- Automated configuration of:
  - Web server (Apache)
  - Database (MariaDB)
  - PHP and required extensions
- Secure password generation
- Detailed installation report

## Prerequisites

- Root access to your system
- One of the supported Linux distributions
- Basic system requirements:
  - Minimum 512MB RAM
  - Minimum 10GB storage space
  - Internet connection

## Installation

1. Download the script:
```bash
wget https://raw.githubusercontent.com/sysnestor/Nextcloud-AutoInstaller/main/Nextcloud-AutoInstaller.sh
```

2. Make it executable:
```bash
chmod +x Nextcloud-AutoInstaller.sh
```

3. Run the script:
```bash
sudo ./Nextcloud-AutoInstaller.sh
```

## Usage

The script provides an interactive menu with the following options:

1. **Update and Upgrade System**
   - Updates package lists
   - Performs system upgrade

2. **Install Nextcloud**
   - Installs all required dependencies
   - Configures database
   - Downloads and extracts Nextcloud
   - Configures web server
   - Sets appropriate permissions
   - Generates secure passwords
   - Creates installation report

3. **View Installation Details**
   - Displays installation information including:
     - Nextcloud URL
     - Admin credentials
     - Database details

4. **Exit**
   - Exits the script

## Security Features

- Random password generation for:
  - Database root password
  - Database user password
  - Nextcloud admin password
- Proper file permissions
  
## Installation Report

After successful installation, a detailed report is generated at `/root/nextcloud_details.txt` containing:
- Nextcloud access URL
- Admin credentials
- Database connection details
- System information

## Error Handling

The script includes comprehensive error handling:
- Checks for root privileges
- Validates operating system compatibility
- Monitors installation processes
- Provides detailed error messages

## Operating System Support

### Debian/Ubuntu
- Configures Apache with required modules
- Sets up MariaDB database
- Installs necessary PHP extensions

## Contributing

Feel free to submit issues and pull requests for:
- Bug fixes
- New features
- Documentation improvements
- Support for additional distributions

## License

This script is provided as-is. Use it at your own risk. 

Feel free to contribute or make improvements. For issues or enhancements, please open an issue on the GitHub repository.

## Contact

For any questions or feedback, please contact [george@networkwhois.com](mailto:george@networkwhois.com).
