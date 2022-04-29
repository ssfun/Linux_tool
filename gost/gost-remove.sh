#!/bin/sh

echo -e "stop gost"
systemctl stop gost

echo -e "disable gost"
systemctl disable gost

echo -e "remove gost.service"
rm -f /etc/systemd/system/gost.service
systemctl daemon-reload

echo -e "remove gost"
rm -f /usr/local/bin/gost

echo -e "remove gost config file"
rm -rf /usr/local/etc/gost

echo -e "gost has been removed."
