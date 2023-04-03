#!/usr/bin

echo -e "check root user"
[[ $EUID -ne 0 ]] && echo -e "Error: You must run this script as root!" && exit 1

arch=$(arch)
echo -e "get the operating system: $(arch)"
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm"
else
    echo -e "Error: The operating system is not supported."
    exit 1
fi

echo -e "remove the old version of trojan-go"
systemctl stop trojan-go
rm -f /usr/local/bin/trojan-go
rm -f /usr/local/etc/trojan-go/geoip.dat
rm -f /usr/local/etc/trojan-go/geosite.dat

# getting the latest version of trojan-go"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/p4gefau1t/trojan-go/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of trojan-go: ${latest_version}"
trojango_link="https://github.com/p4gefau1t/trojan-go/releases/download/${latest_version}/trojan-go-linux-${arch}.zip"

cd `mktemp -d`
wget -nv "${trojango_link}" -O trojan-go.zip
unzip -q trojan-go.zip && rm -rf trojan-go.zip

mv trojan-go /usr/local/bin/trojan-go
mv geoip.dat /usr/local/etc/trojan-go/geoip.dat
mv geosite.dat /usr/local/etc/trojan-go/geosite.dat

systemctl restart trojan-go

echo "trojan-go is updated, and started."
