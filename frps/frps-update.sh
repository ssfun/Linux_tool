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

# getting the latest version of frps
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/fatedier/frp/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of caddy: ${latest_version}"
latest_name="$(wget -qO- -t1 -T2 "https://api.github.com/repos/fatedier/frp/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
echo "${latest_name}"
frps_link="https://github.com/fatedier/frp/releases/download/${latest_version}/frp_${latest_name}_linux_${arch}.tar.gz"

systemctl stop frps
rm -f /usr/local/bin/frps

echo -e "update the latest version of frps"
cd `mktemp -d`
wget -nv "${frps_link}" -O frps.tar.gz
tar -zxvf frps.tar.gz
cd frp_${latest_name}_linux_${arch}
mv frps /usr/local/bin/frps && chmod +x /usr/local/bin/frps
mkdir -p "/usr/local/etc/frps"

echo -e "restart frps"
systemctl daemon-reload
systemctl reset-failed
systemctl restart frps

echo -e "frps is updated, and restarted."
echo -e "use 'nano /usr/local/etc/frps/frps.ini' edit frps config."
