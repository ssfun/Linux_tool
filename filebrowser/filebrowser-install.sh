#!/usr/bin

echo -e "check root user"
[[ $EUID -ne 0 ]] && echo -e "Error: You must run this script as root!" && exit 1

arch=$(arch)
echo -e "get operating system: $(arch)"
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    echo -e "Error: The operating system is not supported."
    exit 1
fi

# getting the latest version of filebrowser"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/filebrowser/filebrowser/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of filebrowser: ${latest_version}"
filebrowser_link="https://github.com/filebrowser/filebrowser/releases/download/${latest_version}/linux-${arch}-filebrowser.tar.gz"

mkdir -p "/usr/local/etc/filebrowser"
mkdir -p "/var/log/filebrowser"
mkdir -p "/opt/filebrowser"
mkdir -p "/home/filebrowser"

cd `mktemp -d`
wget -nv "${filebrowser_link}" -O filebrowser.tar.gz
tar -zxvf filebrowser.tar.gz  && rm -rf filebrowser.tar.gz && rm -rf CHANGELOG.md && rm -rf README.md && rm -rf LICENSE
mv filebrowser /usr/local/bin/filebrowser && chmod +x /usr/local/bin/filebrowser

# set filebrowser.service
cat <<EOF >/etc/systemd/system/filebrowser.service
[Unit]
Description=filebrowser
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/filebrowser -c /usr/local/etc/filebrowser/config.json

[Install]
WantedBy=multi-user.target
EOF

# set config.json
read -p "请输入 filebrowser 端口:" port
    [ -z "${port}" ]
cat <<EOF >/usr/local/etc/filebrowser/config.json
{
    "address":"127.0.0.1",
    "database":"/opt/filebrowser/filebrowser.db",
    "log":"/var/log/filebrowser/filebrowser.log",
    "port":$port,
    "root":"/home/filebrowser",
    "username":"admin"
}
EOF

systemctl daemon-reload
systemctl reset-failed
systemctl enable filebrowser
systemctl start filebrowser

echo -e "filebrowser is installed,and started."
