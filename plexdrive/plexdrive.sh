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

#plexdrive env
PLEXDRIVE_VERSION=''
PLEXDRIVE_CONFIG_PATH='/home/.plexdriv'
PLEXDRIVE_MOUNT_PATH='/var/log/plexdrive'
PLEXDRIVE_BINARY='/usr/local/bin/plexdrive'
PLEXDRIVE_SERVICE='/etc/systemd/system/plexdrive.service'

#plexdrive status define
declare -r PLEXDRIVE_STATUS_RUNNING=1
declare -r PLEXDRIVE_STATUS_NOT_RUNNING=0
declare -r PLEXDRIVE_STATUS_NOT_INSTALL=255

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

#plexdrive status check,-1 means didn't install,0 means failed,1 means running
plexdrive_status_check() {
    if [[ ! -f "${PLEXDRIVE_SERVICE}" ]]; then
        return ${PLEXDRIVE_STATUS_NOT_INSTALL}
    fi
    plexdrive_status_temp=$(systemctl is-active plexdrive)
    if [[ "${plexdrive_status_temp}" == "active" ]]; then
        return ${PLEXDRIVE_STATUS_RUNNING}
    else
        return ${PLEXDRIVE_STATUS_NOT_RUNNING}
    fi
}

#show plexdrive status
show_plexdrive_status() {
    plexdrive_status_check
    case $? in
    0)
        echo -e "[INF] plexdrive状态: ${yellow}未运行${plain}"
        show_plexdrive_enable_status
        ;;
    1)
        echo -e "[INF] plexdrive状态: ${green}已运行${plain}"
        show_plexdrive_enable_status
        show_plexdrive_running_status
        ;;
    255)
        echo -e "[INF] plexdrive状态: ${red}未安装${plain}"
        ;;
    esac
}

#show plexdrive running status
show_plexdrive_running_status() {
    plexdrive_status_check
    if [[ $? == ${PLEXDRIVE_STATUS_RUNNING} ]]; then
        local plexdrive_runTime=$(systemctl status plexdrive | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "plexdrive运行时长：${plexdrive_runTime}"
    else
        LOGE "plexdrive未运行"
    fi
}

#show plexdrive enable status
show_plexdrive_enable_status() {
    local plexdrive_enable_status_temp=$(systemctl is-enabled plexdrive)
    if [[ "${plexdrive_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] plexdrive是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] plexdrive是否开机自启: ${red}否${plain}"
    fi
}

#download plexdrive  binary
download_plexdrive() {
    LOGD "开始下载 plexdrive..."
    # getting the latest version of plexdrive"
    LATEST_VERSION="$(wget -qO- -t1 -T2 "https://api.github.com/repos/plexdrive/plexdrive/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/v//g;s/,//g;s/ //g')"
    LINK="https://github.com/plexdrive/plexdrive/releases/download/${LATEST_VERSION}/plexdrive-linux-${ARCH}"
    cd `mktemp -d`
    wget -nv "${LINK}" -O plexdrive.tar.gz
    tar -zxvf plexdrive.tar.gz
    mv plexdrive ${PLEXDRIVE_BINARY} && chmod +x ${PLEXDRIVE_BINARY}
    LOGI "plexdrive 下载完毕"
}

#install plexdrive systemd service
install_plexdrive_systemd_service() {
    LOGD "开始安装 plexdrive systemd 服务..."
    cat <<EOF >${PLEXDRIVE_SERVICE}
[Unit]
Description=Plexdrive
AssertPathIsDirectory=${PLEXDRIVE_MOUNT_PATH}
After=network-online.target
[Service]
Type=simple
ExecStart=/${PLEXDRIVE_BINARY} mount \
 -c ${PLEXDRIVE_CONFIG_PATH} \
 -o allow_other \
 -v 4 --refresh-interval=1m \
 --chunk-check-threads=4 \
 --chunk-load-threads=4 \
 --chunk-load-ahead=4 \
 --max-chunks=20 \
 ${PLEXDRIVE_MOUNT_PATH}
ExecStop=/bin/fusermount -u ${PLEXDRIVE_MOUNT_PATH}
Restart=on-abort
[Install]
WantedBy=default.target
EOF
    systemctl daemon-reload
    systemctl enable plexdrive
    LOGD "安装 plexdrive systemd 服务成功"
}

#configuration plexdrive config
configuration_plexdrive_config() {
    LOGD "开始配置plexdrive config配置文件..."
    cat <<EOF >${PLEXDRIVE_CONFIG_PATH}/config.json
$config
EOF
    LOGD "开始配置plexdrive token配置文件..."
    cat <<EOF >${PLEXDRIVE_CONFIG_PATH}/token.json
$token
EOF
    LOGD "plexdrive 配置文件完成"
}

#install plexdrive  
install_plexdrive() {
    LOGD "开始安装 plexdrive"
    if [[ -f "${PLEXDRIVE_SERVICE}" ]]; then
        LOGE "当前系统已安装 plexdrive,请使用更新命令"
        show_menu
    fi
    LOGI "开始安装"
    read -p "请输入config:" config
        [ -z "${config}" ]
    read -p "请输入token:" token
        [ -z "${token}" ]
    os_check && arch_check && install_base
    mkdir -p "${PLEXDRIVE_CONFIG_PATH}"
    mkdir -p "${PLEXDRIVE_MOUNT_PATH}"
    download_plexdrive
    install_plexdrive_systemd_service
    configuration_plexdrive_config
    LOGI "plexdrive 已完成安装"
}

#update plexdrive
update_plexdrive() {
    LOGD "开始更新plexdrive..."
    if [[ ! -f "${PLEXDRIVE_SERVICE}" ]]; then
        LOGE "当前系统未安装plexdrive,更新失败"
        show_menu
    fi
    os_check && arch_check && install_base
    systemctl stop plexdrive
    rm -f ${PLEXDRIVE_BINARY}
    # getting the latest version of plexdrive"
    download_plexdrive
    LOGI "plexdrive 启动成功"
    systemctl restart plexdrive
    LOGI "plexdrive 已完成升级"
}

#uninstall plexdrive
uninstall_plexdrive() {
    LOGD "开始卸载plexdrive..."
    systemctl stop plexdrive
    systemctl disable plexdrive
    rm -f ${PLEXDRIVE_SERVICE}
    systemctl daemon-reload
    rm -f ${PLEXDRIVE_BINARY}
    rm -rf ${PLEXDRIVE_CONFIG_PATH}
    LOGI "卸载plexdrive成功"
}

#show menu
show_menu() {
    echo -e "
  ${green}Plexdrive 管理脚本${plain}
  ————————————————
  ${green}0.${plain} 退出脚本
  ————————————————
  ${green}1.${plain} 安装 plexdrive
  ${green}2.${plain} 更新 plexdrive
  ${green}3.${plain} 卸载 plexdrive
  ————————————————
  ${green}4.${plain} 重启 plexdrive 服务
  ${green}5.${plain} 查看 plexdrive 日志
 "
    show_plexdrive_status
    echo && read -p "请输入选择[0-5]:" num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        install_plexdrive && show_menu
        ;;
    2)
        update_plexdrive && show_menu
        ;;
    3)
        uninstall_plexdrive && show_menu
        ;;
    4)
        systemctl restart plexdrive && show_menu
        ;;
    5)
        systemctl status plexdrive && show_menu
        ;;
    *)
        LOGE "请输入正确的选项 [0-5]"
        ;;
    esac
}

main(){
    show_menu
}

main $*
