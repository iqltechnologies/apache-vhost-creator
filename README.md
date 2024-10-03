# Ubuntu Server Setup Script to Host one or more domains with PHP, Apache, MySQL, (or maybe WordPress)
Host one or more sites on your linux server with one command. This script creates vhost conf file, installs SSL and apache (Tested on Ubuntu Server)

## Prerequisites

- A  Ubuntu 22 or up Server.
- Access to the terminal with `sudo` privileges.
- MySQL/MariaDB installed for database operations.
- DigitalOcean account and Spaces set up for storing backups.
- 
# Quickstart - Install or migrate WordPress

We have included a new quickstart script to easily migrate your site if you use wordpress and mgrating to Ubuntu VPS. We assume you are also using wp_offload_media plugin with digitalocean and also want backup of database every 8 hours. It’s designed to streamline the process of migrating a WordPress environment in few seconds.

## Easy Migration

Assuming your site is in migration.sql file in `/var/www/yoursite/public_html` cd in to the directory and upload your migration.sql file in `/var/www/yoursite/`

Download Script

`wget https://cdn.jsdelivr.net/gh/servermango/easy-server-setup/migrate-restore.sh && chmod +x migrate-restore.sh`

*Command-Line Options*
  -   --install-openssl: Install OpenSSL if not installed.
  -  --import-database: Import the specified database.
  -  --install-s3cmd: Install and configure s3cmd for DigitalOcean Spaces.
  -  --run-server-setup: Run the server setup script.
  -  --update-backup-cron-file: Update the backup_cron.sh file with database credentials.
  -  --add-backup-cron: Add a cron job for backup.
  -  --add-keepup-cron: Add a cron job for the keep-up script.
  -  --add-offload-media-config: Add offload media configuration to wp-config.php.
  -  --all: Run all tasks.

### Overview

This script automates the setup of a server environment on Ubuntu 22.04. It installs and configures Apache, PHP (with a version specified by the user), MySQL, phpMyAdmin, and additional utilities. The script also includes options to create and manage virtual hosts, install SSL certificates, and configure the firewall.


## How to use

Download Script
`wget https://cdn.jsdelivr.net/gh/servermango/easy-server-setup/easy-server-setup.sh`

Make it executable
`chmod +x easy-server-setup.sh`

Add your domain
`./easy-server-setup.sh --create YOURDOMAIN.EXTENSION`

### Usage

```bash
./easy-server-setup.sh [options] [command] [domains...]
```

# Remove a domain

`./easy-server-setup.sh --remove YOURDOMAIN.EXTENSION`

# Download wordpress during add with flag --download-wp

`./easy-server-setup.sh --create --download-wp YOURDOMAIN.EXTENSION`

### Options

- `--install-basics`: Installs and configures basic software components such as Apache, PHP, MySQL, OpenSSL, Certbot, and phpMyAdmin. It also configures the firewall to allow HTTP (port 80) and HTTPS (port 443) traffic.
- `--php-version <version>`: Specifies the PHP version to install (e.g., `8.1`). The default is `8.1`.

### Commands

- `--create`: Creates a virtual host for the specified domains, installs SSL certificates, and configures phpMyAdmin access for database management.
- `--remove`: Removes the virtual host configuration and SSL certificates for the specified domains.
- `--download-wp`: Downloads and extracts the latest version of WordPress into the public_html directory for the specified domains.

### Examples

#### 1. Install Basic Software

To install Apache, PHP, MySQL, OpenSSL, Certbot, and phpMyAdmin, and configure the firewall:

```bash
./easy-server-setup.sh --install-basics
```

#### 2. Specify PHP Version

To install a specific version of PHP (e.g., `8.2`) and also install basic software:

```bash
./easy-server-setup.sh --install-basics --php-version 8.2
```

#### 3. Create a Virtual Host

To create a virtual host for `example.com`, including SSL certificates and phpMyAdmin access:

```bash
./easy-server-setup.sh --create example.com
```

#### 4. Remove a Virtual Host

To remove the virtual host and SSL configuration for `example.com`:

```bash
./easy-server-setup.sh --remove example.com
```

#### 5. Download and Install WordPress

To download and extract the latest version of WordPress into the `public_html` directory for `example.com`:

```bash
./easy-server-setup.sh --download-wp example.com
```

### Detailed Function Descriptions

#### `install_apache()`

- Installs Apache if it is not already installed.
- Enables the Apache rewrite module and restarts Apache.

#### `install_php()`

- Installs the specified version of PHP if it is not already installed.
- Restarts Apache to apply PHP changes.

#### `install_mysql()`

- Installs MySQL Server if it is not already installed.
- Starts and enables MySQL service.

#### `check_and_install_openssl()`

- Checks if OpenSSL is installed and installs it if not.

#### `check_and_install_certbot()`

- Checks if Certbot is installed and installs it if not.

#### `install_phpmyadmin()`

- Installs phpMyAdmin with a randomly generated strong password.
- Creates a symbolic link for phpMyAdmin under `/phpmyadmin`.

#### `create_mysql_user()`

- Creates a MySQL user with all privileges and a randomly generated strong password.
- Displays the password for user management via phpMyAdmin.

#### `install_unzip()`

- Installs `unzip` if it is not already installed.

#### `download_wp()`

- Downloads and extracts the latest WordPress version into the specified domain’s `public_html` directory.

#### `create_vhost()`

- Creates an Apache virtual host configuration for the specified domain.

#### `add_ssl_to_vhost()`

- Adds SSL configuration to the virtual host for the specified domain.

#### `install_ssl()`

- Installs an SSL certificate for the specified domain using Certbot.

#### `remove_domain()`

- Removes the Apache virtual host configuration and SSL certificates for the specified domain.

#### `configure_firewall()`

- Configures UFW (Uncomplicated Firewall) to allow HTTP (80) and HTTPS (443) traffic.

#### `install_basics()`

- Installs and configures basic software components if `--install-basics` is used.
- Includes checks and installations for Apache, PHP, MySQL, OpenSSL, Certbot, and phpMyAdmin.
- Configures the firewall to allow Apache traffic.

### Notes

- Ensure you have appropriate permissions to execute the script, particularly for installation and configuration tasks.
- Use a domain name that you own and control to fully utilize the virtual host and SSL configurations.

For any issues or additional help, please contact helpdesk@iqltech.com.

---
