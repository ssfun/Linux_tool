#!/bin/sh

echo -e "stop filebrowser"
systemctl stop filebrowser

echo -e "disable filebrowser"
systemctl disable filebrowser

echo -e "remove filebrowser.service"
rm -f /etc/systemd/system/filebrowser.service
systemctl daemon-reload

echo -e "remove filebrowser"
rm -f /usr/local/bin/filebrowser

echo -e "remove filebrowser config file"
rm -rf /usr/local/etc/filebrowser

echo -e "remove filebrowser log file"
rm -rf /var/log/filebrowser

echo -e "remove filebrowser file"
rm -rf /opt/filebrowser
rm -rf /home/filebrowser

echo -e "filebrowser is removed."
