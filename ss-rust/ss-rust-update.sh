#!/usr/bin

echo -e "check root user"
[[ $EUID -ne 0 ]] && echo -e "Error: You must run this script as root!" && exit 1

arch=$(arch)
echo -e "get operating system: $(arch)"
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="x86_64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="aarch64"
else
    echo -e "Error: The operating system is not supported."
    exit 1
fi

# getting the latest version of shadowsocks-rust"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of ss-rust: ${latest_version}"
ss_link="https://github.com/shadowsocks/shadowsocks-rust/releases/download/${latest_version}/shadowsocks-${latest_version}.${arch}-unknown-linux-gnu.tar.xz"

echo -e "remove the latest version of shadowsocks-rust"
systemctl stop ss-rust
rm -f /usr/local/bin/ssserver

echo -e "installing the latest version of shadowsocks-rust"
cd `mktemp -d`
wget -nv "${ss_link}" -O ss.tar.xz
xz -d ss.tar.xz && tar -xf ss.tar
mv ssserver /usr/local/bin/ssserver && chmod +x /usr/local/bin/ssserver


systemctl restart ss-rust

echo "ss-rust is updated, and restart."
