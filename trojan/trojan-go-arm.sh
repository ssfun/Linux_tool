#!/bin/sh

echo "Getting the latest version of trojan-go"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/p4gefau1t/trojan-go/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
trojango_link="https://github.com/p4gefau1t/trojan-go/releases/download/${latest_version}/trojan-go-linux-arm.zip"

mkdir -p "/usr/local/etc/trojan-go"

cd `mktemp -d`
wget -nv "${trojango_link}" -O trojan-go.zip
unzip -q trojan-go.zip && rm -rf trojan-go.zip

mv trojan-go /usr/local/bin/trojan-go
mv geoip.dat /usr/local/etc/trojan-go/geoip.dat
mv geosite.dat /usr/local/etc/trojan-go/geosite.dat

# set trojan-go.service
cat <<EOF >/etc/systemd/system/trojan-go.service
[Unit]
Description=Trojan-Go - An unidentifiable mechanism that helps you bypass GFW
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/trojan-go -config /usr/local/etc/trojan-go/config.json
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
cat <<EOF >/usr/local/etc/trojan-go/config.json

{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": $port,
    "remote_addr": "127.0.0.1",
    "remote_port": 88,
    "password": [
        "$pswd"
    ],
    "ssl": {
        "cert": "/home/tls/certificates/acme-v02.api.letsencrypt.org-directory/$host/$host.crt",
        "key": "/home/tls/certificates/acme-v02.api.letsencrypt.org-directory/$host/$host.key",
        "cipher": "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384:TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
        "prefer_server_cipher": true,
        "alpn":[
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "plain_http_response": "",
        "sni": "$host",
        "fallback_port": 404
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "prefer_ipv4": false
    },
    "websocket": {
        "enabled": true,
        "path": "$path",
        "hostname": "$host"
    },
    "router": {
        "enabled": true,
        "block": [
            "geoip:private"
        ],
        "geoip": "/usr/local/etc/trojan-go/geoip.dat",
        "geosite": "/usr/local/etc/trojan-go/geosite.dat"
    }
}
EOF


systemctl daemon-reload
systemctl reset-failed
systemctl enable trojan-go
systemctl start trojan-go

echo "trojan-go is installed, and started."
