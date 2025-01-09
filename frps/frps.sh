#!/usr/bin/env bash

#####################################################
# FRPS 管理脚本
# 功能：安装、更新、重启、卸载、查看日志、查看报错
# 作者：优化版
# 版本：1.4.0
#####################################################

# 颜色定义
plain='\033[0m'
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[1;34m'

# 缓存最新版本号
LATEST_VERSION_CACHE=""
LATEST_NAME_CACHE=""

# FRPS 状态定义
declare -r FRPS_STATUS_RUNNING=1
declare -r FRPS_STATUS_NOT_RUNNING=0
declare -r FRPS_STATUS_NOT_INSTALL=255

# 检查 root 用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${red}Error: 必须使用 root 用户运行此脚本！${plain}" && exit 1
    fi
}

# 获取系统架构
get_arch() {
    arch=$(arch)
    echo -e "${green}系统架构: ${arch}${plain}"
    if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
        arch="amd64"
    elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
        arch="arm64"
    else
        echo -e "${red}Error: 不支持的系统架构！${plain}" && exit 1
    fi
}

# 获取最新版本号（带缓存）
get_latest_version() {
    if [[ -z "${LATEST_VERSION_CACHE}" ]]; then
        echo -e "${yellow}正在从 GitHub 获取最新版本号...${plain}"
        LATEST_VERSION_CACHE=$(wget -qO- -t1 -T2 "${PPOXY_URL}https://api.github.com/repos/fatedier/frp/releases" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
        LATEST_NAME_CACHE=$(echo "${LATEST_VERSION_CACHE}" | sed 's/v//g')
        echo -e "${green}最新版本号: ${LATEST_VERSION_CACHE}${plain}"
    fi
}

# 显示 FRPS 状态
show_frps_status() {
    check_frps_status
    case $? in
        ${FRPS_STATUS_RUNNING})
            echo -e "${green}[INF] FRPS 状态: 已运行${plain}"
            local version=$(/usr/local/bin/frps --version | grep -oP '(?<=frps version )\d+\.\d+\.\d+')
            echo -e "${green}[INF] FRPS 版本: ${version}${plain}"
            if systemctl is-enabled frps >/dev/null 2>&1; then
                echo -e "${green}[INF] FRPS 是否开机自启: 是${plain}"
            else
                echo -e "${yellow}[INF] FRPS 是否开机自启: 否${plain}"
            fi
            local run_time=$(systemctl show -p ActiveEnterTimestamp frps | cut -d= -f2)
            echo -e "${green}[INF] FRPS 运行时长: ${run_time}${plain}"
            ;;
        ${FRPS_STATUS_NOT_RUNNING})
            echo -e "${yellow}[INF] FRPS 状态: 未运行${plain}"
            local version=$(/usr/local/bin/frps --version | grep -oP '(?<=frps version )\d+\.\d+\.\d+')
            echo -e "${green}[INF] FRPS 版本: ${version}${plain}"
            if systemctl is-enabled frps >/dev/null 2>&1; then
                echo -e "${green}[INF] FRPS 是否开机自启: 是${plain}"
            else
                echo -e "${yellow}[INF] FRPS 是否开机自启: 否${plain}"
            fi
            ;;
        ${FRPS_STATUS_NOT_INSTALL})
            echo -e "${red}[INF] FRPS 状态: 未安装${plain}"
            ;;
    esac
    get_latest_version
    echo -e "${green}[INF] FRPS 最新版本: ${LATEST_VERSION_CACHE}${plain}"
}

# 下载 FRPS
download_frps() {
    ask_pproxy_url
    get_latest_version
    frps_link="${PPOXY_URL}https://github.com/fatedier/frp/releases/download/${LATEST_VERSION_CACHE}/frp_${LATEST_NAME_CACHE}_linux_${arch}.tar.gz"

    cd $(mktemp -d)
    wget -nv "${frps_link}" -O frps.tar.gz
    tar -zxvf frps.tar.gz
    cd frp_${LATEST_NAME_CACHE}_linux_${arch}
    mv frps /usr/local/bin/frps && chmod +x /usr/local/bin/frps
    echo -e "${green}FRPS 下载完成！${plain}"
}

# 询问用户是否设置 PPOXY_URL
ask_pproxy_url() {
    read -p "是否设置代理 URL (PPOXY_URL)? [y/n]: " set_pproxy
    if [[ "${set_pproxy,,}" == "y" || "${set_pproxy,,}" == "yes" ]]; then
        read -p "请输入 PPOXY_URL (例如: http://example.com/): " PPOXY_URL
        echo -e "${green}[INF] 已设置 PPOXY_URL: ${PPOXY_URL}${plain}"
    else
        PPOXY_URL=""
        echo -e "${yellow}[INF] 未设置 PPOXY_URL${plain}"
    fi
}

# 安装 FRPS
install_frps() {
    echo -e "${yellow}正在安装 FRPS...${plain}"
    if [[ -f "/etc/systemd/system/frps.service" ]]; then
        echo -e "${red}Error: 当前系统已安装 FRPS，请使用更新命令！${plain}"
        show_menu
        return 1
    fi

    check_root
    get_arch

    mkdir -p "/usr/local/etc/frps"
    download_frps
    configure_frps_service
    configure_frps_config
    start_frps

    echo -e "${green}FRPS 安装完成并启动！${plain}"
}

# 配置 FRPS 服务
configure_frps_service() {
    echo -e "${yellow}正在配置 FRPS 服务...${plain}"
    cat <<EOF >/etc/systemd/system/frps.service
[Unit]
Description = frp server
After = network.target syslog.target
Wants = network.target

[Service]
Type = simple
ExecStart = /usr/local/bin/frps -c /usr/local/etc/frps/frps.toml

[Install]
WantedBy = multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable frps
    echo -e "${green}FRPS 服务配置完成！${plain}"
}

# 配置 FRPS 配置文件
configure_frps_config() {
    echo -e "${yellow}正在配置 FRPS 配置文件...${plain}"
    read -p "请输入需要监听的端口: " port
    read -p "请输入连接的 token: " token
    cat <<EOF >/usr/local/etc/frps/frps.toml
bindPort = $port
auth.method = "token"
auth.token = "$token"
transport.tcpMux = true
transport.maxPoolCount = 10
EOF
    echo -e "${green}FRPS 配置文件配置完成！${plain}"
}

# 启动 FRPS
start_frps() {
    echo -e "${yellow}正在启动 FRPS...${plain}"
    systemctl start frps || { echo -e "${red}Error: 启动 FRPS 失败！${plain}"; return 1; }
    echo -e "${green}FRPS 启动完成！${plain}"
}

# 更新 FRPS
update_frps() {
    echo -e "${yellow}正在更新 FRPS...${plain}"
    check_root
    get_arch

    systemctl stop frps
    download_frps
    systemctl restart frps

    echo -e "${green}FRPS 更新完成！${plain}"
}

# 卸载 FRPS
uninstall_frps() {
    echo -e "${yellow}正在卸载 FRPS...${plain}"
    systemctl stop frps
    systemctl disable frps
    rm -f /etc/systemd/system/frps.service
    rm -f /usr/local/bin/frps
    rm -rf /usr/local/etc/frps
    systemctl daemon-reload
    echo -e "${green}FRPS 卸载完成！${plain}"
}

# 显示菜单
show_menu() {
    echo -e "
${green}FRPS 管理脚本${plain}
————————————————
${green}0.${plain} 退出脚本
————————————————
${green}1.${plain} 安装 FRPS
${green}2.${plain} 更新 FRPS
${green}3.${plain} 重启 FRPS
${green}4.${plain} 卸载 FRPS
————————————————
${green}5.${plain} 查看 FRPS 日志
${green}6.${plain} 查看 FRPS 报错
————————————————
"
    show_frps_status
    read -p "请输入选择 [0-6]: " num
    case "${num}" in
        0) exit 0 ;;
        1) install_frps && show_menu ;;
        2) update_frps && show_menu ;;
        3) systemctl restart frps && show_menu ;;
        4) uninstall_frps && show_menu ;;
        5) systemctl status frps && show_menu ;;
        6) journalctl -u frps -p 3 -xb --no-pager && show_menu ;;
        *) echo -e "${red}请输入正确的选项 [0-6]${plain}" && show_menu ;;
    esac
}

# 主函数
main() {
    show_menu
}

main
