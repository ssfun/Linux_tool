#!/bin/bash
#####################################################
# ssfun's Linux Tool For qBittorrent
# Author: ssfun
# Date: 2025-01-08
# Version: 1.0.0
#####################################################

# Basic definitions
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
pink='\033[1;35m'
green='\033[0;32m'
yellow='\033[0;33m'

# OS arch env
OS=''
ARCH=''

# qBittorrent env
QB_VERSION=''
QB_PROFILE_PATH='/usr/local/etc'
QB_DIR_PATH='/home/downloads'
QB_DIRTEMP_PATH='/home/downloads-temp'
QB_BINARY='/usr/local/bin/qbittorrent-nox'
QB_SERVICE='/etc/systemd/system/qbt.service'

# Cache the latest version number
LATEST_VERSION_CACHE=""

# qBittorrent status define
declare -r QB_STATUS_RUNNING=1
declare -r QB_STATUS_NOT_RUNNING=0
declare -r QB_STATUS_NOT_INSTALL=255

# Utils
function LOGE() {
    printf "${red}[ERR] %s${plain}\n" "$*"
}

function LOGI() {
    printf "${green}[INF] %s${plain}\n" "$*"
}

function LOGD() {
    printf "${yellow}[DEG] %s${plain}\n" "$*"
}

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        [[ -z "${temp}" ]] && temp=$2
    else
        read -p "$1 [y/n]: " temp
    fi
    [[ "${temp,,}" == "y" || "${temp,,}" == "yes" ]] && return 0 || return 1
}

# Root user check
[[ $EUID -ne 0 ]] && LOGE "请使用root用户运行该脚本" && exit 1

# System check
os_check() {
    LOGI "检测当前系统中..."
    if grep -qi "centos" /etc/redhat-release; then
        OS="centos"
    elif grep -qi "debian" /etc/issue; then
        OS="debian"
    elif grep -qi "ubuntu" /etc/issue; then
        OS="ubuntu"
    elif grep -qi "centos|red hat|redhat" /etc/issue; then
        OS="centos"
    elif grep -qi "debian" /proc/version; then
        OS="debian"
    elif grep -qi "ubuntu" /proc/version; then
        OS="ubuntu"
    elif grep -qi "centos|red hat|redhat" /proc/version; then
        OS="centos"
    else
        LOGE "系统检测错误,当前系统不支持!" && exit 1
    fi
    LOGI "系统检测完毕,当前系统为:${OS}"
}

# Arch check
arch_check() {
    LOGI "检测当前系统架构中..."
    ARCH=$(uname -m)
    LOGI "当前系统架构为 ${ARCH}"
    if [[ ${ARCH} == "x86_64" || ${ARCH} == "x64" || ${ARCH} == "amd64" ]]; then
        ARCH="x86_64"
    elif [[ ${ARCH} == "aarch64" || ${ARCH} == "arm64" ]]; then
        ARCH="aarch64"
    else
        LOGE "检测系统架构失败,当前系统架构不支持!" && exit 1
    fi
    LOGI "系统架构检测完毕,当前系统架构为:${ARCH}"
}

# Install base packages
install_base() {
    if ! command -v wget >/dev/null 2>&1; then
        if [[ ${OS} == "ubuntu" || ${OS} == "debian" ]]; then
            apt install wget -y
        elif [[ ${OS} == "centos" ]]; then
            yum install wget -y
        fi
    fi
}

# Retrieve the latest version number of qBittorrent (with cache)
get_latest_qBittorrent_version() {
    if [[ -z "${LATEST_VERSION_CACHE}" ]]; then
        LATEST_VERSION_CACHE=$(wget -qO- -t1 -T2 "https://api.github.com/repos/userdocs/qbittorrent-nox-static/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
    fi
    echo "${LATEST_VERSION_CACHE}"
}

# qBittorrent status check
qBittorrent_status_check() {
    if [[ ! -f "${QB_SERVICE}" ]]; then
        return ${QB_STATUS_NOT_INSTALL}
    fi
    if systemctl is-active qbt >/dev/null 2>&1; then
        return ${QB_STATUS_RUNNING}
    else
        return ${QB_STATUS_NOT_RUNNING}
    fi
}

# Show qBittorrent status
show_qBittorrent_status() {
    qBittorrent_status_check
    case $? in
        ${QB_STATUS_RUNNING})
            echo -e "[INF] qBittorrent状态: ${green}已运行${plain}"
            local version=$(${QB_BINARY} --version | grep -oP '(?<=qBittorrent v)\d+\.\d+\.\d+')
            echo -e "[INF] qBittorrent版本: ${green}${version}${plain}"
            show_qBittorrent_enable_status
            show_qBittorrent_running_status
            ;;
        ${QB_STATUS_NOT_RUNNING})
            echo -e "[INF] qBittorrent状态: ${yellow}未运行${plain}"
            local version=$(${QB_BINARY} --version | grep -oP '(?<=qBittorrent v)\d+\.\d+\.\d+')
            echo -e "[INF] qBittorrent版本: ${green}${version}${plain}"
            show_qBittorrent_enable_status
            ;;
        ${QB_STATUS_NOT_INSTALL})
            echo -e "[INF] qBittorrent状态: ${red}未安装${plain}"
            ;;
    esac

    # 显示最新版本号
    local latest_version=$(get_latest_qBittorrent_version)
    echo -e "[INF] qBittorrent最新版本: ${green}${latest_version}${plain}"
}

# Show qBittorrent running status
show_qBittorrent_running_status() {
    qBittorrent_status_check
    if [[ $? == ${QB_STATUS_RUNNING} ]]; then
        local qBittorrent_runTime=$(systemctl show -p ActiveEnterTimestamp qbt | cut -d= -f2)
        LOGI "qBittorrent运行时长：${qBittorrent_runTime}"
    else
        LOGE "qBittorrent未运行"
    fi
}

# Show qBittorrent enable status
show_qBittorrent_enable_status() {
    if systemctl is-enabled qbt >/dev/null 2>&1; then
        echo -e "[INF] qBittorrent是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] qBittorrent是否开机自启: ${red}否${plain}"
    fi
}

# Download qBittorrent binary
download_qBittorrent() {
    LOGD "开始获取 qBittorrent 版本信息"
    local latest_version=$(get_latest_qBittorrent_version)
    LINK="https://github.com/userdocs/qbittorrent-nox-static/releases/download/${latest_version}/${ARCH}-qbittorrent-nox"
    LOGD "开始下载 qBittorrent"
    wget -qO ${QB_BINARY} ${LINK} && chmod +x ${QB_BINARY} || { LOGE "下载 qBittorrent 失败"; exit 1; }
    LOGI "qBittorrent 下载完毕"
}

# Install qBittorrent systemd service
install_qBittorrent_systemd_service() {
    LOGD "开始安装 qBittorrent systemd 服务..."
    cat <<EOF >${QB_SERVICE}
[Unit]
Description=qBittorrent Service
After=network.target nss-lookup.target

[Service]
UMask=000
ExecStart=${QB_BINARY} --profile=${QB_PROFILE_PATH}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable qbt
    LOGD "安装 qBittorrent systemd 服务成功"
}

# Install qBittorrent
install_qBittorrent() {
    LOGD "开始安装 qBittorrent"
    if [[ -f "${QB_SERVICE}" ]]; then
        LOGE "当前系统已安装 qBittorrent,请使用更新命令"
        show_menu
        return 1
    fi

    os_check && arch_check && install_base

    mkdir -p "${QB_DIR_PATH}"
    mkdir -p "${QB_DIRTEMP_PATH}"

    download_qBittorrent
    install_qBittorrent_systemd_service

    systemctl start qbt || { LOGE "启动 qBittorrent 失败"; return 1; }
    LOGI "qBittorrent 已完成安装并启动"
}

# Update qBittorrent
update_qBittorrent() {
    LOGD "开始更新qBittorrent..."
    if [[ ! -f "${QB_SERVICE}" ]]; then
        LOGE "当前系统未安装qBittorrent,更新失败"
        show_menu
        return 1
    fi

    os_check && arch_check

    systemctl stop qbt
    rm -f ${QB_BINARY}
    download_qBittorrent
    systemctl restart qbt || { LOGE "重启 qBittorrent 失败"; return 1; }
    LOGI "qBittorrent 已完成升级"
}

# Uninstall qBittorrent
uninstall_qBittorrent() {
    LOGD "开始卸载qBittorrent..."
    systemctl stop qbt
    systemctl disable qbt
    rm -f ${QB_SERVICE}
    systemctl daemon-reload
    rm -f ${QB_BINARY}
    rm -rf ${QB_PROFILE_PATH}/qBittorrent
    LOGI "卸载qBittorrent成功"
}

# Show menu
show_menu() {
    echo -e "
${green} qBittorrent 管理脚本${plain}
————————————————
${green}0.${plain} 退出脚本
————————————————
${green}1.${plain} 安装 qBittorrent
${green}2.${plain} 更新 qBittorrent
${green}3.${plain} 重启 qBittorrent
${green}4.${plain} 卸载 qBittorrent
————————————————
${green}5.${plain} 查看 qBittorrent 日志
${green}6.${plain} 查看 qBittorrent 报错

"
    show_qBittorrent_status
    echo && read -p "请输入选择 [0-6] (默认0): " num
    [[ -z "${num}" ]] && num=0
    case "${num}" in
        0) exit 0
        ;;
        1) install_qBittorrent && show_menu
        ;;
        2) update_qBittorrent && show_menu
        ;;
        3) systemctl restart qbt && show_menu
        ;;
        4) uninstall_qBittorrent && show_menu
        ;;
        5) systemctl status qbt && show_menu
        ;;
        6) journalctl -u qbt -n 10 && show_menu
        ;;
        *) LOGE "请输入正确的选项 [0-6]" && show_menu
        ;;
    esac
}

main() {
    show_menu
}

main
