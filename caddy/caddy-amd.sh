#!/bin/sh

echo "Getting the latest version of caddy"
wget https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/arm/caddy -O /usr/local/bin/caddy && chmod +x /usr/local/bin/caddy
curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/caddy.service  -o /etc/systemd/system/caddy.service

mkdir -p "/etc/caddy"
touch /etc/caddy/Caddyfile
chown -R root:www-data /etc/caddy

mkdir -p "/etc/ssl/caddy"
chown -R www-data:root /etc/ssl/caddy
chmod -R 777 /etc/ssl/caddy/

mkdir -p "/var/www"
chown www-data:www-data /var/www

mkdir -p "/var/www/404"
curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/index.html  -o /var/www/404/index.html

mkdir -p "/var/log/caddy"
chown www-data:www-data /var/log/caddy

# use the example Caddyfile 
cat <<EOF >/etc/caddy/Caddyfile
site:80 {
    redir https://site
}
site:443 {
    gzip
    timeouts none
    tls email
    log /var/log/caddy/caddy.site.log
    proxy / 127.0.0.1:port {
        header_upstream -Origin
        websocket
    }
}

http://site:404 {
    root /var/www/404
    gzip
}
EOF

systemctl daemon-reload
systemctl reset-failed
systemctl enable caddy

echo "caddy is installed. use 'systemctl start caddy' start caddy."
