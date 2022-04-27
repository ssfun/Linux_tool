#!/bin/sh

echo "Getting the latest version of realm"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/zhboner/realm/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
realm_link="https://github.abskoop.workers.dev/https://github.com/zhboner/realm/releases/download/${latest_version}/realm-x86_64-unknown-linux-gnu.tar.gz"

systemctl stop realm
rm -f /usr/local/bin/realm

cd `mktemp -d`
wget -nv "${realm_link}" -O realm.tar.gz
tar -zxvf realm.tar.gz

mv realm /usr/local/bin/realm && chmod +x /usr/local/bin/realm

systemctl daemon-reload
systemctl start realm

echo "realm is updated, and started."
echo "use 'nano /usr/local/etc/realm/config.toml' edit realm config."
