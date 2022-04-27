#!/bin/sh

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

echo -e "remove old version of caddy"
systemctl stop caddy
rm -f /usr/local/bin/caddy

# getting the latest version of caddy
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of caddy: ${latest_version}"
caddy_link="https://github.com/lxhao61/integrated-examples/releases/download/${latest_version}/caddy_linux_${arch}.tar.gz"

cd `mktemp -d`
wget -nv "${caddy_link}" -O caddy.tar.gz
tar -zxvf caddy.tar.gz

mv caddy /usr/local/bin/caddy && chmod +x /usr/local/bin/caddy

echo -e "restart caddy"
systemctl start caddy

echo -e "caddy is updated, and started."
echo -e "use 'nano /usr/local/etc/caddy/Caddyfile' edit caddy Caddyfile."
