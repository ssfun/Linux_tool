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

#show filebrowser status
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

#show filebrowser running status
show_fb_running_status() {
    fb_status_check
    if [[ $? == ${FILEBROWSER_STATUS_RUNNING} ]]; then
        local fb_runTime=$(systemctl status filebrowser | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "filebrowser 运行时长：${fb_runTime}"
    else
        LOGE "filebrowser 未运行"
    fi
}

#show filebrowser enable status
show_fb_enable_status() {
    local fb_enable_status_temp=$(systemctl is-enabled filebrowser)
    if [[ "${fb_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] filebrowser 是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] filebrowser 是否开机自启: ${red}否${plain}"
    fi
}

#download filebrowser binary
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

#install filebrowser systemd service
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

#configuration filebrowser config
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

#install filebrowser
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
    LOGI "filebrowser 已完成安装"
}

#update filebrowser
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

#uninstall filebrowser
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

#show menu
show_menu() {
    echo -e "
  ${green}filebrowser 管理脚本${plain}
  ————————————————
  ${green}0.${plain} 退出脚本
  ————————————————
  ${green}1.${plain} 安装 filebrowser
  ${green}2.${plain} 更新 filebrowser
  ${green}3.${plain} 卸载 filebrowser
  ————————————————
  ${green}4.${plain} 修改 filebrowser 配置
  ${green}5.${plain} 重启 filebrowser 服务
  ${green}6.${plain} 查看 filebrowser 日志
 "
    show_fb_status
    echo && read -p "请输入选择[0-6]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_fb && show_menu
        ;;
    2)
        update_fb && show_menu
        ;;
    3)
        uninstall_fb && show_menu
        ;;
    4)
        nano ${FILEBROWSER_CONFIG_PATH}/config.json && show_menu
        ;;
    5)
        systemctl restart filebrowser && show_menu
        ;;
    6)
        systemctl status filebrowser && show_menu
        ;;
    *)
        LOGE "请输入正确的选项 [0-8]"
        ;;
    esac
}

main(){
    show_menu
}

main $*
