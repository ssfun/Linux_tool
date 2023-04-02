#!/bin/bash

#####################################################
# ssfun's Filebrowser Tool
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

#file config patch
FILE_CONFIG_PATH='/usr/local/etc/filebrowser'
#log file save path
FILE_LOG_PATH='/var/log/filebrowser'
#file save path
FILE_DATA_PATH='/home/filebrowser'
#database file save path
FILE_DATABASE_PATH='/opt/filebrowser'
#binary install path
FILE_BINARY='/usr/local/bin/filebrowser'
#service install path
FILE_SERVICE='/etc/systemd/system/filebrowser.service'

#file status define
declare -r FILE_STATUS_RUNNING=1
declare -r FILE_STATUS_NOT_RUNNING=0
declare -r FILE_STATUS_NOT_INSTALL=255

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

#install some common utils
install_base() {
    if [[ ${OS} == "ubuntu" || ${OS} == "debian" ]]; then
        apt install wget tar -y
    elif [[ ${OS} == "centos" ]]; then
        yum install wget tar -y
    fi
}

#file status check,-1 means didn't install,0 means failed,1 means running
file_status_check() {
    if [[ ! -f "${FILE_SERVICE}" ]]; then
        return ${FILE_STATUS_NOT_INSTALL}
    fi
    temp=$(systemctl status filebrowser | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return ${FILE_STATUS_RUNNING}
    else
        return ${FILE_STATUS_NOT_RUNNING}
    fi
}

#show file status
show_file_status() {
    file_status_check
    case $? in
    0)
        echo -e "[INF] file状态: ${yellow}未运行${plain}"
        show_file_enable_status
        ;;
    1)
        echo -e "[INF] file状态: ${green}已运行${plain}"
        show_file_enable_status
        show_file_running_status
        ;;
    255)
        echo -e "[INF] file状态: ${red}未安装${plain}"
        ;;
    esac
}

#show file running status
show_file_running_status() {
    file_status_check
    if [[ $? == ${FILE_STATUS_RUNNING} ]]; then
        local runTime=$(systemctl status filebrowser | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "file运行时长：${runTime}"
    else
        LOGE "file未运行"
    fi
}

#show file enable status,enabled means file can auto start when system boot on
show_file_enable_status() {
    local temp=$(systemctl is-enabled filebrowser)
    if [[ x"${temp}" == x"enabled" ]]; then
        echo -e "[INF] file是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] file是否开机自启: ${red}否${plain}"
    fi
}

#download file  binary
download_file() {
    LOGD "开始下载 file..."
    # getting the latest version of file"
    LATEST_FILE_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/file/file/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g'))
    FILE_LINK="https://github.com/file/file/releases/download/${LATEST_FILE_VERSION}/linux-${ARCH}-file.tar.gz"
    cd `mktemp -d`
    wget -nv "${FILE_LINK}" -O filebrowser.tar.gz
    tar -zxvf filebrowser.tar.gz
    mv filebrowser ${FILE_BINARY} && chmod +x ${FILE_BINARY}
    LOGI "file 下载完毕"
}

#install file systemd service
install_file_systemd_service() {
    LOGD "开始安装 file systemd 服务..."
    cat <<EOF >${FILE_SERVICE}
[Unit]
Description=filebrowser
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
User=root
Restart=on-failure
RestartSec=5s
ExecStart=${FILE_BINARY} -c ${FILE_CONFIG_PATH}/config.json
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable filebrowser
    LOGD "安装 filebrowser systemd 服务成功"
}

#configuration file config
configuration_file_config() {
    LOGD "开始配置file配置文件..."
    # set config
    cat <<EOF >${FILE_CONFIG_PATH}/config.json
{
    "address":"127.0.0.1",
    "database":"${FILE_DATABASE_PATH}/filebrowser.db",
    "log":"${FILE_LOG_PATH}/filebrowser.log",
    "port":40333,
    "root":"${FILE_DATA_PATH}",
    "username":"admin"
}
EOF
    LOGD "file 配置文件完成"
}

#install file
install_file() {
    LOGD "开始安装 file..."
    mkdir -p "${FILE_CONFIG_PATH}"
    mkdir -p "${FILE_LOG_PATH}"
    mkdir -p "${FILE_DATABASE_PATH}"
    mkdir -p "${FILE_DATA_PATH}"
    download_file
    install_file_systemd_service
    configuration_file_config
    LOGI "file 已完成安装"
}

#update file
update_file() {
    LOGD "开始更新filebrowser..."
    if [[ ! -f "${FILE_SERVICE}" ]]; then
        LOGE "当前系统未安装file,更新失败"
        show_menu
    fi
    os_check && arch_check
    systemctl stop file
    rm -f ${FILE_BINARY}
    # getting the latest version of filebrowser"
    download_file
    LOGI "file 启动成功"
    systemctl restart filebrowser
    LOGI "file 已完成升级"
}

#uninstall file
uninstall_file() {
    LOGD "开始卸载filebrowser..."
    systemctl stop filebrowser
    systemctl disable filebrowser
    rm -f ${FILE_SERVICE}
    systemctl daemon-reload
    rm -f ${FILE_BINARY}
    rm -rf ${FILE_CONFIG_PATH}
    rm -rf ${FILE_LOG_PATH}
    rm -rf ${FILE_DATABASE_PATH}
    rm -rf ${FILE_DATA_PATH}
    LOGI "卸载filebrowser成功"
}

#show menu
show_menu() {
    echo -e "
  ${green}Filebrowser 管理脚本${plain}
  ————————————————
  ${green}0.${plain} 退出脚本
  ————————————————
  ${green}1.${plain} 安装 file 服务
  ${green}2.${plain} 更新 file 服务
  ${green}3.${plain} 卸载 file 服务
 "
    show_file_status
    echo && read -p "请输入选择[0-3]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_file && show_menu
        ;;
    2)
        update_file && show_menu
        ;;
    3)
        uninstall_file && show_menu
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
