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
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/ssfun/Linux_tool/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of sing-box: ${latest_version}"
link="https://github.com/ssfun/Linux_tool/releases/download/${latest_version}/sing-box-linux-${arch}.tar.gz"


mkdir -p "/usr/local/etc/sing-box"
mkdir -p "/var/log/sing-box"
mkdir -p "/var/lib/sing-box"


cd `mktemp -d`
wget -nv "${link}" -O sing-box.tar.gz
tar -zxvf sing-box.tar.gz

mv sing-box /usr/local/bin/sing-box && chmod +x /usr/local/bin/sing-box

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
read -p "请输入 trojan 网站:" trojanhost
    [ -z "${trojanhost}" ]
read -p "请输入 trojan 端口:" trojanport
    [ -z "${trojanport}" ]
read -p "请输入 trojan 密码:" trojanpswd
    [ -z "${trojanpswd}" ]
read -p "请输入 ws path:" wspath
    [ -z "${wspath}" ]
read -p "请输入 vmess 端口:" vmessport
    [ -z "${vmessport}" ]    
read -p "请输入 vmess UUID:" vmessuuid
    [ -z "${vmessuuid}" ]  
read -p "请输入 warp ipv4:" warpipv4
    [ -z "${warpipv4}" ]  
read -p "请输入 warp ipv6:" warpipv6
    [ -z "${warpipv6}" ]  
read -p "请输入 warp private key:" warpprivatekey
    [ -z "${warpprivatekey}" ]  
read -p "请输入 warp public key:" warppublickey
    [ -z "${warppublickey}" ]  
read -p "请输入 warp reserved:" warpreserved
    [ -z "${warpreserved}" ]  

cat <<EOF >/usr/local/etc/sing-box/config.json

{
    "log":{
        "level":"info",
        "output":"/var/log/sing-box/sing-box.log",
        "timestamp":true
    },
    "inbounds":[
        {
            "type":"trojan",
            "tag":"trojan-in",
            "listen":"0.0.0.0",
            "listen_port":$trojanport,
            "tcp_fast_open":true,
            "udp_fragment":true,
            "sniff":true,
            "sniff_override_destination":false,
            "udp_timeout":300,
            "proxy_protocol":true,
            "proxy_protocol_accept_no_header":false,
            "users":[
                {
                    "name":"trojan",
                    "password":"$trojanpswd"
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"$trojanhost",
                "alpn":[
                    "h2",
                    "http/1.1"
                ],
                "min_version":"1.2",
                "max_version":"1.3",
                "cipher_suites":[
                    "TLS_CHACHA20_POLY1305_SHA256",
                    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
                    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
                ],
                "certificate_path":"/home/tls/certificates/acme-v02.api.letsencrypt.org-directory/$trojanhost/$trojanhost.crt",
                "key_path":"/home/tls/certificates/acme-v02.api.letsencrypt.org-directory/$trojanhost/$trojanhost.key"
            },
            "fallback":{
                "server":"127.0.0.1",
                "server_port":404
            },
            "transport":{
                "type":"ws",
                "path":"/$wspath",
                "max_early_data":0,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            }
        },
        {
            "type":"vmess",
            "tag":"vmess-in",
            "listen":"0.0.0.0",
            "listen_port":$vmessport,
            "tcp_fast_open":true,
            "udp_fragment":true,
            "sniff":true,
            "sniff_override_destination":false,
            "proxy_protocol":true,
            "proxy_protocol_accept_no_header":false,
            "users":[
                {
                    "name":"vmess",
                    "uuid":"$vmessuuid",
                    "alterId":0
                }
            ],
            "transport":{
                "type":"ws",
                "path":"/$wspath",
                "max_early_data":0,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            }
        }
    ],
    "outbounds":[
        {
            "type":"direct",
            "tag":"direct"
        },
        {
            "type":"wireguard",
            "tag":"wireguard-out",
            "server":"engage.cloudflareclient.com",
            "server_port":2408,
            "local_address":[
                "$warpipv4",
                "$warpipv6"
            ],
            "private_key":"$warpprivatekey",
            "peer_public_key":"$warppublickey",
            "reserved":[$warpreserved],
            "mtu":1280
        }
    ],
    "route":{
        "rules":[
            {
                "inbound":[
                    "trojan-in",
                    "vmess-in"
                ],
                "domain_suffix":[
                    "openai.com",
                    "ai.com"
                ],
                "outbound":"wireguard-out"
            }
        ],
        "final":"direct"
    }
}

EOF


systemctl daemon-reload
systemctl reset-failed
systemctl enable sing-box
systemctl start sing-box

echo "sing-box is installed, and started."
