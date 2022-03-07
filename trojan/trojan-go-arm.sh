#!/bin/sh

echo "Getting the latest version of trojan-go"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/p4gefau1t/trojan-go/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g' --raw-output)"
echo "${latest_version}"
trojango_link="https://github.com/p4gefau1t/trojan-go/releases/download/${latest_version}/trojan-go-linux-arm.zip"

mkdir -p "/usr/bin/trojan-go"
mkdir -p "/etc/trojan-go"

cd `mktemp -d`
wget -nv "${trojango_link}" -O trojan-go.zip
unzip -q trojan-go.zip && rm -rf trojan-go.zip

mv trojan-go /usr/bin/trojan-go/trojan-go
mv geoip.dat /etc/trojan-go/geoip.dat
mv geosite.dat /etc/trojan-go/geosite.dat
mv example/trojan-go.service /etc/systemd/system/trojan-go.service

# if config.json didn't exist, use the example server.json 
if [ ! -f "/etc/trojan-go/config.json" ]; then
  mv example/sever.json /etc/trojan-go/config.json
fi

systemctl daemon-reload
systemctl reset-failed

echo "trojan-go is installed."
