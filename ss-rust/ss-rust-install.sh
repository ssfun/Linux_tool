#!/usr/bin

echo -e "check root user"
[[ $EUID -ne 0 ]] && echo -e "Error: You must run this script as root!" && exit 1

arch=$(arch)
echo -e "get operating system: $(arch)"
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="x86_64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="aarch64"
else
    echo -e "Error: The operating system is not supported."
    exit 1
fi

# getting the latest version of shadowsocks-rust"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of ss-rust: ${latest_version}"
ss_link="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${latest_version}/shadowsocks-${latest_version}.${arch}-unknown-linux-gnu.tar.xz"

echo -e "installing the latest version of plexdrive"
cd `mktemp -d`
wget -nv "${ss_link}" -O ss.tar.xz
xz -d ss.tar.xz && tar -xf ss.tar
mv ssserver /usr/local/bin/ssserver && chmod +x /usr/local/bin/ssserver

read -p "请输入监听端口:" port
    [ -z "${port}" ]
read -p "请输入服务密码:" pass
    [ -z "${pass}" ]
    
mkdir "/usr/local/etc/ss-rust"
cat <<EOF >/usr/local/etc/ss-rust/config.json
{
    "server": "0.0.0.0",
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
User=root
ExecStart=/usr/local/bin/ssserver -c /usr/local/etc/ss-rust/config.json

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ss-rust
systemctl start ss-rust

echo "ss-rust is installed, and start."
