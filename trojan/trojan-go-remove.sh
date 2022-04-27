#!/bin/sh

echo -e "stop trojan-go"
systemctl stop trojan-go

echo -e "disable trojan-go"
systemctl disable trojan-go

echo -e "remove trojan-go.service"
rm -f /etc/systemd/system/trojan-go.service
systemctl daemon-reload

echo -e "remove trojan-go"
rm -f /usr/local/bin/trojan-go
rm -f /usr/bin/trojan-go

echo -e "remove trojan-go config file"
rm -rf /etc/trojan-go
rm -rf /usr/local/etc/trojan-go

echo -e "remove trojan-go log file"
rm -rf /var/log/trojan-go

echo -e "trojan-go is removed"
