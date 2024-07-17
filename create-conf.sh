#!/bin/bash

# ASCII Art with copyright message
ascii_art=" _  _____  _      _                  _                                 
(_)(  _  )( )    ( )_               ( )                                
| || ( ) || |    | ,_)   __     ___ | |__        ___    _     ___ ___  
| || | | || |  _ | |   /'__\` /'___)|  _ \`    /'___) /'_\\\` /' _ \` _ \`\\
| || (('\|| |_( )| |_ (  ___/( (___ | | | | _ ( (___ ( (_) )| ( ) ( ) |
(_)(___\_)(____/'\`\__)\\\`\____)\\\`\____)(_) (_)(_)\\\`\____)\\\`\___/'(_) (_) (_)
\nCopyright 2024 IQL Technologies. For help and support or to hire us mail us on helpdesk@iqltech.com\n"

# Function to display ASCII art
display_ascii_art() {
    echo -e "$ascii_art"
}

# Function to install Apache if not installed
install_apache() {
    echo "Installing Apache..."
    sudo apt update
    sudo apt install apache2 -y
}

# Function to install Let's Encrypt (certbot) if not installed
install_certbot() {
    echo "Installing Let's Encrypt (certbot)..."
    sudo apt update
    sudo apt install certbot python3-certbot-apache -y
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

# Check if Apache is installed, if not, install it
if ! command -v apache2 &> /dev/null
then
    install_apache
fi

# Check if certbot is installed, if not, install it
if ! command -v certbot &> /dev/null
then
    install_certbot
fi

# Display ASCII art with the copyright message
display_ascii_art

# Parse command-line arguments
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 --create domain1 domain2 ... | --remove domain | --download-wp domain"
    exit 1
fi

# Check the command
command=$1
shift

# Loop through each domain passed as argument and perform the appropriate action
for domain in "$@"
do
    if [ "$command" == "--create" ]; then
        create_vhost $domain
        install_ssl $domain
        add_ssl_to_vhost $domain
    elif [ "$command" == "--remove" ]; then
        remove_domain $domain
    elif [ "$command" == "--download-wp" ]; then
        download_wp $domain
    else
        echo "Invalid command. Usage: $0 --create domain1 domain2 ... | --remove domain | --download-wp domain"
        exit 1
    fi
done
