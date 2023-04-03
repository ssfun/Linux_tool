#!/bin/sh

echo -e "stop plexdrive"
systemctl stop plexdrive

echo -e "disable plexdrive"
systemctl disable plexdrive

echo -e "remove plexdrive.service"
rm -f /etc/systemd/system/plexdrive.service
systemctl daemon-reload

echo -e "remove plexdrive"
rm -f /usr/local/bin/plexdrive

echo -e "remove plexdrive config and cache file"
rm -rf /home/.plexdrive
rm -rf /home/gsuite

echo -e "plexdrive is removed."
