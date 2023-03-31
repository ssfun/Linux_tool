#!/bin/bash

#####################################################
# This shell script is used for sing-box installation
# Author: ssfun
# Date: 2023-03-31
# Version: 1.0.0
#####################################################

#Some basic definitions
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
pink='\033[1;35m'
green='\033[0;32m'
yellow='\033[0;33m'

#os
OS_RELEASE=''

#arch
OS_ARCH=''

#sing-box status define
declare -r SING_BOX_STATUS_RUNNING=1
declare -r SING_BOX_STATUS_NOT_RUNNING=0
declare -r SING_BOX_STATUS_NOT_INSTALL=255

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

#Root check
[[ $EUID -ne 0 ]] && LOGE "请使用root用户运行该脚本" && exit 1

#System check
os_check() {
    LOGI "检测当前系统中..."
    if [[ -f /etc/redhat-release ]]; then
        OS_RELEASE="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        OS_RELEASE="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        OS_RELEASE="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        OS_RELEASE="centos"
    else
        LOGE "系统检测错误,当前系统不支持!" && exit 1
    fi
    LOGI "系统检测完毕,当前系统为:${OS_RELEASE}"
}

#arch check
arch_check() {
    LOGI "检测当前系统架构中..."
    OS_ARCH=$(arch)
    LOGI "当前系统架构为 ${OS_ARCH}"

    if [[ ${OS_ARCH} == "x86_64" || ${OS_ARCH} == "x64" || ${OS_ARCH} == "amd64" ]]; then
        OS_ARCH="amd64"
    elif [[ ${OS_ARCH} == "aarch64" || ${OS_ARCH} == "arm64" ]]; then
        OS_ARCH="arm64"
    else
        LOGE "检测系统架构失败,当前系统架构不支持!" && exit 1
    fi
    LOGI "系统架构检测完毕,当前系统架构为:${OS_ARCH}"
}

#sing-box status check,-1 means didn't install,0 means failed,1 means running
status_check() {
    if [[ ! -f "/etc/systemd/system/sing-box.service" ]]; then
        return ${SING_BOX_STATUS_NOT_INSTALL}
    fi
    temp=$(systemctl status sing-box | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return ${SING_BOX_STATUS_RUNNING}
    else
        return ${SING_BOX_STATUS_NOT_RUNNING}
    fi
}

#show sing-box version
show_sing_box_version() {
    LOGI "版本信息:/usr/local/bin/sing-box version)"
}

#show sing-box enable status,enabled means sing-box can auto start when system boot on
show_enable_status() {
    local temp=$(systemctl is-enabled sing-box)
    if [[ x"${temp}" == x"enabled" ]]; then
        echo -e "[INF] sing-box是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] sing-box是否开机自启: ${red}否${plain}"
    fi
}

#show sing-box running status
show_running_status() {
    status_check
    if [[ $? == ${SING_BOX_STATUS_RUNNING} ]]; then
        local pid=$(pidof sing-box)
        local runTime=$(systemctl status sing-box | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        local memCheck=$(cat /proc/${pid}/status | grep -i vmrss | awk '{print $2,$3}')
        LOGI "#####################"
        LOGI "进程ID:${pid}"
        LOGI "运行时长：${runTime}"
        LOGI "内存占用:${memCheck}"
        LOGI "#####################"
    else
        LOGE "sing-box未运行"
    fi
}

#show sing-box status
show_status() {
    status_check
    case $? in
    0)
        show_sing_box_version
        echo -e "[INF] sing-box状态: ${yellow}未运行${plain}"
        show_enable_status
        LOGI "配置文件路径:/usr/local/etc/sing-box/config.json"
        LOGI "可执行文件路径:/usr/local/bin/sing-box"
        ;;
    1)
        show_sing_box_version
        echo -e "[INF] sing-box状态: ${green}已运行${plain}"
        show_enable_status
        show_running_status
        LOGI "配置文件路径:/usr/local/etc/sing-box/config.json"
        LOGI "可执行文件路径:/usr/local/bin/sing-box"
        ;;
    255)
        echo -e "[INF] sing-box状态: ${red}未安装${plain}"
        ;;
    esac
}

#install some common utils
install_base() {
    if [[ ${OS_RELEASE} == "ubuntu" || ${OS_RELEASE} == "debian" ]]; then
        apt install wget tar -y
    elif [[ ${OS_RELEASE} == "centos" ]]; then
        yum install wget tar -y
    fi
}

#download sing-box  binary
download_sing-box() {
    LOGD "开始下载 sing-box..."
    os_check && arch_check && install_base
     # getting the latest version of sing-box"
    LATEST_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')"
    LATEST_NUM="$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
    LINK="https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${LATEST_NUM}-linux-${OS_ARCH}.tar.gz"
    wget -nv "${LINK}" -O sing-box.tar.gz
    tar -zxvf sing-box.tar.gz --strip-components=1
    mv sing-box /usr/local/bin/sing-box && chmod +x /usr/local/bin/sing-box
    LOGI "sing-box 下载完毕"
}

#install systemd service
install_systemd_service() {
    LOGD "开始安装 sing-box systemd 服务..."
    cat <<EOF >/etc/systemd/system/sing-box.service
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target
[Service]
WorkingDirectory=/var/lib/sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json
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

#configuration config
configuration_config() {
    LOGD "开始配置sing-box配置文件..."
    # set config.json
    read -p "请输入 trojan 网站:" trojanhost
        [ -z "${trojanhost}" ]
    read -p "请输入 trojan 端口:" trojanport
        [ -z "${trojanport}" ]
    read -p "请输入 trojan 密码:" trojanpswd
        [ -z "${trojanpswd}" ]
    read -p "请输入 ws path:" wspath
        [ -z "${wspath}" ]
    read -p "请输入 vmess 端口:" vmessport
        [ -z "${vmessport}" ]    
    read -p "请输入 vmess UUID:" vmessuuid
        [ -z "${vmessuuid}" ]  
    read -p "请输入 warp ipv4:" warpipv4
        [ -z "${warpipv4}" ]  
    read -p "请输入 warp ipv6:" warpipv6
        [ -z "${warpipv6}" ]  
    read -p "请输入 warp private key:" warpprivatekey
        [ -z "${warpprivatekey}" ]  
    read -p "请输入 warp public key:" warppublickey
        [ -z "${warppublickey}" ]  
    read -p "请输入 warp reserved:" warpreserved
        [ -z "${warpreserved}" ]  
    cat <<EOF >/usr/local/etc/sing-box/config.json
{
    "log":{
        "level":"info",
        "output":"/var/log/sing-box/sing-box.log",
        "timestamp":true
    },
    "inbounds":[
        {
            "type":"trojan",
            "tag":"trojan-in",
            "listen":"0.0.0.0",
            "listen_port":$trojanport,
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
                    "password":"$trojanpswd"
                }
            ],
            "tls":{
                "enabled":true,
                "server_name":"$trojanhost",
                "alpn":[
                    "h2",
                    "http/1.1"
                ],
                "min_version":"1.2",
                "max_version":"1.3",
                "cipher_suites":[
                    "TLS_CHACHA20_POLY1305_SHA256",
                    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
                    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
                ],
                "certificate_path":"/home/tls/certificates/acme-v02.api.letsencrypt.org-directory/$trojanhost/$trojanhost.crt",
                "key_path":"/home/tls/certificates/acme-v02.api.letsencrypt.org-directory/$trojanhost/$trojanhost.key"
            },
            "fallback":{
                "server":"127.0.0.1",
                "server_port":404
            },
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
            "listen_port":$vmessport,
            "tcp_fast_open":true,
            "udp_fragment":true,
            "sniff":true,
            "sniff_override_destination":false,
            "proxy_protocol":true,
            "proxy_protocol_accept_no_header":false,
            "users":[
                {
                    "name":"vmess",
                    "uuid":"$vmessuuid",
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
                "$warpipv4",
                "$warpipv6"
            ],
            "private_key":"$warpprivatekey",
            "peer_public_key":"$warppublickey",
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
    if [[ -f "/etc/systemd/system/sing-box.service" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        show_menu
    fi
    os_check && arch_check && install_base
    mkdir -p "/usr/local/etc/sing-box"
    mkdir -p "/var/log/sing-box"
    mkdir -p "/var/lib/sing-box"
    download_sing-box
    install_systemd_service
    configuration_config
    LOGI "sing-box 启动成功"
    systemctl start sing-box
    LOGI "sing-box 已完成安装"
}


#update sing-box
update_sing-box() {
    LOGD "开始更新sing-box..."
    if [[ ! -f "/etc/systemd/system/sing-box.service" ]]; then
        LOGE "当前系统未安装sing-box,更新失败"
        show_menu
    fi
    systemctl stop sing-box
    rm -f /usr/local/bin/sing-box
    # getting the latest version of sing-box"
    download_sing-box
    LOGI "sing-box 启动成功"
    systemctl restart sing-box
    LOGI "sing-box 已完成升级"
}

#uninstall sing-box
uninstall_sing-box() {
    LOGD "开始卸载sing-box..."
    if [[ ! -f "/etc/systemd/system/sing-box.service" ]]; then
        LOGE "当前系统未安装sing-box,无需卸载"
        show_menu
    fi
    systemctl stop sing-box
    systemctl disable sing-box
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload
    rm -f /usr/local/bin/sing-box
    rm -rf /usr/local/etc/sing-box
    rm -rf /var/log/sing-box
    LOGI "卸载sing-box成功"
}


#show menu
show_menu() {
    echo -e "
  ${green}sing-box 管理脚本${plain}
  ————————————————
  
  ${green}1.${plain} 安装 sing-box 服务
  ${green}2.${plain} 更新 sing-box 服务
  ${green}3.${plain} 卸载 sing-box 服务
  
  ${green}0.${plain} 退出 sing-box 脚本
 "
    show_status
    echo && read -p "请输入选择[0-3]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_sing-box && show_menu
        ;;
    2)
        update_sing-box && show_menu
        ;;
    3)
        uninstall_sing-box && show_menu
        ;;
    *)
        LOGE "请输入正确的选项 [0-3]"
        ;;
    esac
}

main(){
    show_menu
}

main $*
