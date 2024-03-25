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

#trojan-go env
TROJAN_GO_VERSION=''
TROJAN_GO_CONFIG_PATH='/usr/local/etc/trojan-go'
TROJAN_GO_BINARY='/usr/local/bin/trojan-go'
TROJAN_GO_SERVICE='/etc/systemd/system/trojan-go.service'

#trojan-go status define
declare -r TROJAN_GO_STATUS_RUNNING=1
declare -r TROJAN_GO_STATUS_NOT_RUNNING=0
declare -r TROJAN_GO_STATUS_NOT_INSTALL=255

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
        if ! dpkg -s wget zip >/dev/null 2>&1; then
            apt install wget zip -y
        fi
    elif [[ ${OS} == "centos" ]]; then
        if ! rpm -q wget zip >/dev/null 2>&1; then
            yum install wget zip -y
        fi
    fi
}

#trojan-go status check,-1 means didn't install,0 means failed,1 means running
trojan_go_status_check() {
    if [[ ! -f "${TROJAN_GO_SERVICE}" ]]; then
        return ${TROJAN_GO_STATUS_NOT_INSTALL}
    fi
    trojan_go_status_temp=$(systemctl is-active trojan-go)
    if [[ "${trojan_go_status_temp}" == "active" ]]; then
        return ${TROJAN_GO_STATUS_RUNNING}
    else
        return ${TROJAN_GO_STATUS_NOT_RUNNING}
    fi
}

#show trojan-go status
show_trojan_go_status() {
    trojan_go_status_check
    case $? in
    0)
        echo -e "[INF] trojan-go状态: ${yellow}未运行${plain}"
        show_trojan_go_enable_status
        ;;
    1)
        echo -e "[INF] trojan-go状态: ${green}已运行${plain}"
        show_trojan_go_enable_status
        show_trojan_go_running_status
        ;;
    255)
        echo -e "[INF] trojan-go状态: ${red}未安装${plain}"
        ;;
    esac
}

#show trojan-go running status
show_trojan_go_running_status() {
    trojan_go_status_check
    if [[ $? == ${TROJAN_GO_STATUS_RUNNING} ]]; then
        local trojan_go_runTime=$(systemctl status trojan-go | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "trojan-go运行时长：${trojan_go_runTime}"
    else
        LOGE "trojan-go未运行"
    fi
}

#show trojan-go enable status
show_trojan_go_enable_status() {
    local trojan_go_enable_status_temp=$(systemctl is-enabled trojan-go)
    if [[ "${trojan_go_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] trojan-go是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] trojan-go是否开机自启: ${red}否${plain}"
    fi
}

#download trojan-go  binary
download_trojan-go() {
    LOGD "开始下载 trojan-go..."
    # getting the latest version of trojan-go"
    LATEST_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/p4gefau1t/trojan-go/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
    LINK="https://github.com/p4gefau1t/trojan-go/releases/download/${LATEST_VERSION}/trojan-go-linux-${ARCH}.zip"
    cd `mktemp -d`
    wget -nv "${LINK}" -O trojan-go.zip
    unzip -q trojan-go.zip
    mv trojan-go ${TROJAN_GO_BINARY} && chmod +x ${TROJAN_GO_BINARY}
    mv geoip.dat ${TROJAN_GO_CONFIG_PATH}/geoip.dat
    mv geosite.dat ${TROJAN_GO_CONFIG_PATH}/geosite.dat
    LOGI "trojan-go 下载完毕"
}

#install trojan-go systemd service
install_trojan_go_systemd_service() {
    LOGD "开始安装 trojan-go systemd 服务..."
    cat <<EOF >${TROJAN_GO_SERVICE}
[Unit]
Description=Trojan-Go - An unidentifiable mechanism that helps you bypass GFW
Documentation=https://p4gefau1t.github.io/trojan-go/
After=network.target nss-lookup.target
[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${TROJAN_GO_BINARY} -config ${TROJAN_GO_CONFIG_PATH}/config.json
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EO
    systemctl daemon-reload
    systemctl enable trojan-go
    LOGD "安装 trojan-go systemd 服务成功"
}

#configuration trojan-go config
configuration_trojan_go_config() {
    LOGD "开始配置trojan-go配置文件..."
    cat <<EOF >${TROJAN_GO_CONFIG_PATH}/config.json
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": $tport,
    "remote_addr": "127.0.0.1",
    "remote_port": 88,
    "password": [
        "$tpswd"
    ],
    "ssl": {
        "cert": "/home/tls/certificates/acme-v02.api.letsencrypt.org-directory/$thost/$thost.crt",
        "key": "/home/tls/certificates/acme-v02.api.letsencrypt.org-directory/$thost/$thost.key",
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
        "path": "/$tpath",
        "hostname": "$thost"
    },
    "router": {
        "enabled": true,
        "block": [
            "geoip:private"
        ],
        "geoip": "${TROJAN_GO_CONFIG_PATH}/geoip.dat",
        "geosite": "${TROJAN_GO_CONFIG_PATH}/geosite.dat"
    }
}
EOF
    LOGD "trojan-go 配置文件完成"
}

#install trojan-go  
install_trojan-go() {
    LOGD "开始安装 trojan-go"
    if [[ -f "${TROJAN_GO_SERVICE}" ]]; then
        LOGE "当前系统已安装 trojan-go,请使用更新命令"
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
    os_check && arch_check && install_base
    mkdir -p "${TROJAN_GO_CONFIG_PATH}"
    download_trojan-go
    install_trojan_go_systemd_service
    configuration_trojan_go_config
    LOGI "trojan-go 已完成安装"
}

#update trojan-go
update_trojan-go() {
    LOGD "开始更新trojan-go..."
    if [[ ! -f "${TROJAN_GO_SERVICE}" ]]; then
        LOGE "当前系统未安装trojan-go,更新失败"
        show_menu
    fi
    os_check && arch_check && install_base
    systemctl stop trojan-go
    rm -f ${TROJAN_GO_BINARY}
    # getting the latest version of trojan-go"
    download_trojan-go
    LOGI "trojan-go 启动成功"
    systemctl restart trojan-go
    LOGI "trojan-go 已完成升级"
}

#uninstall trojan-go
uninstall_trojan-go() {
    LOGD "开始卸载trojan-go..."
    systemctl stop trojan-go
    systemctl disable trojan-go
    rm -f ${TROJAN_GO_SERVICE}
    systemctl daemon-reload
    rm -f ${TROJAN_GO_BINARY}
    rm -rf ${TROJAN_GO_CONFIG_PATH}
    LOGI "卸载trojan-go成功"
}

#show menu
show_menu() {
    echo -e "
  ${green}Trojan-go 管理脚本${plain}
  ————————————————
  ${green}0.${plain} 退出脚本
  ————————————————
  ${green}1.${plain} 安装 trojan-go
  ${green}2.${plain} 更新 trojan-go
  ${green}3.${plain} 卸载 trojan-go
  ————————————————
  ${green}4.${plain} 修改 trojan-go 配置
  ${green}5.${plain} 重启 trojan-go 服务
  ${green}6.${plain} 查看 trojan-go 日志
 "
    show_trojan_go_status
    echo && read -p "请输入选择[0-6]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_trojan-go && show_menu
        ;;
    2)
        update_trojan-go && show_menu
        ;;
    3)
        uninstall_trojan-go && show_menu
        ;;
    4)
        nano ${TROJAN_GO_CONFIG_PATH}/config.json && show_menu
        ;;
    5)
        systemctl restart trojan-go && show_menu
        ;;
    6)
        systemctl status trojan-go && show_menu
        ;;
    *)
        LOGE "请输入正确的选项 [0-6]"
        ;;
    esac
}

main(){
    show_menu
}

main $*
