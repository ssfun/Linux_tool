#!/bin/sh

echo -e "stop caddy"
systemctl stop caddy

echo -e "disable caddy"
systemctl disable caddy

echo -e "remove caddy.service"
rm -f /etc/systemd/system/caddy.service
systemctl daemon-reload

echo -e "remove caddy"
rm -f /usr/local/bin/caddy

echo -e "remove caddy config file"
rm -rf /usr/local/etc/caddy

echo -e "remove caddy log file"
rm -rf /var/log/caddy

echo -e "remove caddy ssl file"
rm -rf /home/tls

echo -e "remove caddy www file"
rm -rf /var/www

echo -e "caddy is removed."
