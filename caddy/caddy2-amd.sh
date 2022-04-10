#!/bin/sh

echo "Getting the latest version of caddy"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
caddy_link="https://github.com/lxhao61/integrated-examples/releases/download/${latest_version}/caddy_linux_amd64.tar.gz"

cd `mktemp -d`
wget -nv "${caddy_link}" -O caddy.tar.gz
tar -zxvf caddy.tar.gz

mv caddy /usr/local/bin/caddy && chmod +x /usr/local/bin/caddy

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

# set caddy.service 
curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/caddy.service  -o /etc/systemd/system/caddy.service

# use the example Caddyfile 
curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/Caddyfile  -o /etc/caddy/Caddyfile

systemctl daemon-reload
systemctl reset-failed
systemctl enable caddy

echo "caddy is installed. use 'systemctl start caddy' start caddy."
echo "use '/etc/caddy/Caddyfile' edit caddy config."
