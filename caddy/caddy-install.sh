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

# getting the latest version of caddy
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
echo -e "get the latest version of caddy: ${latest_version}"
caddy_link="https://github.com/lxhao61/integrated-examples/releases/download/${latest_version}/caddy-linux-${arch}.tar.gz"

echo -e "installing the latest version of caddy"
cd `mktemp -d`
wget -nv "${caddy_link}" -O caddy.tar.gz
tar -zxvf caddy.tar.gz

mv caddy /usr/local/bin/caddy && chmod +x /usr/local/bin/caddy

mkdir -p "/usr/local/etc/caddy"
mkdir -p "/var/www"
mkdir -p "/var/www/404"
mkdir -p "/var/log/caddy"

# get 404.html
curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/404/index.html  -o /var/www/404/index.html

echo -e "set caddy.service"
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

echo -e "set Caddyfile"
read -p "请输入需要设置的网站host:" host
    [ -z "${host}" ]
read -p "请输入 trojan 密码:" pswd
    [ -z "${pswd}" ]
read -p "请输入 filebrowser 端口:" port
    [ -z "${port}" ]
cat <<EOF >/usr/local/etc/caddy/Caddyfile
{
        order trojan before route
        order forward_proxy before trojan
        order reverse_proxy before forward_proxy
        admin off
        log {
                output file /var/log/caddy/error.log
                level ERROR
        }       #版本不小于v2.4.0才支持日志全局配置，否则各自配置。
        storage file_system {
                root /home/tls #存放TLS证书的基本路径
        }

        cert_issuer acme #acme表示从Let's Encrypt申请TLS证书，zerossl表示从ZeroSSL申请TLS证书。必须acme与zerossl二选一（固定TLS证书的目录便于引用）。注意：版本不小于v2.4.1才支持。
        email qq1112q@gmx.com #电子邮件地址。选配，推荐。

        servers 127.0.0.1:88 {
                #与下边本地监听端口对应
                listener_wrappers {
                        proxy_protocol #开启PROXY protocol接收
                }
                protocols h1 h2c #开启HTTP/1.1 server与H2C server支持
        }
        servers :443 {
                #与下边本地监听端口对应
                listener_wrappers {
                        trojan #caddy-trojan插件应用必须配置
                }
                protocols h1 h2 h3 #开启HTTP/3 server支持（默认，此条参数可以省略不写。）。若采用HAProxy SNI分流（目前不支持UDP转发），推荐不开启。
        }
        trojan {
                caddy
                no_proxy
                users $pswd #修改为自己的密码。密码可多组，用空格隔开。
        }
}

:80 {
        #HTTP默认监听端口
        redir https://{host}{uri} permanent #HTTP自动跳转HTTPS，让网站看起来更真实。
}

:88 {
        #HTTP/1.1 server及H2C server监听端口
        bind 127.0.0.1 #绑定本地主机，避免本机外的机器探测到上面端口。
        @host {
                host $host #限定域名访问（禁止以ip方式访问网站），修改为自己的域名。
        }
        route @host {
                header {
                        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" #启用HSTS
                }
                reverse_proxy 127.0.0.1:40333
        }
}

:443, $host:443 {
        #HTTPS server监听端口。注意：逗号与域名（或含端口）之间有一个空格。
        tls {
                ciphers TLS_AES_256_GCM_SHA384 TLS_AES_128_GCM_SHA256 TLS_CHACHA20_POLY1305_SHA256 TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
                curves x25519 secp521r1 secp384r1 secp256r1
        }
        trojan {
                connect_method
                websocket #开启WebSocket支持
        }       #此部分配置为caddy-trojan插件的WebSocket应用，若删除就仅支持Trojan应用。
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

echo -e "start caddy"
systemctl daemon-reload
systemctl reset-failed
systemctl enable caddy
systemctl start caddy

echo -e "caddy is installed, and started."
echo -e "use 'nano /usr/local/etc/caddy/Caddyfile' edit caddy Caddyfile."
