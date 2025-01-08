#!/bin/bash
#####################################################
# ssfun's Linux Tool For WEBDAV
# Author: ssfun
# Date: 2025-01-08
# Version: 0.0.1
#####################################################

# 基本定义
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
pink='\033[1;35m'
green='\033[0;32m'
yellow='\033[0;33m'

# WebDAV 环境变量
WEBDAV_BINARY="/usr/local/bin/webdav"
WEBDAV_CONFIG="/usr/local/etc/webdav/config.yml"
WEBDAV_SERVICE="/etc/systemd/system/webdav.service"

# WebDAV 状态定义
declare -r WEBDAV_STATUS_RUNNING=1
declare -r WEBDAV_STATUS_NOT_RUNNING=0
declare -r WEBDAV_STATUS_NOT_INSTALL=255

# 系统检测
OS=''
ARCH=''

# 工具函数
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

# 检查 root 用户
[[ $EUID -ne 0 ]] && LOGE "请使用 root 用户运行该脚本" && exit 1

# 系统检测
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

# 架构检测
arch_check() {
    LOGI "检测当前系统架构中..."
    ARCH=$(uname -m)
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

# 安装基础依赖
install_base() {
    LOGI "检查并安装依赖: tar..."
    if ! command -v tar >/dev/null 2>&1; then
        LOGI "tar 未安装，正在安装..."
        if [[ ${OS} == "ubuntu" || ${OS} == "debian" ]]; then
            apt install tar -y || { LOGE "安装 tar 失败"; exit 1; }
        elif [[ ${OS} == "centos" ]]; then
            yum install tar -y || { LOGE "安装 tar 失败"; exit 1; }
        fi
    fi
    LOGI "依赖检查完成"
}

# 获取最新版本号
get_latest_version() {
    LOGD "从 GitHub API 获取最新版本号..."
    local api_url="https://api.github.com/repos/hacdias/webdav/releases/latest"
    local version=$(curl -s ${api_url} | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "${version}" ]]; then
        LOGE "获取最新版本号失败"
        return 1
    fi
    echo "${version}"
}

# 下载 WebDAV 二进制文件
download_webdav() {
    LOGD "开始下载 WebDAV 二进制文件..."
    local version=$(get_latest_version)
    LOGI "最新版本号: ${version}"
    local download_url="https://github.com/hacdias/webdav/releases/download/${version}/linux-${ARCH}-webdav.tar.gz"
    LOGD "下载链接: ${download_url}"
    curl -L -o /tmp/webdav.tar.gz ${download_url} || { LOGE "下载 WebDAV 失败"; exit 1; }
    tar -zxvf /tmp/webdav.tar.gz -C /usr/bin/ || { LOGE "解压 WebDAV 失败"; exit 1; }
    chmod +x ${WEBDAV_BINARY}
    LOGI "WebDAV 下载并解压完成"
}

# 创建 WebDAV 配置文件
create_webdav_config() {
    LOGD "创建 WebDAV 配置文件..."
    read -p "请输入 WebDAV 监听端口 (默认 6065): " port
    [[ -z "${port}" ]] && port=6065

    read -p "请输入 WebDAV 根目录 (默认 /home): " directory
    [[ -z "${directory}" ]] && directory="/home"

    read -p "请输入 WebDAV 用户名 (默认 admin): " username
    [[ -z "${username}" ]] && username="admin"

    read -p "请输入 WebDAV 密码 (默认 admin): " password
    [[ -z "${password}" ]] && password="admin"

    cat <<EOF >${WEBDAV_CONFIG}
address: 0.0.0.0
port: ${port}

# TLS-related settings if you want to enable TLS directly.
tls: false

# Prefix to apply to the WebDAV path-ing. Default is '/'.
prefix: /

# Enable or disable debug logging. Default is 'false'.
debug: false

# Disable sniffing the files to detect their content type. Default is 'false'.
noSniff: false

# Whether the server runs behind a trusted proxy or not. When this is true,
# the header X-Forwarded-For will be used for logging the remote addresses
# of logging attempts (if available).
behindProxy: false

# The directory that will be able to be accessed by the users when connecting.
# This directory will be used by users unless they have their own 'directory' defined.
# Default is '.' (current directory).
directory: ${directory}

# The default permissions for users. This is a case insensitive option. Possible
# permissions: C (Create), R (Read), U (Update), D (Delete). You can combine multiple
# permissions. For example, to allow to read and create, set "RC". Default is "R".
permissions: CRUD

# The default permissions rules for users. Default is none. Rules are applied
# from last to first, that is, the first rule that matches the request, starting
# from the end, will be applied to the request.
rules: []

# The behavior of redefining the rules for users. It can be:
# - overwrite: when a user has rules defined, these will overwrite any global
#   rules already defined. That is, the global rules are not applicable to the
#   user.
# - append: when a user has rules defined, these will be appended to the global
#   rules already defined. That is, for this user, their own specific rules will
#   be checked first, and then the global rules.
# Default is 'overwrite'.
rulesBehavior: overwrite

# Logging configuration
log:
  # Logging format ('console', 'json'). Default is 'console'.
  format: console
  # Enable or disable colors. Default is 'true'. Only applied if format is 'console'.
  colors: true
  # Logging outputs. You can have more than one output. Default is only 'stderr'.
  outputs:
  - stderr

# CORS configuration
cors:
  # Whether or not CORS configuration should be applied. Default is 'false'.
  enabled: false
  credentials: false

# The list of users. If the list is empty, then there will be no authentication.
users:
  - username: ${username}
    password: ${password}
EOF
    LOGI "WebDAV 配置文件已创建: ${WEBDAV_CONFIG}"
}

# 创建 systemd 服务
create_webdav_service() {
    LOGD "创建 WebDAV systemd 服务..."
    cat <<EOF >${WEBDAV_SERVICE}
[Unit]
Description=WebDAV server
After=network.target

[Service]
Type=simple
User=root
ExecStart=${WEBDAV_BINARY} --config ${WEBDAV_CONFIG}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable webdav
    LOGI "WebDAV systemd 服务已创建并启用"
}

# WebDAV 状态检查
webdav_status_check() {
    if [[ ! -f "${WEBDAV_SERVICE}" ]]; then
        return ${WEBDAV_STATUS_NOT_INSTALL}
    fi
    if systemctl is-active webdav >/dev/null 2>&1; then
        return ${WEBDAV_STATUS_RUNNING}
    else
        return ${WEBDAV_STATUS_NOT_RUNNING}
    fi
}

# 显示 WebDAV 状态
show_webdav_status() {
    webdav_status_check
    case $? in
        ${WEBDAV_STATUS_RUNNING})
            echo -e "[INF] WebDAV 状态: ${green}已运行${plain}"
            local installed_version=$(${WEBDAV_BINARY} --version | awk '{print $2}')
            echo -e "[INF] 当前安装版本: ${green}${installed_version}${plain}"
            show_webdav_enable_status
            show_webdav_running_status
            ;;
        ${WEBDAV_STATUS_NOT_RUNNING})
            echo -e "[INF] WebDAV 状态: ${yellow}未运行${plain}"
            if [[ -f "${WEBDAV_BINARY}" ]]; then
                local installed_version=$(${WEBDAV_BINARY} --version | awk '{print $2}')
                echo -e "[INF] 当前安装版本: ${green}${installed_version}${plain}"
            fi
            show_webdav_enable_status
            ;;
        ${WEBDAV_STATUS_NOT_INSTALL})
            echo -e "[INF] WebDAV 状态: ${red}未安装${plain}"
            ;;
    esac

    # 获取并显示 GitHub 上的最新版本号
    local latest_version=$(get_latest_version)
    if [[ -n "${latest_version}" ]]; then
        echo -e "[INF] 最新版本号: ${green}${latest_version}${plain}"
    else
        LOGE "获取最新版本号失败"
    fi
}

# 显示 WebDAV 运行状态
show_webdav_running_status() {
    webdav_status_check
    if [[ $? == ${WEBDAV_STATUS_RUNNING} ]]; then
        local runTime=$(systemctl show -p ActiveEnterTimestamp webdav | cut -d= -f2)
        LOGI "WebDAV 运行时长：${runTime}"
    else
        LOGE "WebDAV 未运行"
    fi
}

# 显示 WebDAV 是否开机自启
show_webdav_enable_status() {
    if systemctl is-enabled webdav >/dev/null 2>&1; then
        echo -e "[INF] WebDAV 是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] WebDAV 是否开机自启: ${red}否${plain}"
    fi
}

# 安装 WebDAV
install_webdav() {
    LOGD "开始安装 WebDAV..."
    if [[ -f "${WEBDAV_SERVICE}" ]]; then
        LOGE "WebDAV 已安装，请勿重复安装"
        return 1
    fi

    os_check && arch_check && install_base
    download_webdav
    create_webdav_config
    create_webdav_service

    systemctl start webdav || { LOGE "启动 WebDAV 失败"; return 1; }
    LOGI "WebDAV 安装并启动成功"
}

# 更新 WebDAV
update_webdav() {
    LOGD "开始更新 WebDAV..."
    if [[ ! -f "${WEBDAV_SERVICE}" ]]; then
        LOGE "WebDAV 未安装，无法更新"
        return 1
    fi

    os_check && arch_check
    systemctl stop webdav
    rm -f ${WEBDAV_BINARY}
    download_webdav
    systemctl start webdav || { LOGE "启动 WebDAV 失败"; return 1; }
    LOGI "WebDAV 更新完成"
}

# 卸载 WebDAV
uninstall_webdav() {
    LOGD "开始卸载 WebDAV..."
    systemctl stop webdav
    systemctl disable webdav
    rm -f ${WEBDAV_SERVICE}
    systemctl daemon-reload
    rm -f ${WEBDAV_BINARY}
    rm -f ${WEBDAV_CONFIG}
    LOGI "WebDAV 卸载完成"
}

# 显示菜单
show_menu() {
    echo -e "
${green} WebDAV 服务管理脚本${plain}
————————————————
${green}0.${plain} 退出脚本
————————————————
${green}1.${plain} 安装 WebDAV
${green}2.${plain} 更新 WebDAV
${green}3.${plain} 重启 WebDAV
${green}4.${plain} 卸载 WebDAV
————————————————
${green}5.${plain} 查看 WebDAV 日志
${green}6.${plain} 查看 WebDAV 报错
"
    show_webdav_status
    echo && read -p "请输入选择 [0-6] (默认0): " num
    [[ -z "${num}" ]] && num=0
    case "${num}" in
        0) exit 0 ;;
        1) install_webdav && show_menu ;;
        2) update_webdav && show_menu ;;
        3) systemctl restart webdav && show_menu ;;
        4) uninstall_webdav && show_menu ;;
        5) systemctl status webdav && show_menu ;;
        6) journalctl -u webdav -n 10 && show_menu ;;
        *) LOGE "请输入正确的选项 [0-6]" && show_menu ;;
    esac
}

main() {
    show_menu
}

main
