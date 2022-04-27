#!/bin/sh

echo "check root user"
check_if_running_as_root() {
  # If you want to run as another user, please modify $EUID to be owned by this user
  if [[ "$EUID" -ne '0' ]]; then
    echo "error: You must run this script as root!"
    exit 1
  fi
}

echo "check operating system"
identify_the_operating_system() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'amd64' | 'x86_64')
        MACHINE='amd64'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    if [[ ! -f '/etc/os-release' ]]; then
      echo "error: Don't use outdated Linux distributions."
      exit 1
    fi
}

echo "Getting the latest version of caddy"
latest_version="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"

echo "${latest_version}"
caddy_link="https://github.com/lxhao61/integrated-examples/releases/download/${latest_version}/caddy_linux_$MACHINE.tar.gz"

echo "download latest version"
cd `mktemp -d`
wget -nv "${caddy_link}" -O caddy.tar.gz
tar -zxvf caddy.tar.gz

mv caddy /usr/local/bin/caddy && chmod +x /usr/local/bin/caddy

mkdir -p "/usr/local/etc/caddy"
mkdir -p "/var/log/caddy"

echo "set caddy.service"
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
read -p "请输入需要设置的ddns host:" host
    [ -z "${host}" ]
read -p "请输入cloudflare api key:" apikey
    [ -z "${apikey}" ]
cat <<EOF >/usr/local/etc/caddy/Caddyfile
{
	log { #注意：版本不小于v2.4.0才支持日志全局配置，否则各自配置。
		output file /var/log/caddy/access.log
		level ERROR
	}
        dynamic_dns { #加了caddy-dynamicdns插件编译的才支持DDNS应用
		provider cloudflare $apikey #可修改为其它caddy-dns插件（必须加了对应插件编译的才支持）及对应caddy-dns插件的token
		domains {
			$host #修改为关联的域名
		}
		check_interval 5m
		ip_source simple_http https://icanhazip.com
	}
}
EOF

echo "start caddy"
systemctl daemon-reload
systemctl reset-failed
systemctl enable caddy
systemctl start caddy

echo "caddy is installed, and started."
echo "use 'nano /usr/local/etc/caddy/Caddyfile' edit caddy Caddyfile."
