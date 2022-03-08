#!/bin/sh

echo "Getting the latest version of filebrowser"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/filebrowser/filebrowser/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
filebrowser_link="https://github.com/filebrowser/filebrowser/releases/download/${latest_version}/linux-amd64-filebrowser.tar.gz"

mkdir -p "/etc/filebrowser"
mkdir -p "/opt/filebrowser"
mkdir -p "/home/filebrowser"

cd `mktemp -d`
wget -nv "${filebrowser_link}" -O filebrowser.tar.gz
tar -zxvf filebrowser.tar.gz  && rm -rf filebrowser.tar.gz && rm -rf CHANGELOG.md && rm -rf README.md && rm -rf LICENSE

wget https://raw.githubusercontent.com/ssfun/Linux_tool/main/filebrowser/filebrowser.service
wget https://raw.githubusercontent.com/ssfun/Linux_tool/main/filebrowser/config.json


mv filebrowser /usr/local/bin/filebrowser
mv filebrowser.service /etc/systemd/system/filebrowser.service

# if config.json didn't exist, use the example server.json 
if [ ! -f "/etc/filebrowser/config.json" ]; then
  mv config.json /etc/filebrowser/config.json
fi

systemctl daemon-reload
systemctl reset-failed

echo "filebrowser is installed. use 'systemctl start filebrowser' to start."
