#!/bin/sh

echo "stop filebrowser"
systemctl stop filebrowser

echo "disable filebrowser"
systemctl disable filebrowser

echo "remove filebrowser.service"
rm -f /etc/systemd/system/filebrowser.service

echo "remove filebrowser"
rm -f /usr/local/bin/filebrowser
rm -f /usr/bin/filebrowser

echo "remove filebrowser config file"
rm -rf /etc/filebrowser
rm -rf /usr/local/etc/filebrowser

echo "remove filebrowser log file"
rm -rf /var/log/filebrowser

echo "remove filebrowser file"
rm -rf /opt/filebrowser
rm -rf /home/filebrowser
