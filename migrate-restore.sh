#!/bin/bash

# Define database credentials
domain_name=""
database_name=""
database_user=""

digitalocean_space_name=""  # Replace with your actual Space name
digitalocean_access_key=""  # Replace with your DigitalOcean Access Key
digitalocean_secret_key=""  # Replace with your DigitalOcean Secret Key
digitalocean_region="blr1"

keep_up_script_path="$(pwd)/keep_up.sh"  # Replace with the actual path to your script
back_up_script_path="$(pwd)/backup_cron.sh"  # Replace with the actual path to your script

s3cmd_config_file="$HOME/.s3cfg"

# Offload media configuration
offload_media_config="define( 'AS3CF_SETTINGS', serialize( array(
    'provider' => 'do', 
    'access-key-id' => '$digitalocean_access_key', 
    'secret-access-key' => '$digitalocean_secret_key', 
    'region' => '$digitalocean_region', 
    'bucket' => '$digitalocean_space_name',
    'copy-to-s3' => true,
    'serve-from-s3' => true,
    'domain' => 'img.risingkashmir.com', 
    'cloudfront' => '',
    'object-versioning' => false,
    'enable-object-prefix' => true,
    'object-prefix' => 'wp-content/uploads/', 
    'use-yearmonth-folders' => true,
    'force-https' => true, 
    'remove-local-file' => false, 
)));"

apt-get install wget

# Function to check and install OpenSSL if not installed
check_and_install_openssl() {
    if ! command -v openssl &> /dev/null; then
        echo "OpenSSL is not installed. Installing OpenSSL..."
        sudo apt-get update
        sudo apt-get install openssl -y
    else
        echo "OpenSSL is already installed."
    fi
}

# Function to install and configure s3cmd
install_and_configure_s3cmd() {
    echo "Installing s3cmd..."
    sudo apt-get install s3cmd -y || { echo "Failed to install s3cmd. Exiting."; exit 1; }

    echo "Configuring s3cmd for DigitalOcean Spaces..."
    cat > "$s3cmd_config_file" <<EOL
[default]
access_key = $digitalocean_access_key
secret_key = $digitalocean_secret_key
host_base = $digitalocean_region.digitaloceanspaces.com
host_bucket = %(bucket)s.$digitalocean_region.digitaloceanspaces.com
use_https = True
signature_v2 = False
EOL
    echo "s3cmd has been configured for DigitalOcean Spaces."
}

# Function to create and configure the database
import_database() {
    echo "Generating a random password for MySQL user '$database_user'..."
    database_password=$(openssl rand -base64 24)
    echo "Generated password: $database_password"

    echo "Creating database '$database_name' if it doesn't exist..."
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS $database_name;" || { echo "Failed to create database. Exiting."; exit 1; }

    echo "Changing password for MySQL user '$database_user'..."
    sudo mysql -e "ALTER USER '$database_user'@'localhost' IDENTIFIED BY '$database_password'; FLUSH PRIVILEGES;" || { echo "Failed to change password. Exiting."; exit 1; }

    echo "Importing database from 'database_export_file.sql' into '$database_name'..."
    mysql -u "$database_user" -p"$database_password" "$database_name" < database_export_file.sql || { echo "Failed to import database. Exiting."; exit 1; }

    echo "Password for MySQL user '$database_user' has been set to: $database_password"
}

# Function to run the server setup script
run_server_setup() {
    echo "Updating package list..."
    sudo apt-get update || { echo "Failed to update package list. Exiting."; exit 1; }

    echo "Installing wget..."
    sudo apt-get install wget -y || { echo "Failed to install wget. Exiting."; exit 1; }

    echo "Running the server setup script..."
    wget https://cdn.jsdelivr.net/gh/servermango/easy-server-setup/easy-server-setup.sh
    chmod +x easy-server-setup.sh
    ./easy-server-setup.sh --install-basics || { echo "Failed to run server setup script. Exiting."; exit 1; }
}

add_domain() {
    if [[ -z "$1" ]]; then
        echo "Error: Domain name is required."
        exit 1
    fi
    ./easy-server-setup.sh --create "$1"
}

# Main function to group database tasks
database_tasks() {
    import_database
}

# Function to add a cron job for keep_up.sh
add_keepup_cron_job() {
    echo "Downloading keep_up.sh..."
    wget https://cdn.jsdelivr.net/gh/servermango/keep-database-and-apache-up/keep_up.sh
    chmod +x keep_up.sh

    echo "Adding a cron job to run $keep_up_script_path every 8 hours..."
    (crontab -l 2>/dev/null; echo "* * * * * bash $keep_up_script_path") | sudo crontab - || { echo "Failed to add cron job for keep_up.sh. Exiting."; exit 1; }
    echo "Cron job for keep_up.sh added successfully."
}

add_backup_cron_job() {
    # Check if the file exists before downloading
    if [ ! -f "$back_up_script_path" ]; then
        echo "Downloading backup_cron.sh..."
        wget https://cdn.jsdelivr.net/gh/servermango/automatically-backup-database-to-cloud/backup_cron.sh -O "$back_up_script_path"
        chmod +x "$back_up_script_path"
    else
        echo "backup_cron.sh already exists. Skipping download."
    fi
    # Add a cron job to run the backup script every 8 hours
    echo "Adding a cron job to run $back_up_script_path every 8 hours..."
    (crontab -l 2>/dev/null; echo "0 */8 * * * bash $back_up_script_path") | sudo crontab - || { echo "Failed to add cron job. Exiting."; exit 1; }
    echo "Cron job for backup_cron.sh added successfully."
}


# Main function to group database tasks
database_tasks() {
    import_database
}

# Function to update the backup_cron.sh file
update_backup_cron_file() {
    echo "Updating backup_cron.sh file..."

    # Create a temporary file
    temp_file=$(mktemp)

    # Flag to track if we are inside the #CONFIG section
    in_config_section=false

    # Read the original file and replace the contents between #CONFIG and #ENDCONFIG
    while IFS= read -r line; do
        if [[ "$line" == "#CONFIG" ]]; then
            echo "$line" >> "$temp_file"
            in_config_section=true
            # Write the new configurations
            echo "DB_NAME=\"$database_name\"" >> "$temp_file"
            echo "DB_USER=\"$database_user\"" >> "$temp_file"
            echo "DB_PASSWORD=\"$database_password\"" >> "$temp_file"
            echo "BACKUP_DIR=\"/var/www/$domain_name/backup/\"" >> "$temp_file"
            echo "CURRENT_DATE=\$(date +%F)" >> "$temp_file"
            echo "S3_BUCKET=\"s3://$digitalocean_space_name/backup/\"" >> "$temp_file"
        elif [[ "$line" == "#ENDCONFIG" ]]; then
            # End the config section
            echo "$line" >> "$temp_file"
            in_config_section=false
        elif ! $in_config_section; then
            # Write all other lines to the temp file
            echo "$line" >> "$temp_file"
        fi
    done < "$back_up_script_path"

    # Replace the original file with the updated temporary file
    mv "$temp_file" "$back_up_script_path"
    chmod +x "$back_up_script_path"

    echo "backup_cron.sh has been updated successfully."
}

add_offload_media_config() {
    local wp_config_path="$(pwd)/public_html/wp-config.php"

    # Check if wp-config.php exists
    if [[ -f "$wp_config_path" ]]; then
        echo "Adding offload_media_config to $wp_config_path..."

        # Create a temporary file
        temp_file=$(mktemp)

        # Flag to track if we are at the beginning of the file
        at_start=true

        # Read the original file and add the config after <?php
        while IFS= read -r line; do
            if $at_start && [[ "$line" == "<?php" ]]; then
                echo "$line" >> "$temp_file"
                echo "$offload_media_config" >> "$temp_file"  # Add the offload_media_config
                at_start=false
            else
                echo "$line" >> "$temp_file"  # Write other lines
            fi
        done < "$wp_config_path"

        # Replace the original file with the updated temporary file
        mv "$temp_file" "$wp_config_path"

        echo "offload_media_config has been added to $wp_config_path successfully."
    else
        echo "Error: $wp_config_path not found."
    fi
}

# Parse command line arguments
case "$1" in
    --install-openssl)
        check_and_install_openssl
        ;;
    --import-database)
        database_tasks
        ;;
    --install-s3cmd)
        install_and_configure_s3cmd
        ;;
    --run-server-setup)
        run_server_setup
        ;;
    --update-backup-cron-file)
        update_backup_cron_file
        ;;
    --add-backup-cron)
        add_backup_cron_job
        ;;
    --add-keepup-cron)
        add_keepup_cron_job
        ;;
    --add-offload-media-config)
        add_offload_media_config
        ;;
    --all)
        if [[ -z "$2" ]]; then
            echo "Error: Domain name is required when using --all."
            exit 1
        fi
        check_and_install_openssl
        run_server_setup
        add_domain
        install_and_configure_s3cmd
        database_tasks
        update_backup_cron_file
        add_keepup_cron_job
        add_backup_cron_job
        add_offload_media_config
        ;;
    *)
        echo "Usage: $0 {--install-openssl|--import-database|--install-s3cmd|--run-server-setup|--update-backup-cron-file|--add-backup-cron|--add-keepup-cron|--add-offload-media-config|--all DOMAIN_NAME}"
        exit 1
        ;;
esac
