#!/bin/sh

echo "Getting the latest version of godns"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/TimothyYe/godns/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
latest_name="$(wget -qO- -t1 -T2 "https://api.github.com/repos/TimothyYe/godns/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
echo "${latest_name}"
godns_link="https://cdn.jsdelivr.net/gh/TimothyYe/godns@releases/download/${latest_version}/godns_${latest_name}_Linux_x86_64.tar.gz"

cd `mktemp -d`
wget -nv "${godns_link}" -O godns.tar.gz
tar -zxvf godns.tar.gz

mv godns /usr/local/bin/godns && chmod +x /usr/local/bin/godns

read -p "请输入 Cloudflare ddns token:" cf_token
    [ -z "${cf_token}" ]
read -p "请输入需要更新的根域名:" domain
    [ -z "${domain}" ]
read -p "请输入需要更新的子域名:" sub_domain
    [ -z "${sub_domain}" ]
read -p "请输入 tg bot api:" tg_api
    [ -z "${tg_api}" ]
read -p "请输入 tg chat id:" tg_chatid
    [ -z "${tg_chatid}" ]
    
mkdir "/usr/local/etc/godns"
cat <<EOF >/usr/local/etc/godns/config.json
{
  "provider": "Cloudflare",
  "login_token": "$cf_token",
  "domains": [
    {
      "domain_name": "$domain",
      "sub_domains": [
        "$sub_domain"
      ]
    }
  ],
  "ip_url": "https://api.ipify.org",
  "ipv6_url": "https://ipify.org",
  "ip_type": "IPv6",
  "interval": 300,
  "resolver": "8.8.8.8",
  "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.111 Safari/537.36",
  "ip_interface": "eth0",
  "socks5_proxy": "",
  "use_proxy": false,
  "debug_info": false,
  "notify": {
    "telegram": {
      "enabled": true,
      "bot_api_key": "$tg_api",
      "chat_id": "$tg_chatid",
      "message_template": "Domain *{{ .Domain }}* is updated to %0A{{ .CurrentIP }}",
      "use_proxy": false
    }
  }
}
EOF

cat <<EOF >/etc/systemd/system/godns.service
[Unit]
Description=GoDNS Service
After=network.target

[Service]
ExecStart=/usr/local/bin/godns -c=/usr/local/etc/godns/config.json
Restart=always
KillMode=process
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable godns
systemctl start godns

echo "godns is installed, and start."
