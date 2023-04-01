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

#os
OS=''

#arch
ARCH=''

# CADDY ENV ##############################
#caddy version
CADDY_VERSION=''
#config install path
CADDY_CONFIG_PATH='/usr/local/etc/caddy'
#binary install path
CADDY_BINARY_PATH='/usr/local/bin/caddy'
#service install path
CADDY_SERVICE_PATH='/etc/systemd/system/caddy.service'
#log file save path
CADDY_LOG_PATH='/usr/local/caddy/caddy.log'

#caddy status define
declare -r CADDY_STATUS_RUNNING=1
declare -r CADDY_STATUS_NOT_RUNNING=0
declare -r CADDY_STATUS_NOT_INSTALL=255
#########################################

# SING-BOX ENV ###########################
#sing-box version
SING_BOX_VERSION=''
#config install path
SING_BOX_CONFIG_PATH='/usr/local/etc/sing-box'
#binary install path
SING_BOX_BINARY_PATH='/usr/local/bin/sing-box'
#service install path
SING_BOX_SERVICE_PATH='/etc/systemd/system/sing-box.service'
#log file save path
SING_BOX_LOG_PATH='/usr/local/sing-box/sing-box.log'

#sing-box status define
declare -r SING_BOX_STATUS_RUNNING=1
declare -r SING_BOX_STATUS_NOT_RUNNING=0
declare -r SING_BOX_STATUS_NOT_INSTALL=255
##########################################

# UTILS #####################################
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
###########################################

# SYSTEM ##################################
#Root check
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

#arch check
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
        apt install wget tar -y
    elif [[ ${OS} == "centos" ]]; then
        yum install wget tar -y
    fi
}
###########################################################

# CADDY STATUS ############################################
#caddy status check,-1 means didn't install,0 means failed,1 means running
caddy_status_check() {
    if [[ ! -f "${CADDY_SERVICE_PATH}" ]]; then
        return ${CADDY_STATUS_NOT_INSTALL}
    fi
    temp=$(systemctl status caddy | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return ${CADDY_STATUS_RUNNING}
    else
        return ${CADDY_STATUS_NOT_RUNNING}
    fi
}

#show caddy status
show_caddy_status() {
    caddy_status_check
    case $? in
    0)
        show_caddy_version
        echo -e "[INF] sing-box状态: ${yellow}未运行${plain}"
        show_caddy_enable_status
        LOGI "配置文件路径:${CADDY_CONFIG_PATH}/Caddyfile"
        LOGI "可执行文件路径:${CADDY_BINARY_PATH}"
        ;;
    1)
        show_caddy_version
        echo -e "[INF] caddy状态: ${green}已运行${plain}"
        show_caddy_enable_status
        show_caddy_running_status
        LOGI "配置文件路径:${CADDY_CONFIG_PATH}/Caddyfile"
        LOGI "可执行文件路径:${CADDY_BINARY_PATH}"
        ;;
    255)
        echo -e "[INF] caddy状态: ${red}未安装${plain}"
        ;;
    esac
}

#show caddy running status
show_caddy_running_status() {
    caddy_status_check
    if [[ $? == ${CADDY_STATUS_RUNNING} ]]; then
        local runTime=$(systemctl status caddy | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "caddy运行时长：${runTime}"
    else
        LOGE "caddy未运行"
    fi
}

#show caddy version
show_caddy_version() {
    LOGI "版本信息:$(${CADDY_BINARY_PATH} version)"
}

#show caddy enable status,enabled means caddy can auto start when system boot on
show_caddy_enable_status() {
    local temp=$(systemctl is-enabled caddy)
    if [[ x"${temp}" == x"enabled" ]]; then
        echo -e "[INF] caddy是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] caddy是否开机自启: ${red}否${plain}"
    fi
}
#############################################################

# SING-BOX STATUS ###########################################
#sing-box status check,-1 means didn't install,0 means failed,1 means running
sing_box_status_check() {
    if [[ ! -f "${SING_BOX_SERVICE_PATH}" ]]; then
        return ${SING_BOX_STATUS_NOT_INSTALL}
    fi
    temp=$(systemctl status sing-box | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return ${SING_BOX_STATUS_RUNNING}
    else
        return ${SING_BOX_STATUS_NOT_RUNNING}
    fi
}

#show sing-box status
show_sing_box_status() {
    sing_box_status_check
    case $? in
    0)
        show_sing_box_version
        echo -e "[INF] sing-box状态: ${yellow}未运行${plain}"
        show_sing_box_enable_status
        LOGI "配置文件路径:${SING_BOX_CONFIG_PATH}/config.json"
        LOGI "可执行文件路径:${SING_BOX_BINARY_PATH}"
        ;;
    1)
        show_sing_box_version
        echo -e "[INF] sing-box状态: ${green}已运行${plain}"
        show_sing_box_enable_status
        show_sing_box_running_status
        LOGI "配置文件路径:${SING_BOX_CONFIG_PATH}/config.json"
        LOGI "可执行文件路径:${SING_BOX_BINARY_PATH}"
        ;;
    255)
        echo -e "[INF] sing-box状态: ${red}未安装${plain}"
        ;;
    esac
}

#show sing-box running status
show_sing_box_running_status() {
    sing_box_status_check
    if [[ $? == ${SING_BOX_STATUS_RUNNING} ]]; then
        local runTime=$(systemctl status sing-box | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "sing-box运行时长：${runTime}"
    else
        LOGE "sing-box未运行"
    fi
}

#show sing-box version
show_sing_box_version() {
    LOGI "版本信息:$(${SING_BOX_BINARY_PATH} version)"
}

#show sing-box enable status,enabled means sing-box can auto start when system boot on
show_sing_box_enable_status() {
    local temp=$(systemctl is-enabled sing-box)
    if [[ x"${temp}" == x"enabled" ]]; then
        echo -e "[INF] sing-box是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] sing-box是否开机自启: ${red}否${plain}"
    fi
}
###################################################

# FILEBROWSER ###############################
#download filebrowser  binary
download_filebrowser() {
    LOGD "开始下载 filebrowser..."
    os_check && arch_check
    # getting the latest version of filebrowser"
    LATEST_FILE_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/filebrowser/filebrowser/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}'
    FILE_LINK="https://github.com/filebrowser/filebrowser/releases/download/${LATEST_FILE_VERSION}/linux-${ARCH}-filebrowser.tar.gz"
    wget -nv "${FILE_LINK}" -O filebrowser.tar.gz
    mv filebrowser /usr/local/bin/filebrowser && chmod +x /usr/local/bin/filebrowser
    LOGI "filebrowser 下载完毕"
}

#install filebrowser systemd service
install_filebrowser_systemd_service() {
    LOGD "开始安装 filebrowser systemd 服务..."
    cat <<EOF >/etc/systemd/system/filebrowser.service
[Unit]
Description=filebrowser
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/filebrowser -c /usr/local/etc/filebrowser/config.json
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable filebrowser
    LOGD "安装 filebrowser systemd 服务成功"
}

#configuration filebrowser config
configuration_filebrowser_config() {
    LOGD "开始配置filebrowser配置文件..."
    # set config
    cat <<EOF >/usr/local/etc/filebrowser/config.json
{
    "address":"127.0.0.1",
    "database":"/opt/filebrowser/filebrowser.db",
    "log":"/var/log/filebrowser/filebrowser.log",
    "port":40333,
    "root":"/home/filebrowser",
    "username":"admin"
}
EOF
    LOGD "filebrowser 配置文件完成"
}

#install filebrowser
install_filebrowser() {
    LOGD "开始安装 filebrowser..."
    mkdir -p "/usr/local/etc/filebrowser"
    mkdir -p "/var/log/filebrowser"
    mkdir -p "/opt/filebrowser"
    mkdir -p "/home/filebrowser"
    download_filebrowser
    install_filebrowser_systemd_service
    configuration_filebrowser_config
    LOGI "filebrowser 已完成安装"
}

#update filebrowser
update_filebrowser() {
    LOGD "开始更新filebrowser..."
    if [[ ! -f "/etc/systemd/system/filebrowser.service" ]]; then
        LOGE "当前系统未安装filebrowser,更新失败"
        show_menu
    fi
    systemctl stop filebrowser
    rm -f /usr/local/bin/filebrowser
    # getting the latest version of filebrowser"
    download_filebrowser
    LOGI "caddy 启动成功"
    systemctl restart filebrowser
    LOGI "caddy 已完成升级"
}

#uninstall filebrowser
uninstall_filebrowser() {
    LOGD "开始卸载filebrowser..."
    if [[ ! -f "/etc/systemd/system/filebrowser.service" ]]; then
        LOGE "当前系统未安装filebrowser,无需卸载"
        show_menu
    fi
    systemctl stop filebrowser
    systemctl disable filebrowser
    rm -f /etc/systemd/system/filebrowser.service
    systemctl daemon-reload
    rm -f /usr/local/bin/filebrowser
    rm -rf /usr/local/etc/filebrowser
    rm -rf /var/log/filebrowser
    rm -rf /opt/filebrowser
    rm -rf /home/filebrowser
    LOGI "卸载filebrowser成功"
}
######################################

# PLEX ################################
#install plex
install_plex() {
    LOGD "开始下载 plex..."
    os_check && arch_check
     # getting the latest version of plex"
    LATEST_PLEX_VERSION="$(wget -qO- -t1 -T2 "https://plex.tv/api/downloads/5.json" | grep -o '"version":"[^"]*' | grep -o '[^"]*$' | head -n 1)"
    PLEX_LINK="https://downloads.plex.tv/plex-media-server-new/${LATEST_PLEX_VERSION}/debian/plexmediaserver_${LATEST_PLEX_VERSION}_${ARCH}.deb"
    wget -nv "${PLEX_LINK}" -O plexmediaserver.deb
    dpkg -i plexmediaserver.deb
    LOGI "plex 已完成安装"
}

#update plex
update_plex() {
    LOGD "开始更新filebrowser..."
    if [[ ! -f "/etc/systemd/system/plexmediaserver.service" ]]; then
        LOGE "当前系统未安装plex,更新失败"
        show_menu
    fi
    install_plex
    LOGI "plex 已完成升级"
}

#uninstall plex
uninstall_plex() {
    LOGD "开始卸载plex..."
    if [[ ! -f "/etc/systemd/system/plexmediaserver.service" ]]; then
        LOGE "当前系统未安装plexmediaserver,无需卸载"
        show_menu
    fi
    dpkg -r plexmediaserver
    rm -rf /var/lib/plexmediaserver/Library/Application Support/Plex Media Server/
    LOGI "卸载plex成功"
}

#######################################

# CADDY TOOL #################################
#download caddy  binary
download_caddy() {
    LOGD "开始下载 caddy..."
    os_check && arch_check
     # getting the latest version of caddy"
    LATEST_CADDY_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
    CADDY_LINK="https://github.com/lxhao61/integrated-examples/releases/download/${LATEST_CADDY_VERSION}/caddy-linux-${ARCH}.tar.gz"
    wget -nv "${CADDY_LINK}" -O caddy.tar.gz
    mv caddy ${CADDY_BINARY_PATH} && chmod +x ${CADDY_BINARY_PATH}
    LOGI "caddy 下载完毕"
}

#install caddy systemd service
install_caddy_systemd_service() {
    LOGD "开始安装 caddy systemd 服务..."
    cat <<EOF >${CADDY_SERVICE_PATH}
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target
[Service]
Type=notify
User=root
Group=root
ExecStart=${CADDY_BINARY_PATH} run --environ --config ${CADDY_CONFIG_PATH}/Caddyfile
ExecReload=${CADDY_BINARY_PATH} reload --config ${CADDY_CONFIG_PATH}/Caddyfile
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

#configuration caddy Caddyfile
configuration_caddy_config() {
    LOGD "开始配置caddy配置文件..."
    # set Caddyfile
    cat <<EOF >${CADDY_CONFIG_PATH}
{
        order reverse_proxy before route
        admin off
        log {
                output file ${CADDY_LOG_PATH}
                level ERROR
        }       #版本不小于v2.4.0才支持日志全局配置，否则各自配置。
        storage file_system {
                root /home/tls #存放TLS证书的基本路径
        }
        cert_issuer acme #acme表示从Let's Encrypt申请TLS证书，zerossl表示从ZeroSSL申请TLS证书。必须acme与zerossl二选一（固定TLS证书的目录便于引用）。注意：版本不小于v2.4.1才支持。
        email $mail #电子邮件地址。选配，推荐。
}
:443, $thost:443 {
        #HTTPS server监听端口。注意：逗号与域名（或含端口）之间有一个空格。
        tls {
                ciphers TLS_AES_256_GCM_SHA384 TLS_AES_128_GCM_SHA256 TLS_CHACHA20_POLY1305_SHA256 TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
                curves x25519 secp521r1 secp384r1 secp256r1
        }
        @tws {
                path /$wspath #与Trojan+WebSocket应用中path对应
                header Connection *Upgrade*
                header Upgrade websocket
        }       #此部分配置为caddy-trojan插件的WebSocket应用，若删除就仅支持Trojan应用。
        reverse_proxy @tws 127.0.0.1:2007 #转发给本机Trojan+WebSocket监听端口
        
        @host {
                host $thost #限定域名访问（禁止以ip方式访问网站），修改为自己的域名。
        }
        route @host {
                header {
                        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" #启用HSTS
                }
                reverse_proxy 127.0.0.1:40333
        }
}
EOF
    LOGD "caddy 配置文件完成"
}

#configuration caddy Caddyfile with plex
configuration_caddy_config_with_plex() {
    LOGD "开始配置caddy配置文件..."
    # set Caddyfile
    cat <<EOF >${CADDY_CONFIG_PATH}
{
        order reverse_proxy before route
        admin off
        log {
                output file ${CADDY_LOG_PATH}
                level ERROR
        }       #版本不小于v2.4.0才支持日志全局配置，否则各自配置。
        storage file_system {
                root /home/tls #存放TLS证书的基本路径
        }
        cert_issuer acme #acme表示从Let's Encrypt申请TLS证书，zerossl表示从ZeroSSL申请TLS证书。必须acme与zerossl二选一（固定TLS证书的目录便于引用）。注意：版本不小于v2.4.1才支持。
        email $mail #电子邮件地址。选配，推荐。
}
:443, $thost:443, $phost:443 {
        #HTTPS server监听端口。注意：逗号与域名（或含端口）之间有一个空格。
        tls {
                ciphers TLS_AES_256_GCM_SHA384 TLS_AES_128_GCM_SHA256 TLS_CHACHA20_POLY1305_SHA256 TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
                curves x25519 secp521r1 secp384r1 secp256r1
        }
        @tws {
                path /$wspath #与Trojan+WebSocket应用中path对应
                header Connection *Upgrade*
                header Upgrade websocket
        }       #此部分配置为caddy-trojan插件的WebSocket应用，若删除就仅支持Trojan应用。
        reverse_proxy @tws 127.0.0.1:$tport #转发给本机Trojan+WebSocket监听端口
        
        @host {
                host $thost #限定域名访问（禁止以ip方式访问网站），修改为自己的域名。
        }
        route @host {
                header {
                        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" #启用HSTS
                }
                reverse_proxy 127.0.0.1:40333
        }
        
        @plex {
                host $phost #限定域名访问（禁止以ip方式访问网站），修改为自己的域名。
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
EOF
    LOGD "caddy 配置文件完成"
}

#install caddy
install_caddy_without_plex() {
    mkdir -p "/usr/local/etc/caddy"
    mkdir -p "/var/www"
    mkdir -p "/var/log/caddy"
    download_caddy
    install_caddy_systemd_service
    configuration_caddy_config
    LOGI "caddy 已完成安装"
}

#install caddy with plex
install_caddy_with_plex() {
    LOGD "开始安装 caddy..."
    mkdir -p "/usr/local/etc/caddy"
    mkdir -p "/var/www"
    mkdir -p "/var/log/caddy"
    download_caddy
    install_caddy_systemd_service
    configuration_caddy_config_with_plex
    LOGI "caddy 已完成安装"
}

#update caddy
update_caddy() {
    LOGD "开始更新caddy..."
    if [[ ! -f "${CADDY_SERVICE_PATH}" ]]; then
        LOGE "当前系统未安装caddy,更新失败"
        show_menu
    fi
    systemctl stop caddy
    rm -f ${CADDY_BINARY_PATH}
    # getting the latest version of caddy"
    download_caddy
    LOGI "caddy 启动成功"
    systemctl restart caddy
    LOGI "caddy 已完成升级"
}

#uninstall caddy
uninstall_caddy() {
    LOGD "开始卸载caddy..."
    if [[ ! -f "${CADDY_SERVICE_PATH}" ]]; then
        LOGE "当前系统未安装caddy,无需卸载"
        show_menu
    fi
    systemctl stop caddy
    systemctl disable caddy
    rm -f ${CADDY_SERVICE_PATH}
    systemctl daemon-reload
    rm -f ${CADDY_BINARY_PATH}
    rm -rf /usr/local/etc/caddy
    rm -rf /var/log/caddy
    LOGI "卸载caddy成功"
}
#################################

# SING-BOX TOOL ######################
#download sing-box  binary
download_sing-box() {
    LOGD "开始下载 sing-box..."
    os_check && arch_check
     # getting the latest version of sing-box"
    LATEST_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
    LATEST_NUM="$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
    LINK="https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${LATEST_NUM}-linux-${OS_ARCH}.tar.gz"
    wget -nv "${LINK}" -O sing-box.tar.gz
    tar -zxvf sing-box.tar.gz --strip-components=1
    mv sing-box /usr/local/bin/sing-box && chmod +x /usr/local/bin/sing-box
    LOGI "sing-box 下载完毕"
}

#install sing-box systemd service
install_sing_box_systemd_service() {
    LOGD "开始安装 sing-box systemd 服务..."
    cat <<EOF >${SING_BOX_SERVICE_PATH}
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target
[Service]
WorkingDirectory=/var/lib/sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=${SING_BOX_BINARY_PATH} run -c ${SING_BOX_CONFIG_PATH}
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable sing-box
    LOGD "安装 sing-box systemd 服务成功"
}

#configuration sing-box config
configuration_sing_box_config() {
    LOGD "开始配置sing-box配置文件..."
    cat <<EOF >${SING_BOX_CONFIG_PATH}
{
    "log":{
        "level":"info",
        "output":"${SING_BOX_LOG_PATH}",
        "timestamp":true
    },
    "inbounds":[
        {
            "type":"trojan",
            "tag":"trojan-in",
            "listen":"127.0.0.1",
            "listen_port":$tport,
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
                    "password":"$tpswd"
                }
            ],
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
            "listen_port":$vport,
            "tcp_fast_open":true,
            "udp_fragment":true,
            "sniff":true,
            "sniff_override_destination":false,
            "proxy_protocol":true,
            "proxy_protocol_accept_no_header":false,
            "users":[
                {
                    "name":"vmess",
                    "uuid":"$vuuid",
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
                "172.16.0.2/32",
                "$warpv6"
            ],
            "private_key":"$warpkey",
            "peer_public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
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
    LOGD "sing-box 配置文件完成"
}

#install sing-box  
install_sing-box() {
    LOGD "开始安装 sing-box..."
    mkdir -p "/usr/local/etc/sing-box"
    mkdir -p "/var/log/sing-box"
    mkdir -p "/var/lib/sing-box"
    download_sing-box
    install_sing_box_systemd_service
    configuration_sing_box_config
    LOGI "sing-box 已完成安装"
}

#update sing-box
update_sing-box() {
    LOGD "开始更新sing-box..."
    if [[ ! -f "${SING_BOX_SERVICE_PATH}" ]]; then
        LOGE "当前系统未安装sing-box,更新失败"
        show_menu
    fi
    systemctl stop sing-box
    rm -f ${SING_BOX_BINARY_PATH}
    # getting the latest version of sing-box"
    download_sing-box
    LOGI "sing-box 启动成功"
    systemctl restart sing-box
    LOGI "sing-box 已完成升级"
}

#uninstall sing-box
uninstall_sing-box() {
    LOGD "开始卸载sing-box..."
    if [[ ! -f "${SING_BOX_SERVICE_PATH}" ]]; then
        LOGE "当前系统未安装sing-box,无需卸载"
        show_menu
    fi
    systemctl stop sing-box
    systemctl disable sing-box
    rm -f ${SING_BOX_SERVICE_PATH}
    systemctl daemon-reload
    rm -f ${SING_BOX_BINARY_PATH}
    rm -rf /usr/local/etc/sing-box
    rm -rf /var/log/sing-box
    LOGI "卸载sing-box成功"
}
########################################

# INSTALL ALL ############################
# install all without plex
install_all_without_plex() {
    LOGD "开始安装 caddy + sing-box + filebrowser"
    if [[ -f "${CADDY_SERVICE_PATH}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    elif [[ -f "${SING_BOX_SERVICE_PATH}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        show_menu
    elif [[ -f "/etc/systemd/system/filebrowser.service" ]]; then
        LOGE "当前系统已安装 filebrowser,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    read -p "请输入 trojan 网站:" thost
        [ -z "${thost}" ]
    read -p "请输入 trojan 端口:" tport
        [ -z "${tport}" ]
    read -p "请输入 trojan 密码:" tpswd
        [ -z "${tpswd}" ]
    read -p "请输入 ws path:" wspath
        [ -z "${wspath}" ]
    read -p "请输入 vmess 端口:" vport
        [ -z "${vport}" ]    
    read -p "请输入 vmess UUID:" vuuid
        [ -z "${vuuid}" ]  
    read -p "请输入 warp ipv6:" warpv6
        [ -z "${warpv6}" ]  
    read -p "请输入 warp private key:" warpkey
        [ -z "${warpkey}" ]  
    read -p "请输入 warp reserved:" warpreserved
        [ -z "${warpreserved}" ]  
    os_check && arch_check && install_base
    install_caddy_without_caddy
    install_sing-box
    install_filebrowser
    systemctl start caddy
    systemctl start sing-box
    systemctl start filebrowser
    LOGI "caddy + sing-box + filebrowser 已完成安装"
}

# install all without plex
install_all_with_plex() {
    LOGD "开始安装 caddy + sing-box + filebrowser"
    if [[ -f "${CADDY_SERVICE_PATH}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    elif [[ -f "${SING_BOX_SERVICE_PATH}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        show_menu
    elif [[ -f "/etc/systemd/system/filebrowser.service" ]]; then
        LOGE "当前系统已安装 filebrowser,请使用更新命令"
        show_menu
    elif [[ -f "/etc/systemd/system/plexmediaserver.service" ]]; then
        LOGE "当前系统已安装 plex,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    read -p "请输入 trojan 网站:" thost
        [ -z "${thost}" ]
    read -p "请输入 plex 网站:" phost
        [ -z "${phost}" ]
    read -p "请输入 trojan 端口:" tport
        [ -z "${tport}" ]
    read -p "请输入 trojan 密码:" tpswd
        [ -z "${tpswd}" ]
    read -p "请输入 ws path:" wspath
        [ -z "${wspath}" ]
    read -p "请输入 vmess 端口:" vport
        [ -z "${vport}" ]    
    read -p "请输入 vmess UUID:" vuuid
        [ -z "${vuuid}" ]  
    read -p "请输入 warp ipv6:" warpv6
        [ -z "${warpv6}" ]  
    read -p "请输入 warp private key:" warpkey
        [ -z "${warpkey}" ]  
    read -p "请输入 warp reserved:" warpreserved
        [ -z "${warpreserved}" ]  
    os_check && arch_check && install_base
    install_caddy_with_caddy
    install_sing-box
    install_filebrowser
    install_plex
    systemctl start caddy
    systemctl start sing-box
    systemctl start filebrowser
    LOGI "caddy + sing-box + plex + filebrowser 已完成安装"
}
##########################################

# MENU ####################################
#show menu
show_menu() {
    echo -e "
  ${green}SSFUN Linux TOOL 管理脚本${plain}
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 安装 caddy + sing-box + filebrowser
  ${green}2.${plain} 安装 caddy + sing-box + plex + filebrowser
————————————————
  ${green}3.${plain} 更新 caddy 服务
  ${green}4.${plain} 卸载 caddy 服务
  ${green}5.${plain} 更新 sing-box 服务
  ${green}6.${plain} 卸载 sing-box 服务
  ${green}7.${plain} 更新 plex 服务
  ${green}8.${plain} 卸载 plex 服务
  ${green}9.${plain} 更新 filebrowser 服务
  ${green}10.${plain} 卸载 filebrowser 服务
 "
    show_caddy_status
    show_sing_box_status
    echo && read -p "请输入选择[0-10]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_all_without_plex && show_menu
        ;;
    2)
        install_all_with_plex && show_menu
        ;;
    3)
        update_caddy && show_menu
        ;;
    4)
        uninstall_caddy && show_menu
        ;;
    5)
        update_sing-box && show_menu
        ;;
    6)
        uninstall_sing-box && show_menu
        ;;
    7)
        update_plex && show_menu
        ;;
    8)
        uninstall_plex && show_menu
        ;;
    9)
        update_filebrowser && show_menu
        ;;
    10)
        uninstall_filebrowser && show_menu
        ;;
    *)
        LOGE "请输入正确的选项 [0-10]"
        ;;
    esac
}

main(){
    show_menu
}

main $*
