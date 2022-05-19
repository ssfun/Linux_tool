#!/usr/bin

echo -e "check root user"
[[ $EUID -ne 0 ]] && echo -e "Error: You must run this script as root!" && exit 1

arch=$(arch)
echo -e "get the operating system: $(arch)"
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    echo -e "Error: The operating system is not supported."
    exit 1
fi

# getting the latest version of plex media server"
latest_version="$(wget -qO- -t1 -T2 "https://plex.tv/api/downloads/5.json" | grep -o '"version":"[^"]*' | grep -o '[^"]*$' | head -n 1)"
echo -e "get the latest version of plex media server: ${latest_version}"
plex_link="https://downloads.plex.tv/plex-media-server-new/${latest_version}/debian/plexmediaserver_${latest_version}_${arch}.deb"

cd `mktemp -d`
wget -nv "${plex_link}" -O plexmediaserver.deb
dpkg -i plexmediaserver.deb

echo -e "plex media server is installed, and started."
