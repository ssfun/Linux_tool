#!/bin/sh

echo "Getting the latest version of caddy"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo "${latest_version}"
caddy_link="https://github.com/lxhao61/integrated-examples/releases/download/${latest_version}/caddy_linux_amd64.tar.gz"

cd `mktemp -d`
wget -nv "${caddy_link}" -O caddy.tar.gz
tar -zxvf caddy.tar.gz

mv caddy /usr/local/bin/caddy && chmod +x /usr/local/bin/caddy

mkdir -p "/etc/caddy"
mkdir -p "/var/www"
mkdir -p "/var/www/404"
mkdir -p "/var/log/caddy"

# get 404.html
curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/index.html  -o /var/www/404/index.html

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
ExecStart=/usr/local/bin/caddy/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy/caddy reload --config /etc/caddy/Caddyfile
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
read -p "请输入 trojan 密码:" pswd
    [ -z "${pswd}" ]
read -p "请输入 filebrowser 端口:" port
    [ -z "${port}" ]
cat <<EOF >/etc/caddy/Caddyfile
{
	order trojan before route
	admin off
	log { #注意：版本不小于v2.4.0才支持日志全局配置，否则各自配置。
		level ERROR
		output file /var/log/caddy/access.log
	}
	storage file_system /home/tls #自定义证书目录
	servers :443 {
		listener_wrappers {
			trojan #caddy-trojan插件应用必须配置
		}
		protocol {
			allow_h2c #caddy-trojan插件应用必须启用
		}
	}
	auto_https off #禁用自动https
	servers 127.0.0.1:88 { #与下边本地监听端口对应
		protocol {
			allow_h2c #开启h2c server支持
		}
	}
}

:80 { #http默认监听端口
	redir https://{host}{uri} permanent #http自动跳转https,让网站看起来更真实。
}

:88 { #http/1.1与h2c server监听端口
	bind 127.0.0.1 #绑定本地主机，避免本机外的机器探测到上面端口。
	@host {
		host $host #限定域名访问（禁止以ip方式访问网站），修改为自己的域名。
	}
	route @host {
		header {
			Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" #启用HSTS
		}
      reverse_proxy 127.0.0.1:$port
	}
}

:443, $host { #xx.yy修改为自己的域名。注意：逗号与域名之间有一个空格。
	tls {
		ciphers TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
		alpn h2 http/1.1
	}

	trojan {
		user $pswd #修改为自己的密码。密码可多组，用空格隔开。
		connect_method
		websocket #开启WebSocket支持
	}

	@host {
		host $host #限定域名访问（禁止以ip方式访问网站），修改为自己的域名。
	}
	route @host {
		header {
			Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" #启用HSTS
		}
		reverse_proxy 127.0.0.1:$port
	}
}

http://$host:404 {
        @host {
                host $host #限定域名访问（禁止以ip方式访问网站），修改为自己的域名。
        }
        route @host {
		file_server {
	                root /var/www/404 #修改为自己存放的WEB文件路径
		}
        }
}
EOF


systemctl daemon-reload
systemctl reset-failed
systemctl enable caddy

echo "caddy is installed. use 'systemctl start caddy' start caddy."
echo "use '/etc/caddy/Caddyfile' edit caddy config."
