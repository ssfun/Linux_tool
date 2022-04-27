#!/bin/sh

echo "remove caddy"
systemctl stop caddy
rm -f /usr/local/bin/caddy

echo "Getting the latest version of caddy"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
caddy_link="https://github.com/lxhao61/integrated-examples/releases/download/${latest_version}/caddy_linux_amd64.tar.gz"

cd `mktemp -d`
wget -nv "${caddy_link}" -O caddy.tar.gz
tar -zxvf caddy.tar.gz

mv caddy /usr/local/bin/caddy && chmod +x /usr/local/bin/caddy

echo "restart caddy"
systemctl start caddy

echo "caddy is updated, and started."
echo "use 'nano /usr/local/etc/caddy/Caddyfile' edit caddy Caddyfile."
