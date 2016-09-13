#!/usr/bin/env bash

## Create ~/projects/web/{logs,ssl} directories
mkdir -pv ~/projects/web/{logs,ssl}

## Remove any previous instances of fastcgi_module from the Apache config
sed -i '' '/fastcgi_module/d' $(brew --prefix)/etc/apache2/2.4/httpd.conf



## Set up fastcgi module to use PHP-FPM
## and include our virtualhost config directory
(export USERHOME=$(dscl . -read /Users/`whoami` NFSHomeDirectory | awk -F"\: " '{print $2}') ; export MODFASTCGIPREFIX=$(brew --prefix mod_fastcgi) ; cat >> $(brew --prefix)/etc/apache2/2.4/httpd.conf <<EOF

# Load PHP-FPM via mod_fastcgi
LoadModule fastcgi_module    ${MODFASTCGIPREFIX}/libexec/mod_fastcgi.so

<IfModule fastcgi_module>
  FastCgiConfig -maxClassProcesses 1 -idle-timeout 1500

  # Prevent accessing FastCGI alias paths directly
  <LocationMatch "^/fastcgi">
    <IfModule mod_authz_core.c>
      Require env REDIRECT_STATUS
    </IfModule>
    <IfModule !mod_authz_core.c>
      Order Deny,Allow
      Deny from All
      Allow from env=REDIRECT_STATUS
    </IfModule>
  </LocationMatch>

  FastCgiExternalServer /php-fpm -host 127.0.0.1:9000 -pass-header Authorization -idle-timeout 1500
  ScriptAlias /fastcgiphp /php-fpm
  Action php-fastcgi /fastcgiphp

  # Send PHP extensions to PHP-FPM
  AddHandler php-fastcgi .php

  # PHP options
  AddType text/html .php
  AddType application/x-httpd-php .php
  DirectoryIndex index.php index.html
</IfModule>

# Include our VirtualHosts
Include ${USERHOME}/projects/web/vhosts.conf
EOF
)







## Create our catch-all vhost
touch ~/projects/web/vhosts.conf

(export USERHOME=$(dscl . -read /Users/`whoami` NFSHomeDirectory | awk -F"\: " '{print $2}') ; cat > ~/projects/web/vhosts.conf <<EOF
#
# Listening ports.
#
#Listen 8080  # defined in main httpd.conf
Listen 8443

#
# Use name-based virtual hosting.
#
NameVirtualHost *:8080
NameVirtualHost *:8443

#
# Set up permissions for VirtualHosts in ~/projects/web
#
<Directory "${USERHOME}/projects/web">
    Options Indexes FollowSymLinks MultiViews
    AllowOverride All
    <IfModule mod_authz_core.c>
        Require all granted
    </IfModule>
    <IfModule !mod_authz_core.c>
        Order allow,deny
        Allow from all
    </IfModule>
</Directory>

# For http://localhost in the users' Sites folder
<VirtualHost _default_:8080>
    ServerName localhost
    DocumentRoot "${USERHOME}/projects/web"
</VirtualHost>
<VirtualHost _default_:8443>
    ServerName localhost
    Include "${USERHOME}/projects/web/ssl/ssl-shared-cert.inc"
    DocumentRoot "${USERHOME}/projects/web"
</VirtualHost>

#
# VirtualHosts
#

## Manual VirtualHost template for HTTP and HTTPS
#<VirtualHost *:8080>
#  ServerName project.loc
#  CustomLog "${USERHOME}/projects/web/logs/project.loc-access_log" combined
#  ErrorLog "${USERHOME}/projects/web/logs/project.loc-error_log"
#  DocumentRoot "${USERHOME}/projects/web/project.loc"
#</VirtualHost>
#<VirtualHost *:8443>
#  ServerName project.dev
#  Include "${USERHOME}/projects/web/ssl/ssl-shared-cert.inc"
#  CustomLog "${USERHOME}/projects/web/logs/project.loc-access_log" combined
#  ErrorLog "${USERHOME}/projects/web/logs/project.loc-error_log"
#  DocumentRoot "${USERHOME}/projects/web/project.loc"
#</VirtualHost>

#
# Automatic VirtualHosts
#
# A directory at ${USERHOME}/projects/web/webroot can be accessed at http://webroot.loc
# In Drupal, uncomment the line with: RewriteBase /
#

# This log format will display the per-virtual-host as the first field followed by a typical log line
LogFormat "%V %h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combinedmassvhost

# Auto-VirtualHosts with .loc
<VirtualHost *:8080>
  ServerName loc
  ServerAlias *.loc

  CustomLog "${USERHOME}/projects/web/logs/loc-access_log" combinedmassvhost
  ErrorLog "${USERHOME}/projects/web/logs/loc-error_log"

  VirtualDocumentRoot ${USERHOME}/projects/web/%-2+
</VirtualHost>
<VirtualHost *:8443>
  ServerName loc
  ServerAlias *.loc
  Include "${USERHOME}/projects/web/ssl/ssl-shared-cert.inc"

  CustomLog "${USERHOME}/projects/web/logs/loc-access_log" combinedmassvhost
  ErrorLog "${USERHOME}/projects/web/logs/loc-error_log"

  VirtualDocumentRoot ${USERHOME}/projects/web/%-2+
</VirtualHost>
EOF
)



## Create self-signed SSL certificate
(export USERHOME=$(dscl . -read /Users/`whoami` NFSHomeDirectory | awk -F"\: " '{print $2}') ; cat > ~/projects/web/ssl/ssl-shared-cert.inc <<EOF
SSLEngine On
SSLProtocol all -SSLv2 -SSLv3
SSLCipherSuite ALL:!ADH:!EXPORT:!SSLv2:RC4+RSA:+HIGH:+MEDIUM:+LOW
SSLCertificateFile "${USERHOME}/projects/web/ssl/selfsigned.crt"
SSLCertificateKeyFile "${USERHOME}/projects/web/ssl/private.key"
EOF
)

openssl req \
  -new \
  -newkey rsa:2048 \
  -days 3650 \
  -nodes \
  -x509 \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=$(whoami)/CN=*.loc" \
  -keyout ~/projects/web/ssl/private.key \
  -out ~/projects/web/ssl/selfsigned.crt