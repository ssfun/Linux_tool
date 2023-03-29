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

# getting the latest version of sing-box"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of sing-box: ${latest_version}"
latest_name="$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
echo "${latest_name}"
sing-box_link="https://github.com/SagerNet/sing-box/releases/download/${latest_version}/sing-box-${latest_name}-linux-${arch}.tar.gz"


mkdir -p "/usr/local/etc/sing-box"
mkdir -p "/var/log/sing-box"
mkdir -p "/var/lib/sing-box"


cd `mktemp -d`
wget -nv "${sing-box_link}" -O sing-box.tar.gz
tar -zxvf sing-box.tar.gz

mv sing-gox /usr/local/bin/sing-box && chmod +x /usr/local/bin/sing-box

# set sing-box.service
cat <<EOF >/etc/systemd/system/sing-box.service

[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
WorkingDirectory=/var/lib/sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target

EOF

# set config.json
read -p "请输入需要设置的网站host:" host
    [ -z "${host}" ]
read -p "请输入 trojan 端口:" port
    [ -z "${port}" ]
read -p "请输入 trojan 密码:" pswd
    [ -z "${pswd}" ]
read -p "请输入 trojan path:" path
    [ -z "${path}" ]

cat <<EOF >/usr/local/etc/sing-gox/config.json

{
  "log": {
    "level": "info"
  },
  "dns": {
    "servers": [
      {
        "address": "tls://8.8.8.8"
      }
    ]
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "listen": "::",
      "listen_port": 8080,
      "sniff": true,
      "network": "tcp",
      "method": "2022-blake3-aes-128-gcm",
      "password": "8JCsPssfgS8tiRwiMlhARg=="
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    },
    {
      "type": "dns",
      "tag": "dns-out"
    }
  ],
  "route": {
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      }
    ]
  }
}

EOF


systemctl daemon-reload
systemctl reset-failed
systemctl enable sing-box
systemctl start sing-box

echo "sing-box is installed, and started."
