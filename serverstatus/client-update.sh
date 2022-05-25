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

# remove the old version of stat_client
systemctl stop stat_client
rm -f /opt/ServerStatus/stat_client

# install the new version fo stat_client
cd `mktemp -d`
wget -nv "${client_link}" -O client.zip
unzip -q client.zip && rm -rf client.zip
mv stat_client /opt/ServerStatus/stat_client

systemctl daemon-reload
systemctl reset-failed
systemctl start stat_client

echo "stat_client is updated, and started."
