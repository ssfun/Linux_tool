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

# getting the latest version of trojan-go"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/p4gefau1t/trojan-go/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of trojan-go: ${latest_version}"
trojango_link="https://github.com/p4gefau1t/trojan-go/releases/download/${latest_version}/trojan-go-linux-${arch}.zip"

echo -e "remove the old version of realm"
systemctl stop realm
rm -f /usr/local/bin/realm

# getting the latest version of realm"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/zhboner/realm/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of realm: ${latest_version}"
realm_link="https://github.abskoop.workers.dev/https://github.com/zhboner/realm/releases/download/${latest_version}/realm-x86_64-unknown-linux-gnu.tar.gz"

cd `mktemp -d`
wget -nv "${realm_link}" -O realm.tar.gz
tar -zxvf realm.tar.gz

mv realm /usr/local/bin/realm && chmod +x /usr/local/bin/realm

systemctl daemon-reload
systemctl restart realm

echo "realm is updated, and started."
echo "use 'nano /usr/local/etc/realm/config.toml' edit realm config."
