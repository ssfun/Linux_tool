#!/usr/bin

echo -e "check root user"
[[ $EUID -ne 0 ]] && echo -e "Error: You must run this script as root!" && exit 1

arch=$(arch)
echo -e "get operating system: $(arch)"
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="armv8"
else
    echo -e "Error: The operating system is not supported."
    exit 1
fi

# getting the latest version of gost"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/go-gost/gost/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
latest_name="$(wget -qO- -t1 -T2 "https://api.github.com/repos/go-gost/gost/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
echo "${latest_name}"
gost_link="https://github.com/go-gost/gost/releases/download/${latest_version}/gost-linux-${arch}-${latest_name}.gz"

echo -e "installing the latest version of gost"
mkdir -p "/usr/local/etc/gost"
cd `mktemp -d`
wget -nv "${gost_link}" -O gost.gz
gzip -d gost.gz
mv gost /usr/local/bin/gost && chmod +x /usr/local/bin/gost

cat <<EOF >/etc/systemd/system/gost.service
[Unit]
Description=gost
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
DynamicUser=true
ExecStart=/usr/local/bin/gost -C /usr/local/etc/gost/config.yaml

[Install]
WantedBy=multi-user.target
EOF

# set config
read -p "请输入本地需要监听的端口:" lport
    [ -z "${lport}" ]
read -p "请输入需要转发的地址:" rhost
    [ -z "${rhost}" ]
read -p "请输入需要转发的端口:" rport
    [ -z "${rport}" ]
    
cat <<EOF >/usr/local/etc/gost/config.yaml
services:
- name: service-tcp
  addr: :$lport
  handler:
    type: tcp
  listener:
    type: tcp
  forwarder:
    targets:
    - $rhost:$rport
services:
- name: service-udp
  addr: :$lport
  handler:
    type: udp
  listener:
    type: udp
    metadata:
      ttl: 5s
  forwarder:
    targets:
    - $rhost:$rport
EOF

systemctl daemon-reload
systemctl reset-failed
systemctl enable gost
systemctl start gost

echo -e "gost is installed, and started."
echo -e "use 'nano /usr/local/etc/gost/config.yaml' edit gost config."
