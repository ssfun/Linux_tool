#!/usr/bin

echo -e "check root user"
[[ $EUID -ne 0 ]] && echo -e "Error: You must run this script as root!" && exit 1

arch=$(arch)
echo -e "get the operating system: $(arch)"
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="x86_64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="aarch64"
else
    echo -e "Error: The operating system is not supported."
    exit 1
fi

# getting the latest version of serverstatus-client"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/zdz/ServerStatus-Rust/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of serverstatus-client: ${latest_version}"
client_link="https://github.com/zdz/ServerStatus-Rust/releases/download/${latest_version}/client-${arch}-unknown-linux-musl.zip"

mkdir -p "/opt/ServerStatus"

cd `mktemp -d`
wget -nv "${client_link}" -O client.zip
unzip -q client.zip && rm -rf client.zip
mv stat_client /opt/ServerStatus/stat_client

# set stat_client.service
read -p "请输入 ServerStatus 地址:" host
    [ -z "${host}" ]
read -p "请输入 ServerStatus user ID:" user
    [ -z "${user}" ]
read -p "请输入 ServerStatus user passsword:" pswd
    [ -z "${pswd}" ]

cat <<EOF >/etc/systemd/system/stat_client.service
[Unit]
Description=ServerStatus-Rust Client
After=network.target

[Service]
User=root
Group=root
Environment="RUST_BACKTRACE=1"
WorkingDirectory=/opt/ServerStatus
ExecStart=/opt/ServerStatus/stat_client -a "https://$host/report" -u $user -p $pswd --disable-ping --disable-tupd
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl reset-failed
systemctl enable stat_client
systemctl start stat_client

echo "stat_client is installed, and started."
