#!/bin/bash

# ASCII Art with copyright message
ascii_art=" _  _____  _      _                  _                                 
(_)(  _  )( )    ( )_               ( )                                
| || ( ) || |    | ,_)   __     ___ | |__        ___    _     ___ ___  
| || | | || |  _ | |   /'__\` /'___)|  _ \`    /'___) /'_\\\` /' _ \` _ \`\\
| || (('\|| |_( )| |_ (  ___/( (___ | | | | _ ( (___ ( (_) )| ( ) ( ) |
(_)(___\_)(____/'\`\__)\\\`\____)\\\`\____)(_) (_)(_)\\\`\____)\\\`\___/'(_) (_) (_)
\nCopyright 2024 IQL Technologies. For help and support or to hire us mail us on helpdesk@iqltech.com\n"

# Default PHP version
php_version="8.1"

# Function to display ASCII art
display_ascii_art() {
    echo -e "$ascii_art"
}

# Function to install Apache if not installed
install_apache() {
    echo "Installing Apache..."
    sudo apt update
    sudo apt install apache2 -y
    sudo a2enmod rewrite
    sudo systemctl restart apache2
}

# Function to install PHP if not installed
install_php() {
    echo "Installing PHP $php_version..."
    sudo apt update
    sudo apt install php$php_version libapache2-mod-php$php_version -y
    sudo systemctl restart apache2
}

# Function to install MySQL if not installed
install_mysql() {
    echo "Installing MySQL..."
    sudo apt update
    sudo apt install mysql-server -y
    sudo systemctl start mysql
    sudo systemctl enable mysql
}

# Function to check if OpenSSL is installed, if not, install it
check_and_install_openssl() {
    if ! command -v openssl &> /dev/null
    then
        echo "Installing OpenSSL..."
        sudo apt update
        sudo apt install openssl -y
    else
        echo "OpenSSL is already installed."
    fi
}

# Function to check if Certbot is installed, if not, install it
check_and_install_certbot() {
    if ! command -v certbot &> /dev/null
    then
        echo "Installing Let's Encrypt (certbot)..."
        sudo apt update
        sudo apt install certbot python3-certbot-apache -y
    else
        echo "Certbot is already installed."
    fi
}

# Function to install phpMyAdmin if not installed
install_phpmyadmin() {
    echo "Installing phpMyAdmin..."

    # Generate a random and strong password
    phpmyadmin_password=$(openssl rand -base64 24)

    sudo apt update
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password '$phpmyadmin_password'"
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password '$phpmyadmin_password'"
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password '$phpmyadmin_password'"
    sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
    sudo apt install phpmyadmin -y

    # Create symbolic link for /phpmyadmin
    sudo ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin

    # Display the generated password
    echo "phpMyAdmin has been installed. The MySQL root password is: $phpmyadmin_password"
}

# Function to create a MySQL user with all privileges
create_mysql_user() {
    user=$1
    password=$(openssl rand -base64 24)  # Generate a strong password

    echo "Creating MySQL user '$user' with full privileges..."
    sudo mysql -e "CREATE USER '$user'@'localhost' IDENTIFIED BY '$password';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON *.* TO '$user'@'localhost' WITH GRANT OPTION;"
    sudo mysql -e "FLUSH PRIVILEGES;"

    echo "MySQL user '$user' created with the following password: $password"
}

# Function to install unzip if not installed
install_unzip() {
    if ! command -v unzip &> /dev/null
    then
        echo "Installing unzip..."
        sudo apt update
        sudo apt install unzip -y
    fi
}

# Function to download and extract the latest version of WordPress
download_wp() {
    domain=$1
    public_html="/var/www/$domain/public_html"

    # Install unzip if not installed
    install_unzip

    # Download the latest version of WordPress
    wget https://wordpress.org/latest.zip -P /tmp

    # Extract WordPress to the public_html directory
    unzip /tmp/latest.zip -d /tmp
    sudo mv /tmp/wordpress/* $public_html
    sudo chown -R $USER:$USER $public_html

    # Clean up
    rm -rf /tmp/wordpress /tmp/latest.zip

    echo "Downloaded and extracted the latest version of WordPress for $domain"
}

# Function to create Apache virtual host configuration
create_vhost() {
    domain=$1
    public_html="/var/www/$domain/public_html"
    conf_file="/etc/apache2/sites-available/$domain.conf"

    # Create directory if it doesn't exist
    if [ ! -d "$public_html" ]; then
        sudo mkdir -p $public_html
        sudo chown -R $USER:$USER $public_html
    fi

    # Create virtual host configuration (HTTP only)
    echo "<VirtualHost *:80>
    ServerName $domain
    DocumentRoot $public_html

    <Directory $public_html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${domain}_error.log
    CustomLog \${APACHE_LOG_DIR}/${domain}_access.log combined
</VirtualHost>" | sudo tee $conf_file

    # Enable the site
    sudo a2ensite $domain.conf

    # Reload Apache
    sudo systemctl reload apache2

    echo "Created Apache config for $domain"
}

# Function to add SSL configuration to the virtual host
add_ssl_to_vhost() {
    domain=$1
    conf_file="/etc/apache2/sites-available/$domain.conf"

    # Append SSL configuration to the existing virtual host configuration
    echo "<VirtualHost *:443>
    ServerName $domain
    DocumentRoot /var/www/$domain/public_html

    <Directory /var/www/$domain/public_html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$domain/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$domain/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf

    ErrorLog \${APACHE_LOG_DIR}/${domain}_error_ssl.log
    CustomLog \${APACHE_LOG_DIR}/${domain}_access_ssl.log combined
</VirtualHost>" | sudo tee -a $conf_file

    # Reload Apache
    sudo systemctl reload apache2

    echo "Added SSL configuration for $domain"
}

# Function to install SSL certificate using Let's Encrypt
install_ssl() {
    domain=$1

    # Install SSL certificate using certbot
    sudo certbot --apache --force-renewal -d $domain --non-interactive --agree-tos --email sales@iqltech.com

    echo "Installed SSL for $domain"
}

# Function to remove domain configuration and SSL certificates
remove_domain() {
    domain=$1
    conf_file="/etc/apache2/sites-available/$domain.conf"

    # Disable the site
    sudo a2dissite $domain.conf

    # Remove the configuration file
    sudo rm -f $conf_file

    # Remove SSL certificate using certbot
    sudo certbot delete --cert-name $domain

    # Reload Apache
    sudo systemctl reload apache2

    echo "Removed Apache config and SSL for $domain"
}

# Function to enable UFW firewall and allow Apache ports 80 and 443
configure_firewall() {
    echo "Configuring UFW firewall..."

    # Enable UFW if it's not enabled
    sudo ufw enable

    # Allow Apache Full profile (80 and 443 ports)
    sudo ufw allow 'Apache Full'

    # Reload UFW
    sudo ufw reload

    echo "UFW firewall configured to allow Apache ports 80 and 443."
}

# Check if Apache is installed, if not, install it
if ! command -v apache2 &> /dev/null
then
    install_apache
fi

# Check if PHP is installed, if not, install it
if ! command -v php &> /dev/null || ! php -v | grep -q $php_version
then
    install_php
fi

# Check if MySQL is installed, if not, install it
if ! command -v mysql &> /dev/null
then
    install_mysql
fi

# Check and install OpenSSL
check_and_install_openssl

# Check and install Certbot (Let's Encrypt)
check_and_install_certbot

# Install phpMyAdmin if not installed
if ! [ -d /usr/share/phpmyadmin ]; then
    install_phpmyadmin
fi

# Configure firewall (UFW) to allow Apache 80 and 443
configure_firewall

# Parse the command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --php-version)
            php_version="$2"
            shift
            ;;
        --create|--remove|--download-wp)
            command=$1
            domains=()
            shift
            while [[ "$#" -gt 0 && "$1" != --* ]]; do
                domains+=("$1")
                shift
            done
            ;;
        *)
            echo "Invalid option: $1"
            exit 1
            ;;
    esac
done

# Execute the appropriate command
for domain in "${domains[@]}"; do
    if [ "$command" == "--create" ]; then
        create_vhost $domain
        create_mysql_user "phpmyadmin_$domain"
        install_ssl $domain
        add_ssl_to_vhost $domain
    elif [ "$command" == "--remove" ]; then
        remove_domain $domain
    elif [ "$command" == "--download-wp" ]; then
        download_wp $domain
    else
        echo "Invalid command."
        exit 1
    fi
done

# Display ASCII art at the end
display_ascii_art
