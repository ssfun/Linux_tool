#!/bin/sh

echo "Getting the latest version of Gost"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/ginuerzh/gost/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
latest_name="$(wget -qO- -t1 -T2 "https://api.github.com/repos/ginuerzh/gost/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
echo "${latest_name}"
gost_link="https://github.com/ginuerzh/gost/releases/download/${latest_version}/gost-linux-armv8-${latest_name}.gz"

mkdir -p "/etc/gost"

cd `mktemp -d`
wget -nv "${gost_link}" -O gost.gz
gzip -d gost.gz

mv gost /usr/bin/gost
chmod +x /usr/bin/gost

curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/gost/gost.service  -o /etc/systemd/system/gost.service

# if config.json didn't exist, use the example server.json 
if [ ! -f "/etc/gost/config.json" ]; then
  curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/gost/config.json  -o /etc/systemd/system/config.json
fi

systemctl daemon-reload
systemctl reset-failed
systemctl enable gost

echo "gost is installed. use 'systemctl start gost' start gost."
