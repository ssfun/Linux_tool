#!/bin/sh

echo "stop trojan-go"
systemctl stop trojan-go

echo "disable trojan-go"
systemctl disable trojan-go

echo "remove trojan-go.service"
rm -f /etc/systemd/system/trojan-go.service

echo "remove trojan-go"
rm -f /usr/local/bin/trojan-go
rm -f /usr/bin/trojan-go

echo "remove trojan-go config file"
rm -rf /etc/trojan-go
rm -rf /usr/local/etc/trojan-go

echo "remove trojan-go log file"
rm -rf /var/log/trojan-go