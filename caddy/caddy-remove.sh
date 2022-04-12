#!/bin/sh

echo "stop caddy"
systemctl stop caddy

echo "disable caddy"
systemctl disable caddy

echo "remove caddy.service"
rm -f /etc/systemd/system/caddy.service

echo "remove caddy"
rm -f /usr/local/bin/caddy
rm -f /usr/bin/caddy

echo "remove caddy config file"
rm -rf /etc/caddy
rm -rf /usr/local/etc/caddy

echo "remove caddy log file"
rm -rf /var/log/caddy

echo "remove caddy ssl file"
rm -rf /etc/ssl/caddy
rm -rf /home/tls

echo "remove caddy www file"
rm -rf /var/www
