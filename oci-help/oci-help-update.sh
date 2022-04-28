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

# getting the latest version of oci-help"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lemoex/oci-help/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of oci-help: ${latest_version}"
oci_link="https://github.com/lemoex/oci-help/releases/download/${latest_version}/oci-help-linux-${arch}-${latest_version}.zip"

echo -e "remove the latest version of oci-help"
rm -f /root/oci/oci-help

echo -e "installing the latest version of oci-help"
cd `mktemp -d`
wget -nv "${oci_link}" -O oci.zip
unzip oci.zip
mv oci-help /root/oci/oci-help && chmod +x /root/oci/oci-help

echo "oci-help is updated."
