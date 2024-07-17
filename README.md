# One Create Click Hosting for one or more domains on your Ubuntu server
Host one or more sites on your linux server with one command. This script creates vhost conf file, installs SSL and apache (Tested on Ubuntu Server)

## How to use

Download Script
`wget https://cdn.jsdelivr.net/gh/iqltechnologies/apache-vhost-creator/create-conf.sh`

Make it executable
`chmod +x create-conf.sh`

Add your domain
`./create-conf.sh --create YOURDOMAIN.EXTENSION`

# Remove a domain

`./create-conf.sh --remove YOURDOMAIN.EXTENSION`

# Download wordpress during add with flag --download-wp

`./create-conf.sh --create --download-wp YOURDOMAIN.EXTENSION`
