#!/bin/sh

echo -e "stop ss-rust"
systemctl stop ss-rust

echo -e "disable ss-rust"
systemctl disable ss-rust

echo -e "remove ss-rust.service"
rm -f /etc/systemd/system/ss-rust.service
systemctl daemon-reload

echo -e "remove ss-rust"
rm -f /usr/local/bin/ssserver

echo -e "remove trojan-go config file"
rm -rf /usr/local/etc/ss-rust

echo -e "remove trojan-go log file"
rm -rf /var/log/ss-rust

echo -e "trojan-go is removed."
