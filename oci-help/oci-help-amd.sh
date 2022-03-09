#!/bin/sh

echo "Getting the latest version of oci-help"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lemoex/oci-help/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
oci_link="https://github.com/lemoex/oci-help/releases/download/${latest_version}/gost-linux-amd64-${latest_version}.zip"

mkdir -p "/root/oci"

wget -nv "${oci_link}" -O oci.zip
unzip oci.zip -d /root/oci && rm -f oci.zip
chmod +x /root/oci/oci-help

echo "oci-help is installed. use 'apt install screen' to install screen, then 'screen -S oci-help' "
