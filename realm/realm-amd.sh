#!/bin/sh

echo "Getting the latest version of realm"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/zhboner/realm/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
realm_link="https://github.com/zhboner/realm/releases/download/${latest_version}/realm-x86_64-unknown-linux-gnu.tar.gz"

cd `mktemp -d`
wget -nv "${realm_link}" -O realm.tar.gz
tar -zxvf realm.tar.gz

mv realm /usr/local/bin/realm && chmod +x /usr/local/bin/realm

mkdir -p "/usr/local/etc/realm"
mkdir -p "/var/log/realm"


# set realm.service
cat <<EOF >/etc/systemd/system/realm.service
[Unit]
Description=realm
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/realm -c /usr/local/etc/realm/config.toml

[Install]
WantedBy=multi-user.target
EOF

# set realm.toml 
read -p "请输入本地需要监听的地址,(ipv6:"[::0]";ipv4:"0.0.0.0"):" lhost
    [ -z "${lhost}" ]
read -p "请输入本地需要监听的端口:" lport
    [ -z "${lport}" ]
read -p "请输入需要转发的地址:" rhost
    [ -z "${rhost}" ]
read -p "请输入需要转发的端口:" rport
    [ -z "${rport}" ]
cat <<EOF >/usr/local/etc/realm/config.toml
[log]
level = "warn"
output = "/var/log/realm/realm.log"

[network]
use_udp = true
zero_copy = true

[[endpoints]]
listen = "$lhost:$lport"
remote = "$rhost:$rport"

EOF


systemctl daemon-reload
systemctl reset-failed
systemctl enable realm
systemctl start realm

echo "realm is installed, and started."
echo "use 'nano /usr/local/etc/realm/config.toml' edit realm config."
