#!/bin/sh

echo "Getting the latest version of Plex"
latest_version="$(wget -qO- -t1 -T2 "https://plex.tv/api/downloads/5.json" | grep "version" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
echo "${latest_version}"
plex_link="https://downloads.plex.tv/plex-media-server-new/${latest_version}/debian/plexmediaserver_${latest_version}_arm64.deb"

cd `mktemp -d`
wget -nv "${plex_link}" -O plexmediaserver.deb
dpkg -i plexmediaserver.deb 
