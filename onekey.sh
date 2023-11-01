#!/bin/bash

#####################################################
# ssfun's Linux Onekey Tool
# Author: ssfun
# Date: 2023-11-1
# Version: 3.0.0
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

#sing-box env
SING_BOX_VERSION=''
SING_BOX_CONFIG_PATH='/usr/local/etc/sing-box'
SING_BOX_LOG_PATH='/var/log/sing-box'
SING_BOX_LIB_PATH='/var/lib/sing-box'
SING_BOX_BINARY='/usr/local/bin/sing-box'
SING_BOX_SERVICE='/etc/systemd/system/sing-box.service'

#sing-box status define
declare -r SING_BOX_STATUS_RUNNING=1
declare -r SING_BOX_STATUS_NOT_RUNNING=0
declare -r SING_BOX_STATUS_NOT_INSTALL=255

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
        ;;
    255)
        echo -e "[INF] plex状态: ${red}未安装${plain}"
        ;;
    esac
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
        ;;
    255)
        echo -e "[INF] filebrowser 状态: ${red}未安装${plain}"
        ;;
    esac
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

#sing-box status check,-1 means didn't install,0 means failed,1 means running
sing_box_status_check() {
    if [[ ! -f "${SING_BOX_SERVICE}" ]]; then
        return ${SING_BOX_STATUS_NOT_INSTALL}
    fi
    sing_box_status_temp=$(systemctl is-active sing-box)
    if [[ "${sing_box_status_temp}" == "active" ]]; then
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
        echo -e "[INF] sing-box状态: ${yellow}未运行${plain}"
        show_sing_box_enable_status
        ;;
    1)
        echo -e "[INF] sing-box状态: ${green}已运行${plain}"
        show_sing_box_enable_status
        ;;
    255)
        echo -e "[INF] sing-box状态: ${red}未安装${plain}"
        ;;
    esac
}

#show sing-box enable status
show_sing_box_enable_status() {
    local sing_box_enable_status_temp=$(systemctl is-enabled sing-box)
    if [[ "${sing_box_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] sing-box是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] sing-box是否开机自启: ${red}否${plain}"
    fi
}

#download sing-box  binary
download_sing-box() {
    LOGD "开始下载 sing-box..."
    # getting the latest version of sing-box"
    LATEST_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
    LATEST_NUM="$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
    LINK="https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${LATEST_NUM}-linux-${ARCH}.tar.gz"
    cd `mktemp -d`
    wget -nv "${LINK}" -O sing-box.tar.gz
    tar -zxvf sing-box.tar.gz --strip-components=1
    mv sing-box ${SING_BOX_BINARY} && chmod +x ${SING_BOX_BINARY}
    LOGI "sing-box 下载完毕"
}

#install sing-box systemd service
install_sing_box_systemd_service() {
    LOGD "开始安装 sing-box systemd 服务..."
    cat <<EOF >${SING_BOX_SERVICE}
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target
[Service]
WorkingDirectory=${SING_BOX_LIB_PATH}
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=${SING_BOX_BINARY} run -c ${SING_BOX_CONFIG_PATH}/config.json
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

#configuration sing-box (trojan) config
configuration_sing_box_config() {
    LOGD "开始配置sing-box配置文件..."
    cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
  "log": {
    "level": "info",
    "output": "${SING_BOX_LOG_PATH}/sing-box.log",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": $port,
      "sniff": true,
      "sniff_override_destination": false,
      "users": [
        {
          "name": "trojan",
          "password": "$pswd"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$sub.$host",
        "certificate_path": "${CADDY_TLS_PATH}/certificates/acme-v02.api.letsencrypt.org-directory/$host/$host.crt",
        "key_path": "${CADDY_TLS_PATH}/certificates/acme-v02.api.letsencrypt.org-directory/$host/$host.key"
      },
      "fallback": {
        "server": "127.0.0.1",
        "server_port": 80
      },
      "fallback_for_alpn": {
        "http/1.1": {
          "server": "127.0.0.1",
          "server_port": 443
        }
      },
      "transport": {
        "type": "ws",
        "path": "$path",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [],
    "geoip": {
      "path": "${SING_BOX_CONFIG_PATH}/geoip.db",
      "download_url": "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
      "download_detour": "direct"
    },
    "geosite": {
      "path": "${SING_BOX_CONFIG_PATH}/geosite.db",
      "download_url": "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db",
      "download_detour": "direct"
    },
    "final": "direct",
    "auto_detect_interface": true
  }
}
EOF
    LOGD "sing-box 配置文件完成"
}

#configuration sing-box (trojan + warp) config
configuration_sing_box_warp_config() {
    LOGD "开始配置sing-box配置文件..."
    cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
  "log": {
    "level": "info",
    "output": "${SING_BOX_LOG_PATH}/sing-box.log",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": $port,
      "sniff": true,
      "sniff_override_destination": false,
      "users": [
        {
          "name": "trojan",
          "password": "$pswd"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$sub.$host",
        "certificate_path": "${CADDY_TLS_PATH}/certificates/acme-v02.api.letsencrypt.org-directory/$host/$host.crt",
        "key_path": "${CADDY_TLS_PATH}/certificates/acme-v02.api.letsencrypt.org-directory/$host/$host.key"
      },
      "fallback": {
        "server": "127.0.0.1",
        "server_port": 80
      },
      "fallback_for_alpn": {
        "http/1.1": {
          "server": "127.0.0.1",
          "server_port": 443
        }
      },
      "transport": {
        "type": "ws",
        "path": "$path",
        "max_early_data": 2048,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type":"direct",
      "tag":"warp-IPv6-out",
      "detour":"wireguard-out",
      "domain_strategy":"ipv6_only"
    },
    {
      "type": "wireguard",
      "tag": "wireguard-out",
      "server": "engage.cloudflareclient.com",
      "server_port": 2408,
      "local_address": [
        "172.16.0.2/32",
        "$ipv6"
      ],
      "private_key": "$key",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [$reserved],
      "mtu": 1280,
      "domain_strategy": "prefer_ipv6",
      "fallback_delay": "300ms"
    }
  ],
  "route": {
    "rules": [
      {
        "domain_suffix": ["imgur.com"],
        "outbound": "wireguard-out"
      },
      {
        "ip_cidr": ["1.1.1.1/32"],
        "outbound": "wireguard-out"
      },
      {
        "geosite": ["openai"],
        "outbound": "warp-IPv6-out"
      },
      {
        "domain_keyword": ["ipv6"],
        "outbound": "warp-IPv6-out"
      },
      {
        "ip_version": 6,
        "outbound": "warp-IPv6-out"
      }
    ],
    "geoip": {
      "path": "${SING_BOX_CONFIG_PATH}/geoip.db",
      "download_url": "https://github.com/SagerNet/sing-geoip/releases/latest/download/geoip.db",
      "download_detour": "direct"
    },
    "geosite": {
      "path": "${SING_BOX_CONFIG_PATH}/geosite.db",
      "download_url": "https://github.com/SagerNet/sing-geosite/releases/latest/download/geosite.db",
      "download_detour": "direct"
    },
    "final": "direct",
    "auto_detect_interface": true
  }
}
EOF
    LOGD "sing-box 配置文件完成"
}

#install sing-box  
install_sing-box() {
    LOGD "开始安装 sing-box"
    mkdir -p "${SING_BOX_CONFIG_PATH}"
    mkdir -p "${SING_BOX_LOG_PATH}"
    mkdir -p "${SING_BOX_LIB_PATH}"
    download_sing-box
    install_sing_box_systemd_service
    configuration_sing_box_config
    systemctl start sing-box
    LOGI "sing-box 已完成安装并启动"
}

#install sing-box with warp
install_sing-box_warp() {
    LOGD "开始安装 sing-box"
    mkdir -p "${SING_BOX_CONFIG_PATH}"
    mkdir -p "${SING_BOX_LOG_PATH}"
    mkdir -p "${SING_BOX_LIB_PATH}"
    download_sing-box
    install_sing_box_systemd_service
    configuration_sing_box_warp_config
    systemctl start sing-box
    LOGI "sing-box 已完成安装并启动"
}

#update sing-box
update_sing-box() {
    LOGD "开始更新sing-box..."
    if [[ ! -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统未安装sing-box,更新失败"
        show_menu
    fi
    os_check && arch_check && install_base
    systemctl stop sing-box
    rm -f ${SING_BOX_BINARY}
    # getting the latest version of sing-box"
    download_sing-box
    LOGI "sing-box 启动成功"
    systemctl restart sing-box
    LOGI "sing-box 已完成升级"
}

#uninstall sing-box
uninstall_sing-box() {
    LOGD "开始卸载sing-box..."
    systemctl stop sing-box
    systemctl disable sing-box
    rm -f ${SING_BOX_SERVICE}
    systemctl daemon-reload
    rm -f ${SING_BOX_BINARY}
    rm -rf ${SING_BOX_CONFIG_PATH}
    rm -rf ${SING_BOX_LOG_PATH}
    rm -rf ${SING_BOX_LIB_PATH}
    LOGI "卸载sing-box成功"
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
        ;;
    255)
        echo -e "[INF] caddy状态: ${red}未安装${plain}"
        ;;
    esac
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
ExecStart=${CADDY_BINARY} run --environ --config ${CADDY_CONFIG_PATH}/config.json
ExecReload=${CADDY_BINARY} reload --config ${CADDY_CONFIG_PATH}/config.json
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
    # set Caddyfile
    cat <<EOF >${CADDY_CONFIG_PATH}/config.json
{
  "admin": {
    "disabled": true,
    "config": {
      "persist": false
    }
  },
  "logging": {
    "logs": {
      "default": {
        "writer": {
          "output": "file",
          "filename": "${CADDY_LOG_PATH}/caddy.log"
        },
        "encoder": {
          "format": "console"
        },
        "level": "WARN"
      }
    }
  },
  "storage": {
    "module": "file_system",
    "root": "${CADDY_TLS_PATH}"
  },
  "apps": {
    "http": {
      "servers": {
        "srvh1": {
          "listen": [":80"],
          "routes": [
            {
              "handle": [
                {
                  "handler": "static_response",
                  "headers": {
                    "Location": ["https://{http.request.host}{http.request.uri}"]
                  },
                  "status_code": 301
                }
              ]
            }
          ],
          "protocols": ["h1"]
        },
        "srvh2": {
          "listen": [":443"],
          "routes": [
            {
              "handle": [
                {
                  "handler": "headers",
                  "response": {
                    "set": {
                      "Strict-Transport-Security": ["max-age=31536000; includeSubDomains; preload"]
                    }
                  }
                },
                {
                  "handler": "reverse_proxy",
                  "upstreams": [
                    {
                      "dial": "127.0.0.1:40333"
                    }
                  ]
                }
              ],
              "match": [
                {
                  "host": ["$host"]
                }
              ]
            }
          ],
          "tls_connection_policies": [
            {
              "cipher_suites": [
                "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
                "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
                "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
              ],
              "curves": ["x25519","secp521r1","secp384r1","secp256r1"]
            }
          ],
          "protocols": ["h1","h2"]
        }
      }
    },
    "tls": {
      "certificates": {
        "automate": ["$host"]
      },
      "automation": {
        "policies": [
          {
            "issuers": [
              {
                "module": "acme",
                "email": "$email"
              }
            ]
          }
        ]
      }
    }
  }
}
EOF
    LOGD "caddy 配置文件完成"
}

configuration_caddy_plex_config() {
    LOGD "开始配置caddy配置文件..."
    # set Caddyfile
    cat <<EOF >${CADDY_CONFIG_PATH}/config.json
{
  "admin": {
    "disabled": true,
    "config": {
      "persist": false
    }
  },
  "logging": {
    "logs": {
      "default": {
        "writer": {
          "output": "file",
          "filename": "${CADDY_LOG_PATH}/caddy.log"
        },
        "encoder": {
          "format": "console"
        },
        "level": "WARN"
      }
    }
  },
  "storage": {
    "module": "file_system",
    "root": "${CADDY_TLS_PATH}"
  },
  "apps": {
    "http": {
      "servers": {
        "srvh1": {
          "listen": [":80"],
          "routes": [
            {
              "handle": [
                {
                  "handler": "static_response",
                  "headers": {
                    "Location": ["https://{http.request.host}{http.request.uri}"]
                  },
                  "status_code": 301
                }
              ]
            }
          ],
          "protocols": ["h1"]
        },
        "srvh2": {
          "listen": [":443"],
          "routes": [
            {
              "handle": [
                {
                  "handler": "headers",
                  "response": {
                    "set": {
                      "Strict-Transport-Security": ["max-age=31536000; includeSubDomains; preload"]
                    }
                  }
                },
                {
                  "handler": "reverse_proxy",
                  "upstreams": [
                    {
                      "dial": "127.0.0.1:40333"
                    }
                  ]
                }
              ],
              "match": [
                {
                  "host": ["$host"]
                }
              ]
            },
            {
              "handle": [
                {
                  "handler": "headers",
                  "response": {
                    "set": {
                      "Referrer-Policy": ["no-referrer-when-downgrade"],
                      "Strict-Transport-Security": ["max-age=31536000; includeSubDomains; preload"],
                      "X-Content-Type-Options": ["nosniff"],
                      "X-Frame-Options": ["DENY"],
                      "X-Xss-Protection": ["1"]
                    }
                  }
                },
                {
                  "handler": "reverse_proxy",
                  "upstreams": [
                    {
                      "dial": "127.0.0.1:32400"
                    }
                  ]
                },
                {
                  "encodings": {
                    "gzip": {
                    }
                  },
                  "handler": "encode",
                  "prefer": ["gzip"]
                }
              ],
              "match": [
                {
                  "host": ["$plex"]
                }
              ]
            }
          ],
          "tls_connection_policies": [
            {
              "cipher_suites": [
                "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
                "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
                "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
              ],
              "curves": ["x25519","secp521r1","secp384r1","secp256r1"]
            }
          ],
          "protocols": ["h1","h2"]
        }
      }
    },
    "tls": {
      "certificates": {
        "automate": ["$host","&plex"]
      },
      "automation": {
        "policies": [
          {
            "issuers": [
              {
                "module": "acme",
                "email": "$email"
              }
            ]
          }
        ]
      }
    }
  }
}
EOF
    LOGD "caddy 配置文件完成"
}

install_caddy() {
    LOGD "开始安装 caddy..."
    mkdir -p "${CADDY_CONFIG_PATH}"
    mkdir -p "${CADDY_WWW_PATH}"
    mkdir -p "${CADDY_404_PATH}"
    mkdir -p "${CADDY_LOG_PATH}"
    curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/404/index.html  -o ${CADDY_404_PATH}/index.html
    download_caddy
    install_caddy_systemd_service
    configuration_caddy_config
    systemctl start caddy
    LOGI "caddy 已完成安装并启动"
}

install_caddy_plex() {
    LOGD "开始安装 caddy..."
    mkdir -p "${CADDY_CONFIG_PATH}"
    mkdir -p "${CADDY_WWW_PATH}"
    mkdir -p "${CADDY_404_PATH}"
    mkdir -p "${CADDY_LOG_PATH}"
    curl -s  https://raw.githubusercontent.com/ssfun/Linux_tool/main/caddy/404/index.html  -o ${CADDY_404_PATH}/index.html
    download_caddy
    install_caddy_systemd_service
    configuration_caddy_plex_config
    systemctl start caddy
    LOGI "caddy 已完成安装并启动"
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

#安装 caddy + sing-box(trojan) + filebrowser
install_all_without_warp_plex() {
    LOGD "开始安装 caddy + sing-box(trojan) + filebrowser"
    if [[ -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    elif [[ -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        show_menu
    elif [[ -f "${FILEBROWSER_SERVICE}" ]]; then
        LOGE "当前系统已安装 filebrowser,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    read -p "请输入域名:" host
        [ -z "${host}" ]
    read -p "请输入证书邮箱:" email
        [ -z "${email}" ]
    read -p "请输入 trojan 端口:" port
        [ -z "${port}" ]
    read -p "请输入 trojan 密码:" pswd
        [ -z "${pswd}" ]
    read -p "请输入 trojan ws path:" path
        [ -z "${path}" ]
    os_check && arch_check && install_base
    install_caddy
    install_sing-box
    install_fb
    LOGI "caddy + sing-box(trojan) + filebrowser 已完成安装"
}

#安装 caddy + sing-box(trojan & warp) + filebrowser
install_all_without_plex() {
    LOGD "开始安装 caddy + sing-box(trojan & warp) + filebrowser"
    if [[ -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    elif [[ -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        show_menu
    elif [[ -f "${FILEBROWSER_SERVICE}" ]]; then
        LOGE "当前系统已安装 filebrowser,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    read -p "请输入域名:" host
        [ -z "${host}" ]
    read -p "请输入证书邮箱:" email
        [ -z "${email}" ]
    read -p "请输入 trojan 端口:" port
        [ -z "${port}" ]
    read -p "请输入 trojan 密码:" pswd
        [ -z "${pswd}" ]
    read -p "请输入 trojan ws path:" path
        [ -z "${path}" ]
    read -p "请输入 warp ipv6:" ipv6
        [ -z "${ipv6}" ]
    read -p "请输入 warp private key:" key
        [ -z "${key}" ]
    read -p "请输入 warp reserved:" reserved
        [ -z "${reserved}" ]
    os_check && arch_check && install_base
    install_caddy
    install_sing-box_warp
    install_fb
    LOGI "caddy + sing-box(trojan & warp) + filebrowser 已完成安装"
}

#安装 caddy + sing-box(trojan) + filebrowser + plex
install_all_without_warp() {
    LOGD "开始安装 caddy + sing-box(trojan) + filebrowser + plex"
    if [[ -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    elif [[ -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        show_menu
    elif [[ -f "${FILEBROWSER_SERVICE}" ]]; then
        LOGE "当前系统已安装 filebrowser,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    read -p "请输入域名:" host
    read -p "请输入 plex 域名:" plex
        [ -z "${plex}" ]
    read -p "请输入证书邮箱:" email
        [ -z "${email}" ]
    read -p "请输入 trojan 端口:" port
        [ -z "${port}" ]
    read -p "请输入 trojan 密码:" pswd
        [ -z "${pswd}" ]
    read -p "请输入 trojan ws path:" path
        [ -z "${path}" ]
    os_check && arch_check && install_base
    install_caddy_plex
    install_sing-box
    install_fb
    install_plex
    LOGI "caddy + sing-box(trojan) + filebrowser + plex 已完成安装"
}

#安装 caddy + sing-box(trojan & warp) + filebrowser + plex
install_all() {
    LOGD "开始安装 caddy + sing-box(trojan & warp) + filebrowser + plex"
    if [[ -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    elif [[ -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        show_menu
    elif [[ -f "${FILEBROWSER_SERVICE}" ]]; then
        LOGE "当前系统已安装 filebrowser,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    read -p "请输入域名:" host
    read -p "请输入 plex 域名:" plex
        [ -z "${plex}" ]
    read -p "请输入证书邮箱:" email
        [ -z "${email}" ]
    read -p "请输入 trojan 端口:" port
        [ -z "${port}" ]
    read -p "请输入 trojan 密码:" pswd
        [ -z "${pswd}" ]
    read -p "请输入 trojan ws path:" path
        [ -z "${path}" ]
    read -p "请输入 warp ipv6:" ipv6
        [ -z "${ipv6}" ]
    read -p "请输入 warp private key:" key
        [ -z "${key}" ]
    read -p "请输入 warp reserved:" reserved
        [ -z "${reserved}" ]
    os_check && arch_check && install_base
    install_caddy_plex
    install_sing-box_warp
    install_fb
    install_plex
    LOGI "caddy + sing-box(trojan & warp) + filebrowser + plex 已完成安装"
}

#show menu
show_menu() {
    echo -e "
  ${green}Caddy | Sing-box | Filebrowser | Plex 管理脚本${plain}
  ————————————————
  ${green}Q.${plain} 退出脚本
  ————————————————
  ${green}1.${plain} 安装 caddy + sing-box(trojan) + filebrowser
  ${green}2.${plain} 安装 caddy + sing-box(trojan & warp) + filebrowser
  ${green}3.${plain} 安装 caddy + sing-box(trojan) + filebrowser + plex
  ${green}4.${plain} 安装 caddy + sing-box(trojan & warp) + filebrowser + plex
  ————————————————
  ${green}5.${plain} 更新 caddy
  ${green}6.${plain} 更新 sing-box
  ${green}7.${plain} 更新 filebrowser
  ${green}8.${plain} 更新 plex
  ————————————————
  ${green}11.${plain} 卸载 caddy
  ${green}12.${plain} 卸载 sing-box
  ${green}13.${plain} 卸载 filebrowser
  ${green}14.${plain} 卸载 plex
 "
    show_caddy_status
    show_sing_box_status
    show_fb_status
    show_plex_status
    echo && read -p "请输入选择[0-14]:" num

    case "${num}" in
    Q)
        exit 0
        ;;
    1)
        install_all_without_warp_plex && show_menu
        ;;
    2)
        install_all_without_plex && show_menu
        ;;
    3)
        install_all_without_warp && show_menu
        ;;
    4)
        install_all && show_menu
        ;;
    5)
        update_caddy && show_menu
        ;;
    6)
        update_sing-box && show_menu
        ;;
    7)
        update_fb && show_menu
        ;;
    8)
        update_plex && show_menu
        ;;
    11)
        uninstall_caddy && show_menu
        ;;
    12)
        uninstall_sing-box && show_menu
        ;;
    13)
        uninstall_fb && show_menu
        ;;
    14)
        uninstall_plex && show_menu
        ;;
    *)
        LOGE "请输入正确的选项 [0-14]"
        ;;
    esac
}

main(){
    show_menu
}

main $*
