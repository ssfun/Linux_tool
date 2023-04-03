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

# getting the latest version of plexdrive"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/plexdrive/plexdrive/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
echo "get the latest version of plexdrive: ${latest_version}"
plexdrive_link="https://github.com/plexdrive/plexdrive/releases/download/${latest_version}/plexdrive-linux-${arch}"

echo -e "remove the old version of plexdrive"
systemctl stop plexdrive
rm -f /usr/local/bin/plexdrive

echo -e "installing the latest version of plexdrive"

cd `mktemp -d`
wget -nv "${plexdrive_link}" -O plexdrive
mv plexdrive /usr/local/bin/plexdrive
chmod +x /usr/local/bin/plexdrive


systemctl restart plexdrive

echo "plexdrive is updated, and restart."
