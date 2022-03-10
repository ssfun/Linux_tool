#!/bin/sh

echo "Getting the latest version of shadowsocks-rust"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
ss_link="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${latest_version}/shadowsocks-${latest_version}.arm-unknown-linux-gnueabi.tar.xz"

cd /usr/local/bin/
wget -nv "${ss_link}" -O ss.tar.xz
xz -d ss.tar.xz && tar -xf ss.tar
chown root.root ./ss*

read -p "请输入监听端口:" port
    [ -z "${port}" ]
read -p "请输入服务密码:" pass
    [ -z "${pass}" ]
    
mkdir /etc/ss-rust
cat <<EOF >/etc/ss-rust/config.json
{
    "server": "127.0.0.1",
    "server_port": $port,
    "timeout": 60,
    "method": "aes-128-gcm",
    "password": "${pass}",
    "fast_open": false,
    "mode": "tcp_and_udp"
}
EOF

cat <<EOF >/etc/systemd/system/ss-rust.service
[Unit]
Description=Shadowsocks-Rust Service
After=network.target
[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/ssserver -c /etc/ss-rust/config.json
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ss-rust

echo "ss-rust is installed. use 'systemctl start ss-rust' to start."