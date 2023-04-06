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
CADDY_BINARY='/usr/local/bin/caddy'
CADDY_SERVICE='/etc/systemd/system/caddy.service'

#caddy status define
declare -r CADDY_STATUS_RUNNING=1
declare -r CADDY_STATUS_NOT_RUNNING=0
declare -r CADDY_STATUS_NOT_INSTALL=255

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
        if ! dpkg -s wget tar >/dev/null 2>&1; then
            apt install wget tar -y
        fi
    elif [[ ${OS} == "centos" ]]; then
        if ! rpm -q wget tar >/dev/null 2>&1; then
            yum install wget tar -y
        fi
    fi
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

#show caddy status
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

#show caddy running status
show_caddy_running_status() {
    caddy_status_check
    if [[ $? == ${CADDY_STATUS_RUNNING} ]]; then
        local caddy_runTime=$(systemctl status caddy | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "caddy运行时长：${caddy_runTime}"
    else
        LOGE "caddy未运行"
    fi
}

#show caddy enable status
show_caddy_enable_status() {
    local caddy_enable_status_temp=$(systemctl is-enabled caddy)
    if [[ "${caddy_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] caddy是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] caddy是否开机自启: ${red}否${plain}"
    fi
}


#download caddy binary
download_caddy() {
    LOGD "开始下载 caddy..."
    # getting the latest version of caddy & filebrowser"
    LATEST_CADDY_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/lxhao61/integrated-examples/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
    CADDY_LINK="https://github.com/lxhao61/integrated-examples/releases/download/${LATEST_CADDY_VERSION}/caddy-linux-${ARCH}.tar.gz"
    cd `mktemp -d`
    wget -nv "${CADDY_LINK}" -O caddy.tar.gz
    tar -zxvf caddy.tar.gz
    mv caddy ${CADDY_BINARY} && chmod +x ${CADDY_BINARY}
    LOGI "caddy下载完毕"
}

#install caddy systemd service
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

#configuration caddy config
configuration_caddy_config() {
    LOGD "开始配置caddy配置文件..."
    # set Caddyfile
    cat <<EOF >${CADDY_CONFIG_PATH}/Caddyfile
{
        order reverse_proxy before route
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
}
:443, $thost {
        #HTTPS server监听端口。注意：逗号与域名（或含端口）之间有一个空格。
        tls {
                ciphers TLS_AES_256_GCM_SHA384 TLS_AES_128_GCM_SHA256 TLS_CHACHA20_POLY1305_SHA256 TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
                curves x25519 secp521r1 secp384r1 secp256r1
                alpn http/1.1 h2
        }
        
        @tws {
                path /$wspath #与Trojan+WebSocket应用中path对应
                header Connection *Upgrade*
                header Upgrade websocket
        } 
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
}
EOF
    LOGD "caddy 配置文件完成"
}

#configuration caddy with plex
configuration_caddy_config_with_plex() {
    LOGD "开始配置caddy配置文件..."
    # set Caddyfile
    cat <<EOF >${CADDY_CONFIG_PATH}/Caddyfile
{
        order reverse_proxy before route
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
}
:443, $thost, $phost {
        #HTTPS server监听端口。注意：逗号与域名（或含端口）之间有一个空格。
        tls {
                ciphers TLS_AES_256_GCM_SHA384 TLS_AES_128_GCM_SHA256 TLS_CHACHA20_POLY1305_SHA256 TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384 TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256 TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
                curves x25519 secp521r1 secp384r1 secp256r1
                alpn http/1.1 h2
        }
        @tws {
                path /$wspath #与Trojan+WebSocket应用中path对应
                header Connection *Upgrade*
                header Upgrade websocket
        }  
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
    LOGD "开始安装 caddy"
    if [[ -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    read -p "请输入申请证书邮箱:" mail
        [ -z "${mail}" ]
    read -p "请输入 trojan 网站:" thost
        [ -z "${thost}" ]
    read -p "请输入 trojan 端口:" tport
        [ -z "${tport}" ]
    read -p "请输入 ws path:" wspath
        [ -z "${wspath}" ]
    os_check && arch_check && install_base
    mkdir -p "${CADDY_CONFIG_PATH}"
    mkdir -p "${CADDY_WWW_PATH}"
    mkdir -p "${CADDY_LOG_PATH}"
    download_caddy
    install_caddy_systemd_service
    configuration_caddy_config
    LOGI "caddy 已完成安装"
}

#install caddy with plex
install_caddy_with_plex() {
    LOGD "开始安装 caddy"
    if [[ -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    read -p "请输入申请证书邮箱:" mail
        [ -z "${mail}" ]
    read -p "请输入 trojan 网站:" thost
        [ -z "${thost}" ]
    read -p "请输入 plex 网站:" phost
        [ -z "${phost}" ]
    read -p "请输入 trojan 端口:" tport
        [ -z "${tport}" ]
    read -p "请输入 ws path:" wspath
        [ -z "${wspath}" ]
    os_check && arch_check && install_base
    mkdir -p "${CADDY_CONFIG_PATH}"
    mkdir -p "${CADDY_WWW_PATH}"
    mkdir -p "${CADDY_LOG_PATH}"
    download_caddy
    install_caddy_systemd_service
    configuration_caddy_config_with_plex
    LOGI "caddy 已完成安装"
}

#update caddy
update_caddy() {
    LOGD "开始更新caddy..."
    if [[ ! -f "${CADDY_SERVICE}" ]]; then
        LOGE "当前系统未安装caddy,更新失败"
        show_menu
    fi
    os_check && arch_check && install_base
    systemctl stop caddy
    rm -f ${CADDY_BINARY}
    # getting the latest version of caddy"
    download_caddy
    LOGI "caddy 启动成功"
    systemctl restart caddy
    LOGI "caddy 已完成升级"
}

#uninstall caddy
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


#show menu
show_menu() {
    echo -e "
  ${green}Caddy 管理脚本${plain}
  ————————————————
  ${green}0.${plain} 退出脚本
  ————————————————
  ${green}1.${plain} 安装 caddy
  ${green}2.${plain} 安装 caddy with plex
  ${green}3.${plain} 更新 caddy
  ${green}4.${plain} 卸载 caddy
  ————————————————
  ${green}5.${plain} 修改 caddy 配置
  ${green}6.${plain} 重启 caddy 服务
  ${green}7.${plain} 查看 caddy 日志

 "
    show_caddy_status
    echo && read -p "请输入选择[0-7]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_caddy_without_plex && show_menu
        ;;
    2)
        install_caddy_with_plex && show_menu
        ;;
    3)
        update_caddy && show_menu
        ;;
    4)
        uninstall_caddy && show_menu
        ;;
    5)
        nano ${CADDY_CONFIG_PATH}/Caddyfile && show_menu
        ;;
    6)
        systemctl restart caddy && show_menu
        ;;
    7)
        systemctl status caddy && show_menu
        ;;
    *)
        LOGE "请输入正确的选项 [0-7]"
        ;;
    esac
}

main(){
    show_menu
}

main $*
