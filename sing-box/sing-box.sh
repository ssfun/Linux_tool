#!/bin/bash
#####################################################
# ssfun's Linux Tool
# Author: ssfun
# Date: 2025-01-30
# Version: 2.0.0
#####################################################

# 基本定义
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
pink='\033[1;35m'
green='\033[0;32m'
yellow='\033[0;33m'

# 操作系统架构环境
OS=''
ARCH=''

# 版本和配置类型 (稳定版)
SING_BOX_VERSION_TYPE="stable" # 稳定版
SING_BOX_CONFIG_TYPE="warp" # warp 或 nowarp

# sing-box 环境
SING_BOX_VERSION=''
SING_BOX_CONFIG_PATH='/usr/local/etc/sing-box'
SING_BOX_LOG_PATH='/var/log/sing-box'
SING_BOX_LIB_PATH='/var/lib/sing-box'
SING_BOX_BINARY='/usr/local/bin/sing-box'
SING_BOX_SERVICE='/etc/systemd/system/sing-box.service'

# sing-box 状态定义
declare -r SING_BOX_STATUS_RUNNING=1
declare -r SING_BOX_STATUS_NOT_RUNNING=0
declare -r SING_BOX_STATUS_NOT_INSTALL=255

# 工具函数
function LOGE() {
    echo -e "${red}[错误] $* ${plain}"
}
function LOGI() {
    echo -e "${green}[信息] $* ${plain}"
}
function LOGD() {
    echo -e "${yellow}[调试] $* ${plain}"
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

# 检查是否为 root 用户
[[ $EUID -ne 0 ]] && LOGE "请使用 root 用户运行该脚本" && exit 1

# 系统检查
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

# 架构检查
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

# 安装基础包
install_base() {
    if [[ ${OS} == "ubuntu" || ${OS} == "debian" ]]; then
        if ! dpkg -s tar >/dev/null 2>&1; then
            apt install tar -y
        fi
    elif [[ ${OS} == "centos" ]]; then
        if ! rpm -q tar >/dev/null 2>&1; then
            yum install tar -y
        fi
    fi
}

# 获取最新版本信息
get_latest_version() {
    local type=$1  # 只有 stable
    local info_type=$2  # version 或 name
    local api_response
    local latest_version

    api_response=$(curl -fsSL -m 10 "https://api.github.com/repos/SagerNet/sing-box/releases/latest") || return 1
    latest_version=$(echo "$api_response" | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)

    if [[ -z "${latest_version}" ]]; then
        return 1
    fi

    if [[ "${info_type}" == "name" ]]; then
        echo "${latest_version#v}"
    else
        echo "${latest_version}"
    fi
}

# sing-box 状态检查
sing_box_status_check() {
    if [[ ! -f "${SING_BOX_SERVICE}" ]]; then
        return ${SING_BOX_STATUS_NOT_INSTALL}
    fi
    sing_box_status_temp=$(systemctl is-active sing-box)
    if [[ "${sing_box_status_temp}" == "active" ]]; then
        return ${SING_BOX_STATUS_RUNNING}
    else
        return ${SING_BOX_STATUS_NOT_RUNNING}
    fi
}

# 显示 sing-box 状态
show_sing_box_status() {
    sing_box_status_check
    case $? in
        0)
            echo -e "[信息] sing-box 状态: ${yellow}未运行${plain}"
            if [ -f "${SING_BOX_BINARY}" ]; then
                local version_info=$(${SING_BOX_BINARY} version)
                local version=$(echo "$version_info" | head -n1 | awk '{print $3}')
                echo -e "[信息] sing-box 版本: ${green}${version}${plain}"
                # 检查最新版本
                local latest_stable=$(get_latest_version "stable" "version" | sed 's/^v//')
                echo -e "[信息] 最新版本: ${green}${latest_stable}${plain}"
            fi
            show_sing_box_enable_status
            ;;
        1)
            echo -e "[信息] sing-box 状态: ${green}已运行${plain}"
            if [ -f "${SING_BOX_BINARY}" ]; then
                local version_info=$(${SING_BOX_BINARY} version)
                local version=$(echo "$version_info" | head -n1 | awk '{print $3}')
                echo -e "[信息] sing-box 版本: ${green}${version}${plain}"
                # 检查最新版本
                if [ -f "${SING_BOX_CONFIG_PATH}/install.info" ]; then
                    source ${SING_BOX_CONFIG_PATH}/install.info
                    local latest_version=$(get_latest_version "${SING_BOX_VERSION_TYPE}" "version" | sed 's/^v//')
                    echo -e "[信息] 最新版本: ${green}${latest_version}${plain}"
                    # 比较版本,提示是否需要更新
                    if [ "${version}" != "${latest_version}" ]; then
                        echo -e "[信息] 发现新版本: ${yellow}建议更新${plain}"
                    fi
                fi
                 # 显示更多版本信息
                local environment=$(echo "$version_info" | grep "Environment:" | awk '{print $2" "$3}')
                local tags=$(echo "$version_info" | grep "Tags:" | cut -d':' -f2-)
                echo -e "[信息] 环境信息: ${green}${environment}${plain}"
                echo -e "[信息] 包含功能: ${green}${tags}${plain}"
            fi
            if [ -f "${SING_BOX_CONFIG_PATH}/install.info" ]; then
                source ${SING_BOX_CONFIG_PATH}/install.info
                echo -e "[信息] 版本类型: ${green}${SING_BOX_VERSION_TYPE}${plain}"
                echo -e "[信息] 配置类型: ${green}${SING_BOX_CONFIG_TYPE}${plain}"
            fi
            show_sing_box_enable_status
            show_sing_box_running_status
            ;;
        255)
            echo -e "[信息] sing-box 状态: ${red}未安装${plain}"
            # 显示最新稳定版本信息
            local latest_stable=$(get_latest_version "stable" "version" | sed 's/^v//')
            echo -e "[信息] 最新版本: ${green}${latest_stable}${plain}"
            ;;
    esac
}

# 显示 sing-box 运行时长
show_sing_box_running_status() {
    sing_box_status_check
    if [[ $? == ${SING_BOX_STATUS_RUNNING} ]]; then
        local sing_box_runTime=$(systemctl status sing-box | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "sing-box 运行时长：${sing_box_runTime}"
    else
        LOGE "sing-box 未运行"
    fi
}

# 显示 sing-box 开机自启状态
show_sing_box_enable_status() {
    local sing_box_enable_status_temp=$(systemctl is-enabled sing-box)
    if [[ "${sing_box_enable_status_temp}" == "enabled" ]]; then
        echo -e "[信息] sing-box 是否开机自启: ${green}是${plain}"
    else
        echo -e "[信息] sing-box 是否开机自启: ${red}否${plain}"
    fi
}

# 下载 sing-box 二进制文件
install_sing_box_binary() {
    local version=$1
    local name=$2
    local temp_dir
    local download_link
    local new_binary_path

    if [[ -z "${version}" || -z "${name}" ]]; then
        LOGE "获取 sing-box 版本信息失败"
        return 1
    fi

    temp_dir=$(mktemp -d) || return 1
    download_link="https://github.com/SagerNet/sing-box/releases/download/${version}/sing-box-${name}-linux-${ARCH}.tar.gz"
    new_binary_path="${SING_BOX_BINARY}.new"

    LOGD "开始下载 sing-box_${name}"
    if ! curl -fsSL -o "${temp_dir}/sing-box.tar.gz" "${download_link}"; then
        rm -rf "${temp_dir}"
        LOGE "sing-box 下载失败"
        return 1
    fi

    if ! tar -xzf "${temp_dir}/sing-box.tar.gz" -C "${temp_dir}" --strip-components=1; then
        rm -rf "${temp_dir}"
        LOGE "sing-box 解压失败"
        return 1
    fi

    if [[ ! -f "${temp_dir}/sing-box" ]]; then
        rm -rf "${temp_dir}"
        LOGE "sing-box 二进制文件缺失"
        return 1
    fi

    if ! install -m 755 "${temp_dir}/sing-box" "${new_binary_path}"; then
        rm -f "${new_binary_path}"
        rm -rf "${temp_dir}"
        LOGE "sing-box 安装失败"
        return 1
    fi

    if ! mv -f "${new_binary_path}" "${SING_BOX_BINARY}"; then
        rm -f "${new_binary_path}"
        rm -rf "${temp_dir}"
        LOGE "sing-box 安装失败"
        return 1
    fi

    rm -rf "${temp_dir}"
    LOGI "sing-box 下载完毕"
}

# 安装 sing-box systemd 服务
install_sing_box_systemd_service() {
    LOGD "开始安装 sing-box systemd 服务..."
    cat <<EOF >${SING_BOX_SERVICE}
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target
[Service]
WorkingDirectory=${SING_BOX_LIB_PATH}
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
ExecStart=${SING_BOX_BINARY} run -c ${SING_BOX_CONFIG_PATH}/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload || return 1
    systemctl enable sing-box || return 1
    LOGD "安装 sing-box systemd 服务成功"
}

# 检测 IPv6 连通性
check_ipv6_support() {
    # 测试地址：Google IPv6 DNS
    local test_ipv6="2001:4860:4860::8888"
    local ping_count=1
    local timeout=3
    # 确定使用的 ping 命令
    local ping_cmd=""
    if command -v ping6 >/dev/null 2>&1; then
        ping_cmd="ping6"
    else
        ping_cmd="ping -6"
    fi
    # 测试连通性
    if $ping_cmd -c ${ping_count} -W ${timeout} ${test_ipv6} >/dev/null 2>&1; then
        LOGI "IPv6 连通正常"
        return 0
    else
        LOGE "IPv6 无法连通"
        return 1
    fi
}

validate_sing_box_config() {
    if ! "${SING_BOX_BINARY}" check -c "${SING_BOX_CONFIG_PATH}/config.json"; then
        LOGE "sing-box 配置校验失败"
        return 1
    fi
}

# 配置 sing-box 配置
configuration_sing_box_config() {
    local config_backup=''

    LOGD "开始配置 sing-box 配置文件..."
    # 检测IPv6支持
    check_ipv6_support
    local ipv6_support=$?

    if [[ -f "${SING_BOX_CONFIG_PATH}/config.json" ]]; then
        config_backup=$(mktemp) || return 1
        cp "${SING_BOX_CONFIG_PATH}/config.json" "${config_backup}" || return 1
    fi

    # 让用户选择是否启用 WARP
    echo -e "请选择配置类型:"
    echo -e "${green}1.${plain} 启用 WARP"
    echo -e "${green}2.${plain} 不启用 WARP"
    read -p "请输入选择[1-2]:" config_type
    case "${config_type}" in
        1)
            SING_BOX_CONFIG_TYPE="warp"
            # 获取 WARP 配置所需参数
            read -p "请输入 warp ipv6:" warpv6
            [ -z "${warpv6}" ] && LOGE "warp ipv6 不能为空" && return 1
            read -p "请输入 warp private key:" warpkey
            [ -z "${warpkey}" ] && LOGE "warp private key 不能为空" && return 1
            read -p "请输入 warp reserved:" warpreserved
            [ -z "${warpreserved}" ] && LOGE "warp reserved 不能为空" && return 1
            ;;
        2)
            SING_BOX_CONFIG_TYPE="nowarp"
            ;;
        *)
            LOGE "请输入正确的选项 [1-2]"
            return 1
            ;;
    esac
    # 获取通用配置参数
    read -p "请输入 ss 端口:" sport
    [ -z "${sport}" ] && LOGE "ss端口不能为空" && return 1
    read -p "请输入 trojan 端口:" tport
    [ -z "${tport}" ] && LOGE "trojan端口不能为空" && return 1
    read -p "请输入密码:" pswd
    [ -z "${pswd}" ] && LOGE "密码不能为空" && return 1
    # 根据配置类型和IPv6支持情况选择模板
    if [[ "${SING_BOX_CONFIG_TYPE}" == "warp" ]]; then
        if [[ ${ipv6_support} == 0 ]]; then
            generate_config_warp_ipv6
        else
            generate_config_warp_noipv6
        fi
    else
        generate_config_nowarp
    fi

    if ! validate_sing_box_config; then
        if [[ -n "${config_backup}" ]]; then
            mv -f "${config_backup}" "${SING_BOX_CONFIG_PATH}/config.json"
        else
            rm -f "${SING_BOX_CONFIG_PATH}/config.json"
        fi
        return 1
    fi

    rm -f "${config_backup}"
    echo "SING_BOX_VERSION_TYPE=${SING_BOX_VERSION_TYPE}" > "${SING_BOX_CONFIG_PATH}/install.info"
    echo "SING_BOX_CONFIG_TYPE=${SING_BOX_CONFIG_TYPE}" >> "${SING_BOX_CONFIG_PATH}/install.info"
    if [[ "${SING_BOX_CONFIG_TYPE}" == "warp" ]]; then
        echo "IPV6_SUPPORT=$([ ${ipv6_support} == 0 ] && echo "yes" || echo "no")" >> "${SING_BOX_CONFIG_PATH}/install.info"
    fi
    LOGD "sing-box 配置文件完成"
}

# 以下是各种配置模板生成函数
generate_config_warp_ipv6() {
  cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
    "log": {
        "disabled": false,
        "level": "info",
        "output": "${SING_BOX_LOG_PATH}/sing-box.log",
        "timestamp": true
    },
    "endpoints": [
        {
            "type": "wireguard",
            "tag": "wg-ep",
            "system": false,
            "name": "wg0",
            "mtu": 1280,
            "address": [
                "172.16.0.2/32",
                "$warpv6"
            ],
            "private_key": "$warpkey",
            "listen_port": 2408,
            "peers": [
                {
                    "address": "engage.cloudflareclient.com",
                    "port": 2408,
                    "public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                    "allowed_ips": [
                        "0.0.0.0/0",
                        "::/0"
                    ],
                    "persistent_keepalive_interval": 30,
                    "reserved": [$warpreserved]
                }
            ]
        }
    ],
    "inbounds": [
        {
            "type": "shadowsocks",
            "tag": "ss-in",
            "listen": "::",
            "listen_port": $sport,
            "tcp_fast_open": true,
            "method": "2022-blake3-aes-128-gcm",
            "password": "$pswd"
        },
        {
            "type": "trojan",
            "tag": "trojan-in",
            "listen": "::",
            "listen_port": $tport,
            "users": [
                {
                    "name": "trojan",
                    "password": "$pswd"
                }
            ],
            "transport": {
                "type": "ws",
                "path": "/media-cdn",
                "max_early_data": 2048,
                "early_data_header_name": "Sec-WebSocket-Protocol"
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ],
    "route": {
        "rules": [
            {
                "inbound": ["ss-in","trojan-in"],
                "action": "sniff",
                "timeout": "1s"
            },
            {
                "rule_set": "openai",
                "action": "resolve",
                "strategy": "prefer_ipv6"
            },
            {
                "domain_suffix": "perplexity.ai",
                "action": "resolve",
                "strategy": "prefer_ipv6"
            },
            {
                "domain_suffix": "oyunfor.com",
                "action": "resolve",
                "strategy": "ipv4_only"
            },
            {
                "domain": [
                    "speedysub.itunes.apple.com",
                    "fpinit.itunes.apple.com",
                    "entitlements.itunes.apple.com"
                ],
                "action": "route",
                "outbound": "wg-ep"
            },
            {
                "domain_suffix": "perplexity.ai",
                "action": "route",
                "outbound": "wg-ep"
            },
            {
                "ip_cidr": ["1.1.1.1/32"],
                "action": "route",
                "outbound": "wg-ep"
            },
            {
                "rule_set": "openai",
                "action": "route",
                "outbound": "wg-ep"
            }
        ],
        "rule_set": [
            {
                "tag": "openai",
                "type": "remote",
                "format": "binary",
                "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-openai.srs",
                "download_detour": "direct"
            }
        ],
        "final": "direct",
        "auto_detect_interface": true
    },
    "experimental": {
        "cache_file": {
            "enabled": true
        }
    }
}
EOF
}
generate_config_warp_noipv6() {
  cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
    "log": {
        "disabled": false,
        "level": "info",
        "output": "${SING_BOX_LOG_PATH}/sing-box.log",
        "timestamp": true
    },
    "endpoints": [
        {
            "type": "wireguard",
            "tag": "wg-ep",
            "system": false,
            "name": "wg0",
            "mtu": 1280,
            "address": [
                "172.16.0.2/32",
                "$warpv6"
            ],
            "private_key": "$warpkey",
            "listen_port": 2408,
            "peers": [
                {
                    "address": "engage.cloudflareclient.com",
                    "port": 2408,
                    "public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                    "allowed_ips": [
                        "0.0.0.0/0",
                        "::/0"
                    ],
                    "persistent_keepalive_interval": 30,
                    "reserved": [$warpreserved]
                }
            ]
        }
    ],
    "inbounds": [
        {
            "type": "shadowsocks",
            "tag": "ss-in",
            "listen": "::",
            "listen_port": $sport,
            "tcp_fast_open": true,
            "method": "2022-blake3-aes-128-gcm",
            "password": "$pswd"
        },
        {
            "type": "trojan",
            "tag": "trojan-in",
            "listen": "::",
            "listen_port": $tport,
            "users": [
                {
                    "name": "trojan",
                    "password": "$pswd"
                }
            ],
            "transport": {
                "type": "ws",
                "path": "/media-cdn",
                "max_early_data": 2048,
                "early_data_header_name": "Sec-WebSocket-Protocol"
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ],
    "route": {
        "rules": [
            {
                "inbound": ["ss-in","trojan-in"],
                "action": "sniff",
                "timeout": "1s"
            },
            {
                "rule_set": "openai",
                "action": "resolve",
                "strategy": "prefer_ipv6"
            },
            {
                 "domain_suffix": "perplexity.ai",
                "action": "resolve",
                "strategy": "prefer_ipv6"
            },
            {
                "domain_suffix": "oyunfor.com",
                "action": "resolve",
                "strategy": "ipv4_only"
            },
            {
                "domain": [
                    "speedysub.itunes.apple.com",
                    "fpinit.itunes.apple.com",
                    "entitlements.itunes.apple.com"
                ],
                "action": "route",
                "outbound": "wg-ep"
            },
             {
                "domain_suffix": "perplexity.ai",
                "action": "route",
                "outbound": "wg-ep"
            },
             {
                "ip_cidr": ["1.1.1.1/32"],
                "action": "route",
                "outbound": "wg-ep"
            },
            {
                "rule_set": "openai",
                "action": "route",
                "outbound": "wg-ep"
            },
             {
                "domain_keyword": ["ipv6"],
                "action": "route",
                "outbound": "wg-ep"
            },
            {
                "ip_version": 6,
                "action": "route",
                "outbound": "wg-ep"
            }
        ],
        "rule_set": [
            {
                "tag": "openai",
                "type": "remote",
                "format": "binary",
                "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-openai.srs",
                "download_detour": "direct"
            }
        ],
        "final": "direct",
        "auto_detect_interface": true
    },
    "experimental": {
        "cache_file": {
            "enabled": true
        }
    }
}
EOF
}
generate_config_nowarp() {
  cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
    "log": {
        "disabled": false,
        "level": "info",
        "output": "${SING_BOX_LOG_PATH}/sing-box.log",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "shadowsocks",
            "tag": "ss-in",
            "listen": "::",
            "listen_port": $sport,
            "tcp_fast_open": true,
            "method": "2022-blake3-aes-128-gcm",
            "password": "$pswd"
        },
        {
            "type": "trojan",
            "tag": "trojan-in",
            "listen": "::",
            "listen_port": $tport,
            "users": [
                {
                    "name": "trojan",
                    "password": "$pswd"
                }
            ],
            "transport": {
                "type": "ws",
                "path": "/media-cdn",
                "max_early_data": 2048,
                "early_data_header_name": "Sec-WebSocket-Protocol"
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ],
    "route": {
        "rules": [
             {
                "inbound": ["ss-in","trojan-in"],
                "action": "sniff",
                "timeout": "1s"
            },
            {
                "domain_suffix": "oyunfor.com",
                "action": "resolve",
                "strategy": "ipv4_only"
            }
        ],
        "rule_set": [],
        "final": "direct",
        "auto_detect_interface": true
    },
    "experimental": {
        "cache_file": {
            "enabled": true
        }
    }
}
EOF
}

# 安装 sing-box
install_sing_box() {
    local latest_version
    local latest_name

    LOGD "开始安装 sing-box"
    if [[ -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        return 1
    fi

    os_check || return 1
    arch_check || return 1
    install_base || return 1

    mkdir -p "${SING_BOX_CONFIG_PATH}" || return 1
    mkdir -p "${SING_BOX_LOG_PATH}" || return 1
    mkdir -p "${SING_BOX_LIB_PATH}" || return 1

    latest_version=$(get_latest_version "${SING_BOX_VERSION_TYPE}" "version") || {
        LOGE "获取 sing-box 最新版本失败"
        return 1
    }
    latest_name=$(get_latest_version "${SING_BOX_VERSION_TYPE}" "name") || {
        LOGE "获取 sing-box 最新版本名称失败"
        return 1
    }

    install_sing_box_binary "${latest_version}" "${latest_name}" || return 1
    install_sing_box_systemd_service || return 1
    configuration_sing_box_config || return 1

    if systemctl start sing-box; then
        LOGI "sing-box 已完成安装并启动"
    else
        LOGE "sing-box 安装失败，请检查日志"
        return 1
    fi
}

# 更新 sing-box
update_sing_box() {
    local current_version
    local latest_version
    local latest_name
    local was_running=0

    LOGD "开始更新 sing-box..."
    if [[ ! -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统未安装 sing-box, 更新失败"
        return 1
    fi

    current_version=$(${SING_BOX_BINARY} version | head -n1 | awk '{print $3}')
    LOGD "当前版本: ${current_version}"

    if [[ ! -f "${SING_BOX_CONFIG_PATH}/install.info" ]]; then
        LOGI "未找到安装信息文件,默认使用stable版本"
        echo "SING_BOX_VERSION_TYPE=${SING_BOX_VERSION_TYPE}" > "${SING_BOX_CONFIG_PATH}/install.info"
    else
        source "${SING_BOX_CONFIG_PATH}/install.info"
    fi

    latest_version=$(get_latest_version "${SING_BOX_VERSION_TYPE}" "version") || {
        LOGE "获取 sing-box 最新版本失败"
        return 1
    }
    latest_name=$(get_latest_version "${SING_BOX_VERSION_TYPE}" "name") || {
        LOGE "获取 sing-box 最新版本名称失败"
        return 1
    }

    if [[ "${current_version}" == "${latest_version#v}" ]]; then
        LOGI "当前已是最新版本,无需更新"
        return 0
    fi

    LOGD "最新版本: ${latest_version}"
    LOGD "版本类型: ${SING_BOX_VERSION_TYPE}"

    read -p "确认更新到最新版本? [y/n]: " confirm
    if [[ "${confirm}" != "y" ]]; then
        LOGI "取消更新"
        return 0
    fi

    os_check || return 1
    arch_check || return 1

    if systemctl is-active --quiet sing-box; then
        was_running=1
    fi

    install_sing_box_binary "${latest_version}" "${latest_name}" || return 1

    if [[ ${was_running} == 1 ]]; then
        if systemctl restart sing-box; then
            LOGI "sing-box 已更新至 ${latest_version}"
        else
            LOGE "sing-box 升级失败，请检查日志"
            return 1
        fi
    else
        LOGI "sing-box 已更新至 ${latest_version}"
    fi
}

# 卸载 sing-box
uninstall_sing_box() {
    LOGD "开始卸载 sing-box..."
    systemctl stop sing-box >/dev/null 2>&1
    systemctl disable sing-box >/dev/null 2>&1
    rm -f "${SING_BOX_SERVICE}"
    systemctl daemon-reload || return 1
    rm -f "${SING_BOX_BINARY}"
    rm -rf "${SING_BOX_CONFIG_PATH}"
    rm -rf "${SING_BOX_LOG_PATH}"
    rm -rf "${SING_BOX_LIB_PATH}"
    LOGI "卸载 sing-box 成功"
}

reload_sing_box_config() {
    if systemctl is-active --quiet sing-box; then
        systemctl restart sing-box || return 1
        LOGI "sing-box 配置已更新并重启"
    else
        LOGI "sing-box 配置已更新，服务当前未运行"
    fi
}

# 显示菜单
show_menu() {
    local num

    while true; do
        echo -e "
${green}Sing-box 管理脚本${plain}
————————————————
${green}0.${plain} 退出脚本
————————————————
${green}1.${plain} 安装 sing-box
${green}2.${plain} 更新 sing-box
${green}3.${plain} 重启 sing-box
————————————————
${green}4.${plain} 更新 sing-box 配置
${green}5.${plain} 修改 sing-box 配置
————————————————
${green}6.${plain} 查看 sing-box 状态
${green}7.${plain} 查看 sing-box 日志
————————————————
${green}8.${plain} 卸载 sing-box
"
        show_sing_box_status
        echo && read -p "请输入选择 [0-8]:" num
        case "${num}" in
            0) exit 0
            ;;
            1) install_sing_box
            ;;
            2) update_sing_box
            ;;
            3) systemctl restart sing-box
            ;;
            4) configuration_sing_box_config && reload_sing_box_config
            ;;
            5) nano "${SING_BOX_CONFIG_PATH}/config.json"
            ;;
            6) systemctl status sing-box
            ;;
            7) journalctl -u sing-box.service -n 50 --no-pager
            ;;
            8) uninstall_sing_box
            ;;
            *) LOGE "请输入正确的选项 [0-8]"
            ;;
        esac
    done
}
main() {
    show_menu
}
main "$@"
