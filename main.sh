#!/bin/bash

#####################################################
# ssfun's Linux Tool
# Author: ssfun
# Date: 2023-04-01
# Version: 1.0.0
#####################################################

#Basic definitions
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
pink='\033[1;35m'
green='\033[0;32m'
yellow='\033[0;33m'

#os arch evn
OS=''
ARCH=''

#caddy env
CADDY_VERSION=''
CADDY_CONFIG_PATH='/usr/local/etc/caddy'
CADDY_LOG_PATH='/var/log/caddy'
CADDY_TLS_PATH='/home/tls'
CADDY_WWW_PATH='/var/www'
CADDY_404_PATH='/var/www/404'
CADDY_BINARY='/usr/local/bin/caddy'
CADDY_SERVICE='/etc/systemd/system/caddy.service'

#caddy status define
declare -r CADDY_STATUS_RUNNING=1
declare -r CADDY_STATUS_NOT_RUNNING=0
declare -r CADDY_STATUS_NOT_INSTALL=255

#filebrowser env
FILEBROWSER_VERSION=''
FILEBROWSER_CONFIG_PATH='/usr/local/etc/filebrowser'
FILEBROWSER_LOG_PATH='/var/log/filebrowser'
FILEBROWSER_DATA_PATH='/home/filebrowser'
FILEBROWSER_DATABASE_PATH='/opt/filebrowser'
FILEBROWSER_BINARY='/usr/local/bin/filebrowser'
FILEBROWSER_SERVICE='/etc/systemd/system/filebrowser.service'

#filebrowser status define
declare -r FILEBROWSER_STATUS_RUNNING=1
declare -r FILEBROWSER_STATUS_NOT_RUNNING=0
declare -r FILEBROWSER_STATUS_NOT_INSTALL=255

#plex env
PLEX_LIBRARY_PATH='/var/lib/plexmediaserver'
PLEX_SERVICE='/lib/systemd/system/plexmediaserver.service'

#plex status define
declare -r PLEX_STATUS_RUNNING=1
declare -r PLEX_STATUS_NOT_RUNNING=0
declare -r PLEX_STATUS_NOT_INSTALL=255

#utils 
function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}

function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

#root user check
[[ $EUID -ne 0 ]] && LOGE "请使用root用户运行该脚本" && exit 1

#System check
os_check() {
    LOGI "检测当前系统中..."
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        OS="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        OS="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS="centos"
    else
        LOGE "系统检测错误,当前系统不支持!" && exit 1
    fi
    LOGI "系统检测完毕,当前系统为:${OS}"
}

arch_check() {
    LOGI "检测当前系统架构中..."
    ARCH=$(arch)
    LOGI "当前系统架构为 ${ARCH}"
    if [[ ${ARCH} == "x86_64" || ${ARCH} == "x64" || ${ARCH} == "amd64" ]]; then
        ARCH="amd64"
    elif [[ ${ARCH} == "aarch64" || ${ARCH} == "arm64" ]]; then
        ARCH="arm64"
    else
        LOGE "检测系统架构失败,当前系统架构不支持!" && exit 1
    fi
    LOGI "系统架构检测完毕,当前系统架构为:${ARCH}"
}

#install some common utils
install_base() {
    if [[ ${OS} == "ubuntu" || ${OS} == "debian" ]]; then
        if ! dpkg -s wget tar >/dev/null 2>&1; then
            apt install wget tar -y
        fi
    elif [[ ${OS} == "centos" ]]; then
        if ! rpm -q wget tar >/dev/null 2>&1; then
            yum install wget tar -y
        fi
    fi
}

#plex status check,-1 means didn't install,0 means failed,1 means running
plex_status_check() {
    if [[ ! -f "${PLEX_SERVICE}" ]]; then
        return ${PLEX_STATUS_NOT_INSTALL}
    fi
    local plex_status_temp=$(systemctl is-active plexmediaserver)
    if [[ "${plex_status_temp}" == "active" ]]; then
        return ${PLEX_STATUS_RUNNING}
    else
        return ${PLEX_STATUS_NOT_RUNNING}
    fi
}

show_plex_status() {
    plex_status_check
    case $? in
    0)
        echo -e "[INF] plex状态: ${yellow}未运行${plain}"
        show_plex_enable_status
        ;;
    1)
        echo -e "[INF] plex状态: ${green}已运行${plain}"
        show_plex_enable_status
        show_plex_running_status
        ;;
    255)
        echo -e "[INF] plex状态: ${red}未安装${plain}"
        ;;
    esac
}

show_plex_running_status() {
    plex_status_check
    if [[ $? == ${PLEX_STATUS_RUNNING} ]]; then
        local plex_runTime=$(systemctl status plexmediaserver | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "plex运行时长：${plex_runTime}"
    else
        LOGE "plex未运行"
    fi
}

show_plex_enable_status() {
    local plex_enable_status_temp=$(systemctl is-enabled plexmediaserver)
    if [[ "${plex_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] plex是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] plex是否开机自启: ${red}否${plain}"
    fi
}

install_plex() {
    LOGD "开始下载 plex..."
    os_check && arch_check && install_base
    # getting the latest version of plex"
    LATEST_PLEX_VERSION="$(wget -qO- -t1 -T2 "https://plex.tv/api/downloads/5.json" | grep -o '"version":"[^"]*' | grep -o '[^"]*$' | head -n 1)"
    PLEX_LINK="https://downloads.plex.tv/plex-media-server-new/${LATEST_PLEX_VERSION}/debian/plexmediaserver_${LATEST_PLEX_VERSION}_${ARCH}.deb"
    cd `mktemp -d`
    wget -nv "${PLEX_LINK}" -O plexmediaserver.deb
    dpkg -i plexmediaserver.deb
    LOGI "plex 已完成安装"
}

update_plex() {
    LOGD "开始更新plex..."
    if [[ ! -f "${PLEX_SERVICE}" ]]; then
        LOGE "当前系统未安装plex,更新失败"
        show_menu
    fi
    os_check && arch_check
    install_plex
    LOGI "plex 已完成升级"
}

uninstall_plex() {
    LOGD "开始卸载plex..."
    dpkg -r plexmediaserver
    rm -rf ${PLEX_LIBRARY_PATH}
    LOGI "卸载plex成功"
}

#filebrowser status check,-1 means didn't install,0 means failed,1 means running
fb_status_check() {
    if [[ ! -f "${FILEBROWSER_SERVICE}" ]]; then
        return ${FILEBROWSER_STATUS_NOT_INSTALL}
    fi
    filebrowser_status_temp=$(systemctl is-active filebrowser)
    if [[ "${filebrowser_status_temp}" == "active" ]]; then
        return ${FILEBROWSER_STATUS_RUNNING}
    else
        return ${FILEBROWSER_STATUS_NOT_RUNNING}
    fi
}

show_fb_status() {
    fb_status_check
    case $? in
    0)
        echo -e "[INF] filebrowser 状态: ${yellow}未运行${plain}"
        show_fb_enable_status
        ;;
    1)
        echo -e "[INF] filebrowser 状态: ${green}已运行${plain}"
        show_fb_enable_status
        show_fb_running_status
        ;;
    255)
        echo -e "[INF] filebrowser 状态: ${red}未安装${plain}"
        ;;
    esac
}

show_fb_running_status() {
    fb_status_check
    if [[ $? == ${FILEBROWSER_STATUS_RUNNING} ]]; then
        local fb_runTime=$(systemctl status filebrowser | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "filebrowser 运行时长：${fb_runTime}"
    else
        LOGE "filebrowser 未运行"
    fi
}

show_fb_enable_status() {
    local fb_enable_status_temp=$(systemctl is-enabled filebrowser)
    if [[ "${fb_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] filebrowser 是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] filebrowser 是否开机自启: ${red}否${plain}"
    fi
}

download_fb() {
    LOGD "开始下载 filebrowser..."
    # getting the latest version of caddy & filebrowser"
    LATEST_FILEBROWSER_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/filebrowser/filebrowser/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
    FILEBROWSER_LINK="https://github.com/filebrowser/filebrowser/releases/download/${LATEST_FILEBROWSER_VERSION}/linux-${ARCH}-filebrowser.tar.gz"
    cd `mktemp -d`
    wget -nv "${FILEBROWSER_LINK}" -O filebrowser.tar.gz
    tar -zxvf filebrowser.tar.gz
    mv filebrowser ${FILEBROWSER_BINARY} && chmod +x ${FILEBROWSER_BINARY}
    LOGI "filebrowser 下载完毕"
}

install_fb_systemd_service() {
    LOGD "开始安装 filebrowser systemd 服务..."
    cat <<EOF >${FILEBROWSER_SERVICE}
[Unit]
Description=filebrowser
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
User=root
Restart=on-failure
RestartSec=5s
ExecStart=${FILEBROWSER_BINARY} -c ${FILEBROWSER_CONFIG_PATH}/config.json
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable filebrowser
    LOGD "安装 filebrowser systemd 服务成功"
}

configuration_fb_config() {
    LOGD "开始配置 filebrowser 配置文件..."
    # set config
    cat <<EOF >${FILEBROWSER_CONFIG_PATH}/config.json
{
    "address":"127.0.0.1",
    "database":"${FILEBROWSER_DATABASE_PATH}/filebrowser.db",
    "log":"${FILEBROWSER_LOG_PATH}/filebrowser.log",
    "port":40333,
    "root":"${FILEBROWSER_DATA_PATH}",
    "username":"admin"
}
EOF
    LOGD "filebrowser 配置文件完成"
}

install_fb() {
    LOGD "开始安装 filebrowser..."
    os_check && arch_check && install_base
    mkdir -p "${FILEBROWSER_CONFIG_PATH}"
    mkdir -p "${FILEBROWSER_LOG_PATH}"
    mkdir -p "${FILEBROWSER_DATABASE_PATH}"
    mkdir -p "${FILEBROWSER_DATA_PATH}"
    download_fb
    install_fb_systemd_service
    configuration_fb_config
    systemctl start filebrowser
    LOGI "filebrowser 已完成安装"
}

update_fb() {
    LOGD "开始更新 filebrowser..."
    if [[ ! -f "${FILEBROWSER_SERVICE}" ]]; then
        LOGE "当前系统未安装 filebrowser,更新失败"
        show_menu
    fi
    os_check && arch_check && install_base
    systemctl stop filebrowser
    rm -f ${FILEBROWSER_BINARY}
    # getting the latest version of filebrowser"
    download_fb
    LOGI "filebrowser 启动成功"
    systemctl restart filebrowser
    LOGI "filebrowser 已完成升级"
}

uninstall_fb() {
    LOGD "开始卸载 filebrowser..."
    systemctl stop filebrowser
    systemctl disable filebrowser
    rm -f ${FILEBROWSER_SERVICE}
    systemctl daemon-reload
    rm -f ${FILEBROWSER_BINARY}
    rm -rf ${FILEBROWSER_CONFIG_PATH}
    rm -rf ${FILEBROWSER_LOG_PATH}
    rm -rf ${FILEBROWSER_DATABASE_PATH}
    rm -rf ${FILEBROWSER_DATA_PATH}
    LOGI "卸载 filebrowser 成功"
}

#caddy status check,-1 means didn't install,0 means failed,1 means running
caddy_status_check() {
    if [[ ! -f "${CADDY_SERVICE}" ]]; then
        return ${CADDY_STATUS_NOT_INSTALL}
    fi
    caddy_status_temp=$(systemctl is-active caddy)
    if [[ "${caddy_status_temp}" == "active" ]]; then
        return ${CADDY_STATUS_RUNNING}
    else
        return ${CADDY_STATUS_NOT_RUNNING}
    fi
}

show_caddy_status() {
    caddy_status_check
    case $? in
    0)
        echo -e "[INF] caddy状态: ${yellow}未运行${plain}"
        show_caddy_enable_status
        ;;
    1)
        echo -e "[INF] caddy状态: ${green}已运行${plain}"
        show_caddy_enable_status
        show_caddy_running_status
        ;;
    255)
        echo -e "[INF] caddy状态: ${red}未安装${plain}"
        ;;
    esac
}

show_caddy_running_status() {
    caddy_status_check
    if [[ $? == ${CADDY_STATUS_RUNNING} ]]; then
        local caddy_runTime=$(systemctl status caddy | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "caddy运行时长：${caddy_runTime}"
    else
        LOGE "caddy未运行"
    fi
}

show_caddy_enable_status() {
    local caddy_enable_status_temp=$(systemctl is-enabled caddy)
    if [[ "${caddy_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] caddy是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] caddy是否开机自启: ${red}否${plain}"
    fi
}

download_caddy() {
    LOGD "开始下载 caddy..."
    # getting the latest version of caddy"
    LATEST_CADDY_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
    CADDY_LINK="https://github.com/lxhao61/integrated-examples/releases/download/${LATEST_CADDY_VERSION}/caddy-linux-${ARCH}.tar.gz"
    cd `mktemp -d`
    wget -nv "${CADDY_LINK}" -O caddy.tar.gz
    tar -zxvf caddy.tar.gz
    mv caddy ${CADDY_BINARY} && chmod +x ${CADDY_BINARY}
    LOGI "caddy 下载完毕"
}

install_caddy_systemd_service() {
    LOGD "开始安装 caddy systemd 服务..."
    cat <<EOF >${CADDY_SERVICE}
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target
[Service]
Type=notify
User=root
Group=root
ExecStart=${CADDY_BINARY} run --environ --config ${CADDY_CONFIG_PATH}/Caddyfile
ExecReload=${CADDY_BINARY} reload --config ${CADDY_CONFIG_PATH}/Caddyfile
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable caddy
    LOGD "安装 caddy systemd 服务成功"
}

configuration_caddy_config() {
    LOGD "开始配置caddy配置文件..."
    read -p "请输入需要设置的网站host:" host
        [ -z "${host}" ]
    read -p "请输入 trojan 密码:" pswd
        [ -z "${pswd}" ]
    read -p "请输入申请证书mail:" mail
        [ -z "${mail}" ]  
    # set Caddyfile
    cat <<EOF >${CADDY_CONFIG_PATH}/Caddyfile
{
        order trojan before route
        order forward_proxy before trojan
        order reverse_proxy before forward_proxy
        admin off
        log {
                output file /${CADDY_LOG_PATH}/caddy.log
                level ERROR
        }       #版本不小于v2.4.0才支持日志全局配置，否则各自配置。
        storage file_system {
                root ${CADDY_TLS_PATH} #存放TLS证书的基本路径
        }
        cert_issuer acme #acme表示从Let's Encrypt申请TLS证书，zerossl表示从ZeroSSL申请TLS证书。必须acme与zerossl二选一（固定TLS证书的目录便于引用）。注意：版本不小于v2.4.1才支持。
        email $mail #电子邮件地址。选配，推荐。
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
                reverse_proxy 127.0.0.1:40333
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
    LOGD "caddy 配置文件完成"
}

configuration_caddy_config_with_plex() {
    LOGD "开始配置caddy配置文件..."
    read -p "请输入需要设置的网站host:" host
        [ -z "${host}" ]
    read -p "请输入申请证书的mail:" mail
        [ -z "${mail}" ]
    read -p "请输入 trojan 密码:" pswd
        [ -z "${pswd}" ]
    read -p "请输入需要设置的Plex网站:" plex
        [ -z "${plex}" ]
    # set Caddyfile
    cat <<EOF >${CADDY_CONFIG_PATH}/Caddyfile
{
        order trojan before route
        order forward_proxy before trojan
        order reverse_proxy before forward_proxy
        admin off
        log {
                output file ${CADDY_LOG_PATH}/caddy.log
                level ERROR
        }       #版本不小于v2.4.0才支持日志全局配置，否则各自配置。
        storage file_system {
                root ${CADDY_TLS_PATH} #存放TLS证书的基本路径
        }
        cert_issuer acme #acme表示从Let's Encrypt申请TLS证书，zerossl表示从ZeroSSL申请TLS证书。必须acme与zerossl二选一（固定TLS证书的目录便于引用）。注意：版本不小于v2.4.1才支持。
        email $mail #电子邮件地址。选配，推荐。
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
:443, $host:443, $plex:443 {
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
                reverse_proxy 127.0.0.1:40333
        }
        @plex {
                host $plex #限定域名访问（禁止以ip方式访问网站），修改为自己的域名。
        }
        route @plex {
                header {
                        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" #启用HSTS
                        X-Content-Type-Options nosniff
                        X-Frame-Options DENY
                        Referrer-Policy no-referrer-when-downgrade
                        X-XSS-Protection 1
                }
                reverse_proxy 127.0.0.1:32400
                encode gzip
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
    LOGD "caddy 配置文件完成"
}

install_caddy_without_plex() {
    LOGD "开始安装 caddy..."
    mkdir -p "${CADDY_CONFIG_PATH}"
    mkdir -p "${CADDY_WWW_PATH}"
    mkdir -p "${CADDY_404_PATH}"
    mkdir -p "${CADDY_LOG_PATH}"
    curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/404/index.html  -o ${CADDY_404_PATH}/index.html
    download_caddy
    install_caddy_systemd_service
    configuration_caddy_config
    systmctl start caddy
    LOGI "caddy 已完成安装"
}

install_caddy_with_plex() {
    LOGD "开始安装 caddy..."
    mkdir -p "${CADDY_CONFIG_PATH}"
    mkdir -p "${CADDY_WWW_PATH}"
    mkdir -p "${CADDY_404_PATH}"
    mkdir -p "${CADDY_LOG_PATH}"
    curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/404/index.html  -o ${CADDY_404_PATH}/index.html
    download_caddy
    install_caddy_systemd_service
    configuration_caddy_config_with_plex
    LOGI "caddy 已完成安装"
}

update_caddy() {
    LOGD "开始更新caddy..."
    if [[ ! -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统未安装caddy,更新失败"
        show_menu
    fi
    os_check && arch_check
    systemctl stop caddy
    rm -f ${CADDY_BINARY}
    # getting the latest version of caddy"
    download_caddy
    LOGI "caddy 启动成功"
    systemctl restart caddy
    LOGI "caddy 已完成升级"
}

uninstall_caddy() {
    LOGD "开始卸载caddy..."
    systemctl stop caddy
    systemctl disable caddy
    rm -f ${CADDY_SERVICE}
    systemctl daemon-reload
    rm -f ${CADDY_BINARY}
    rm -rf ${CADDY_CONFIG__PATH}
    rm -rf ${CADDY_LOG_PATH}
    rm -rf ${CADDY_WWW_PATH}
    rm -rf ${CADDY_TLS_PATH}
    LOGI "卸载caddy 成功"
}

install_all_without_plex() {
    LOGD "开始安装 caddy + filebrowser"
    if [[ -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    elif [[ -f "${FILEBROWSER_SERVICE}" ]]; then
        LOGE "当前系统已安装 filebrowser,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    os_check && arch_check && install_base
    install_caddy_without_plex
    install_fb
    LOGI "caddy + filebrowser 已完成安装"
}

install_all_with_plex() {
    LOGD "开始安装 caddy + filebrowser + plex"
    if [[ -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    elif [[ -f "${FILEBROWSER_SERVICE}" ]]; then
        LOGE "当前系统已安装 filebrowser,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    os_check && arch_check && install_base
    install_caddy_with_plex
    install_sing-box
    install_plex
    LOGI "caddy + plex + filebrowser 已完成安装"
}

#show menu
show_menu() {
    echo -e "
  ${green}Caddy (trojan) | Filebrowser  | Plex 管理脚本${plain}
  ————————————————
  ${green}Q.${plain} 退出脚本
  ————————————————
  ${green}0.${plain} 安装 caddy + filebrowser
  ${green}1.${plain} 安装 caddy + filebrowser + plex
  ————————————————
  ${green}2.${plain} 安装 caddy
  ${green}3.${plain} 更新 caddy
  ${green}4.${plain} 卸载 caddy
  ————————————————
  ${green}5.${plain} 安装 filebrowser
  ${green}6.${plain} 更新 filebrowser
  ${green}7.${plain} 卸载 filebrowser
  ————————————————
  ${green}8.${plain} 更新 plex
  ${green}9.${plain} 卸载 plex
 "
    show_caddy_status
    show_fb_status
    show_plex_status
    echo && read -p "请输入选择[0-9]:" num

    case "${num}" in
    Q)
        exit 0
        ;;
    0)
        install_all_without_plex && show_menu
        ;;
    1)
        install_all_with_plex && show_menu
        ;;
    2)
        install_caddy_without_plex && show_menu
        ;;
    3)
        update_caddy && show_menu
        ;;
    4)
        uninstall_caddy && show_menu
        ;;
    5)
        install_fb && show_menu
        ;;
    6)
        update_fb && show_menu
        ;;
    7)
        uninstall_fb && show_menu
        ;;
    8)
        install_plex && show_menu
        ;;
    9)
        uninstall_plex && show_menu
        ;;
    *)
        LOGE "请输入正确的选项 [0-9]"
        ;;
    esac
}

main(){
    show_menu
}

main $*
