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

echo -e "remove the old version of filebrowser"
systemctl stop filebrowser
rm -f /usr/local/bin/filebrowser"

# getting the latest version of filebrowser"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/filebrowser/filebrowser/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of filebrowser: ${latest_version}"
filebrowser_link="https://github.com/filebrowser/filebrowser/releases/download/${latest_version}/linux-${arch}-filebrowser.tar.gz"

cd `mktemp -d`
wget -nv "${filebrowser_link}" -O filebrowser.tar.gz
tar -zxvf filebrowser.tar.gz  && rm -rf filebrowser.tar.gz && rm -rf CHANGELOG.md && rm -rf README.md && rm -rf LICENSE
mv filebrowser /usr/local/bin/filebrowser && chmod +x /usr/local/bin/filebrowser

systemctl restart filebrowser

echo -e "filebrowser is updated, and started."
