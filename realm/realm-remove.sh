#!/bin/sh

echo -e "stop realm"
systemctl stop realm

echo -e "disable realm"
systemctl disable realm

echo -e "remove realm.service"
rm -f /etc/systemd/system/realm.service
systemctl daemon-reload

echo -e "remove realm"
rm -f /usr/local/bin/realm

echo -e "remove realm config file"
rm -rf /usr/local/etc/realm

echo -e "remove realm log file"
rm -rf /var/log/realm

echo -e "realm is removed."
