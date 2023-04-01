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

#install some common utils
install_base() {
    if [[ ${OS} == "ubuntu" || ${OS} == "debian" ]]; then
        apt install wget tar -y
    elif [[ ${OS} == "centos" ]]; then
        yum install wget tar -y
    fi
}

#download caddy  binary
download_caddy() {
    LOGD "开始下载 caddy..."
    os_check && arch_check && install_base
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
ExecStart=${CADDY_BINARY_PATH} run --environ --config ${CADDY_CONFIG_PATH}
ExecReload=${CADDY_BINARY_PATH} reload --config ${CADDY_CONFIG_PATH}
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
    read -p "请输入需要设置的网站host:" host
        [ -z "${host}" ]
    read -p "请输入 trojan 密码:" pswd
        [ -z "${pswd}" ]
    read -p "请输入申请证书mail:" mail
        [ -z "${mail}" ]    
    cat <<EOF >${CADDY_CONFIG_PATH}
{
        order trojan before route
        order forward_proxy before trojan
        order reverse_proxy before forward_proxy
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

#install caddy
install_caddy() {
    LOGD "开始安装 caddy..."
    if [[ -f "${CADDY_SERVICE_PATH}" ]]; then
        LOGE "当前系统已安装 caddy,请使用更新命令"
        show_menu
    fi
    os_check && arch_check && install_base
    mkdir -p "/usr/local/etc/caddy"
    mkdir -p "/var/www"
    mkdir -p "/var/www/404"
    mkdir -p "/var/log/caddy"
    download_caddy
    install_caddy_systemd_service
    configuration_caddy_config
    LOGI "caddy 启动成功"
    systemctl start caddy
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
                "172.16.0.2/32",
                "$warpipv6"
            ],
            "private_key":"$warpprivatekey",
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
    if [[ -f "${SING_BOX_SERVICE_PATH}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        show_menu
    fi
    os_check && arch_check && install_base
    mkdir -p "/usr/local/etc/sing-box"
    mkdir -p "/var/log/sing-box"
    mkdir -p "/var/lib/sing-box"
    download_sing-box
    install_sing_box_systemd_service
    configuration_sing_box_config
    LOGI "sing-box 启动成功"
    systemctl start sing-box
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


#show menu
show_menu() {
    echo -e "
  ${green}sing-box-v${SING_BOX_YES_VERSION} 管理脚本${plain}
  ${green}0.${plain} 退出脚本
————————————————
  ${green}1.${plain} 安装 caddy 服务
  ${green}2.${plain} 更新 caddy 服务
  ${green}3.${plain} 卸载 caddy 服务
————————————————
  ${green}4.${plain} 安装 sing-box 服务
  ${green}5.${plain} 更新 sing-box 服务
  ${green}6.${plain} 卸载 sing-box 服务
 "
    show_caddy_status
    show_sing_box_status
    echo && read -p "请输入选择[0-6]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_caddy && show_menu
        ;;
    2)
        update_caddy && show_menu
        ;;
    3)
        uninstall_caddy && show_menu
        ;;
    4)
        install_sing-box && show_menu
        ;;
    5)
        update_sing-box && show_menu
        ;;
    6)
        uninstall_sing-box && show_menu
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
