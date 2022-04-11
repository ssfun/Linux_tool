#!/bin/sh

echo "Getting the latest version of caddy"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
caddy_link="https://github.com/lxhao61/integrated-examples/releases/download/${latest_version}/caddy_linux_amd64.tar.gz"

cd `mktemp -d`
wget -nv "${caddy_link}" -O caddy.tar.gz
tar -zxvf caddy.tar.gz

mv caddy /usr/local/bin/caddy && chmod +x /usr/local/bin/caddy

mkdir -p "/usr/local/etc/caddy"
mkdir -p "/var/www"
mkdir -p "/var/log/caddy"

# set caddy.service
cat <<EOF >/etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=root
Group=root
ExecStart=/usr/local/bin/caddy run --environ --config /usr/local/etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /usr/local/etc/caddy/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# set Caddyfile 
read -p "请输入需要设置的网站host:" host
    [ -z "${host}" ]
read -p "请输入 trojan 端口:" tport
    [ -z "${tport}" ]
read -p "请输入 trojan path:" tpath
    [ -z "${tpath}" ]
read -p "请输入 filebrowser 端口:" fport
    [ -z "${fport}" ]
cat <<EOF >/usr/local/etc/caddy/Caddyfile
{
	order reverse_proxy before route
	admin off
	log { #注意：版本不小于v2.4.0才支持日志全局配置，否则各自配置。
		level ERROR
		output file /var/log/caddy/access.log
	}
	storage file_system /home/tls #自定义证书目录
}

:443, $host { #xx.yy修改为自己的域名。注意：逗号与域名之间有一个空格。
	tls {
		ciphers TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
		alpn h2 http/1.1
	}

	@tws { #匹配器标签。此标签仅区分，多个不同代理需要改成不同名称，但要与下边‘reverse_proxy’中匹配器标签对应。
		path /$tpath #与trojan+ws应用中path对应
		header Connection *Upgrade*
		header Upgrade websocket
	}
	reverse_proxy @tws 127.0.0.1:$tport #转发给本机trojan+ws监听端口

	@host {
		host $host #限定域名访问（禁止以ip方式访问网站），修改为自己的域名。
	}
	route @host {
		header {
			Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" #启用HSTS
		}
		reverse_proxy 127.0.0.1:$fport
	}
}

EOF


systemctl daemon-reload
systemctl reset-failed
systemctl enable caddy
systemctl start caddy

echo "caddy is installed and start."
echo "use 'nano /usr/local/etc/caddy/Caddyfile' to edit caddy Caddyfile."
