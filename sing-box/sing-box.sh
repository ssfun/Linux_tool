#!/bin/bash
#####################################################
# ssfun's Linux Tool
# Author: ssfun
# Date: 2024-11-28
# Version: 2.0.0
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

# Version and config type
SING_BOX_VERSION_TYPE="stable" # stable或beta
SING_BOX_CONFIG_TYPE="warp" # warp或nowarp

# sing-box env
SING_BOX_VERSION=''
SING_BOX_CONFIG_PATH='/usr/local/etc/sing-box'
SING_BOX_LOG_PATH='/var/log/sing-box'
SING_BOX_LIB_PATH='/var/lib/sing-box'
SING_BOX_BINARY='/usr/local/bin/sing-box'
SING_BOX_SERVICE='/etc/systemd/system/sing-box.service'

# sing-box status define
declare -r SING_BOX_STATUS_RUNNING=1
declare -r SING_BOX_STATUS_NOT_RUNNING=0
declare -r SING_BOX_STATUS_NOT_INSTALL=255

# Utils
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

# Root user check
[[ $EUID -ne 0 ]] && LOGE "请使用root用户运行该脚本" && exit 1

# System check
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

# Arch check
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

# Install base packages
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

# sing-box status check
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

# Show sing-box status
show_sing_box_status() {
    sing_box_status_check
    case $? in
        0)
            echo -e "[INF] sing-box状态: ${yellow}未运行${plain}"
            if [ -f "${SING_BOX_BINARY}" ]; then
                local version_info=$(${SING_BOX_BINARY} version)
                local version=$(echo "$version_info" | head -n1 | awk '{print $3}')
                echo -e "[INF] sing-box版本: ${green}${version}${plain}"
            fi
            show_sing_box_enable_status
            ;;
        1)
            echo -e "[INF] sing-box状态: ${green}已运行${plain}"
            if [ -f "${SING_BOX_BINARY}" ]; then
                local version_info=$(${SING_BOX_BINARY} version)
                local version=$(echo "$version_info" | head -n1 | awk '{print $3}')
                echo -e "[INF] sing-box版本: ${green}${version}${plain}"
                
                # 显示更多版本信息
                local environment=$(echo "$version_info" | grep "Environment:" | awk '{print $2" "$3}')
                local tags=$(echo "$version_info" | grep "Tags:" | cut -d':' -f2-)
                local revision=$(echo "$version_info" | grep "Revision:" | awk '{print $2}')
                local cgo=$(echo "$version_info" | grep "CGO:" | awk '{print $2}')
                
                echo -e "[INF] 环境信息: ${green}${environment}${plain}"
                echo -e "[INF] 包含功能: ${green}${tags}${plain}"
                echo -e "[INF] 修订版本: ${green}${revision}${plain}"
                echo -e "[INF] CGO状态: ${green}${cgo}${plain}"
            fi
            if [ -f "${SING_BOX_CONFIG_PATH}/install.info" ]; then
                source ${SING_BOX_CONFIG_PATH}/install.info
                echo -e "[INF] 版本类型: ${green}${SING_BOX_VERSION_TYPE}${plain}"
                echo -e "[INF] 配置类型: ${green}${SING_BOX_CONFIG_TYPE}${plain}"
            fi
            show_sing_box_enable_status
            show_sing_box_running_status
            ;;
        255)
            echo -e "[INF] sing-box状态: ${red}未安装${plain}"
            ;;
    esac
}

# Show sing-box running status
show_sing_box_running_status() {
    sing_box_status_check
    if [[ $? == ${SING_BOX_STATUS_RUNNING} ]]; then
        local sing_box_runTime=$(systemctl status sing-box | grep Active | awk '{for (i=5;i<=NF;i++)printf("%s ", $i);print ""}')
        LOGI "sing-box运行时长：${sing_box_runTime}"
    else
        LOGE "sing-box未运行"
    fi
}

# Show sing-box enable status
show_sing_box_enable_status() {
    local sing_box_enable_status_temp=$(systemctl is-enabled sing-box)
    if [[ "${sing_box_enable_status_temp}" == "enabled" ]]; then
        echo -e "[INF] sing-box是否开机自启: ${green}是${plain}"
    else
        echo -e "[INF] sing-box是否开机自启: ${red}否${plain}"
    fi
}

# Download sing-box binary
download_sing_box() {
    LOGD "开始获取 sing-box 版本信息"
    
    echo -e "请选择版本类型:"
    echo -e "${green}1.${plain} 稳定版"
    echo -e "${green}2.${plain} 测试版"
    read -p "请输入选择[1-2]:" version_type
    case "${version_type}" in
        1)
            SING_BOX_VERSION_TYPE="stable"
            LATEST_VERSION=$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -E 'tag_name|prerelease' | grep -B1 'false' | head -n1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
            LATEST_NAME=$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -E 'name|prerelease' | grep -B1 'false' | head -n1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
            ;;
        2)
            SING_BOX_VERSION_TYPE="beta"
            LATEST_VERSION=$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -E 'tag_name|prerelease' | grep -B1 'true' | head -n1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
            LATEST_NAME=$(wget -qO- -t1 -T2 "https://api.github.com/repos/SagerNet/sing-box/releases" | grep -E 'name|prerelease' | grep -B1 'true' | head -n1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
            ;;
        *)
            LOGE "请输入正确的选项 [1-2]"
            return 1
            ;;
    esac

    LOGD "LATEST_VERSION:${LATEST_VERSION}"
    LOGD "VERSION_TYPE:${SING_BOX_VERSION_TYPE}"

    LINK="https://github.com/SagerNet/sing-box/releases/download/${LATEST_VERSION}/sing-box-${LATEST_NAME}-linux-${ARCH}.tar.gz"
    
    cd `mktemp -d`
    LOGD "开始下载 sing-box_${LATEST_NAME}"
    wget -nv "${LINK}" -O sing-box.tar.gz
    tar -zxvf sing-box.tar.gz --strip-components=1
    mv sing-box ${SING_BOX_BINARY} && chmod +x ${SING_BOX_BINARY}
    LOGI "sing-box 下载完毕"
}

# Install sing-box systemd service
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
    systemctl daemon-reload
    systemctl enable sing-box
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

# Configuration sing-box config
configuration_sing_box_config() {
    LOGD "开始配置sing-box配置文件..."
    
    # 检测IPv6支持
    check_ipv6_support
    local ipv6_support=$?
    
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

    # 根据版本类型、配置类型和IPv6支持情况选择模板
    if [[ "${SING_BOX_VERSION_TYPE}" == "stable" ]]; then
        if [[ "${SING_BOX_CONFIG_TYPE}" == "warp" ]]; then
            if [[ ${ipv6_support} == 0 ]]; then
                # 1. 稳定版 + WARP + 本机有IPv6配置
                generate_config_stable_warp_ipv6
            else
                # 2. 稳定版 + WARP + 本机无IPv6配置
                generate_config_stable_warp_noipv6
            fi
        else
            # 3. 稳定版 + 无WARP配置
            generate_config_stable_nowarp
        fi
    else
        if [[ "${SING_BOX_CONFIG_TYPE}" == "warp" ]]; then
            if [[ ${ipv6_support} == 0 ]]; then
                # 4. 测试版 + WARP + 本机有IPv6配置
                generate_config_beta_warp_ipv6
            else
                # 5. 测试版 + WARP + 本机无IPv6配置
                generate_config_beta_warp_noipv6
            fi
        else
            # 6. 测试版 + 无WARP配置
            generate_config_beta_nowarp
        fi
    fi

    # 保存版本和配置信息
    echo "SING_BOX_VERSION_TYPE=${SING_BOX_VERSION_TYPE}" > ${SING_BOX_CONFIG_PATH}/install.info
    echo "SING_BOX_CONFIG_TYPE=${SING_BOX_CONFIG_TYPE}" >> ${SING_BOX_CONFIG_PATH}/install.info
    if [[ "${SING_BOX_CONFIG_TYPE}" == "warp" ]]; then
        echo "IPV6_SUPPORT=$([ ${ipv6_support} == 0 ] && echo "yes" || echo "no")" >> ${SING_BOX_CONFIG_PATH}/install.info
    fi

    LOGD "sing-box 配置文件完成"
}

# 以下是各种配置模板生成函数
generate_config_stable_warp_ipv6() {
    cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
  # 稳定版 + WARP + 本机有IPv6 配置
  "log": {
    "disabled": false,
    "level": "info",
    "output": "/var/log/sing-box/sing-box.log",
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
      "password": "$pswd",
      "sniff": true,
      "sniff_override_destination": false,
      "udp_disable_domain_unmapping": true
    },
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": $tport,
      "sniff": true,
      "sniff_override_destination": false,
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
    },
    {
      "type": "direct",
      "tag": "direct-v4",
      "domain_strategy":"ipv4_only"
    },
    {
      "type":"direct",
      "tag":"direct-v6",
      "domain_strategy":"ipv6_only"
    },
    {
      "type": "wireguard",
      "tag": "warp-out",
      "server": "engage.cloudflareclient.com",
      "server_port": 2408,
      "local_address": [
        "172.16.0.2/32",
        "$warpv6"
      ],
      "private_key": "$warpkey",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [$warpreserved],
      "mtu": 1280,
      "fallback_delay": "300ms",
      "domain_strategy": "prefer_ipv6"
    }
  ],
  "route": {
    "rules": [
      {
        "domain_suffix": "oyunfor.com",
        "outbound": "direct-v4"
      },
      {
        "domain_suffix": "perplexity.ai",
        "outbound": "warp-out"
      },
      {
        "domain": [
          "speedysub.itunes.apple.com",
          "fpinit.itunes.apple.com",
          "entitlements.itunes.apple.com"
        ],
        "outbound": "warp-out"
      },
      {
        "ip_cidr": ["1.1.1.1/32"],
        "outbound": "warp-out"
      },
      {
        "rule_set": "openai",
        "outbound": "warp-out"
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

generate_config_stable_warp_noipv6() {
    cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
  # 稳定版 + WARP + 本机无IPv6 配置
  "log": {
    "disabled": false,
    "level": "info",
    "output": "/var/log/sing-box/sing-box.log",
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
      "password": "$pswd",
      "sniff": true,
      "sniff_override_destination": false,
      "udp_disable_domain_unmapping": true
    },
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": $tport,
      "sniff": true,
      "sniff_override_destination": false,
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
    },
    {
      "type": "direct",
      "tag": "direct-v4",
      "domain_strategy":"ipv4_only"
    },
    {
      "type": "wireguard",
      "tag": "warp-out",
      "server": "engage.cloudflareclient.com",
      "server_port": 2408,
      "local_address": [
        "172.16.0.2/32",
        "$warpv6"
      ],
      "private_key": "$warpkey",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [$warpreserved],
      "mtu": 1280,
      "fallback_delay": "300ms"
    }
  ],
  "route": {
    "rules": [
      {
        "domain_suffix": "oyunfor.com",
        "outbound": "direct-v4"
      },
      {
        "domain_suffix": "perplexity.ai",
        "outbound": "warp-out"
      },
      {
        "domain": [
          "speedysub.itunes.apple.com",
          "fpinit.itunes.apple.com",
          "entitlements.itunes.apple.com"
        ],
        "outbound": "warp-out"
      },
      {
        "ip_cidr": ["1.1.1.1/32"],
        "outbound": "warp-out"
      },
      {
        "rule_set": "openai",
        "outbound": "warp-out"
      },
      {
        "domain_keyword": ["ipv6"],
        "outbound": "warp-out"
      },
      {
        "ip_version": 6,
        "outbound": "warp-out"
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
}
EOF
}

generate_config_stable_nowarp() {
    cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
  # 稳定版基础配置
  "log": {
    "disabled": false,
    "level": "info",
    "output": "/var/log/sing-box/sing-box.log",
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
      "password": "$pswd",
      "sniff": true,
      "sniff_override_destination": false,
      "udp_disable_domain_unmapping": true
    },
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": $tport,
      "sniff": true,
      "sniff_override_destination": false,
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
    },
    {
      "type": "direct",
      "tag": "direct-v4",
      "domain_strategy":"ipv4_only"
    }
  ],
  "route": {
    "rules": [
      {
        "domain_suffix": "oyunfor.com",
        "outbound": "direct-v4"
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

generate_config_beta_warp_ipv6() {
    cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
    # 测试版 + WARP + 本机有IPv6 配置
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
            "password": "$pswd",
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
            }，
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

generate_config_beta_warp_noipv6() {
    cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
    # 测试版 + WARP + 本机无IPv6 配置
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
            "password": "$pswd",
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
            }，
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

generate_config_beta_nowarp() {
    cat <<EOF >${SING_BOX_CONFIG_PATH}/config.json
{
    # 测试版基础配置
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
            "password": "$pswd",
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
            }
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

# Install sing-box
install_sing-box() {
    LOGD "开始安装 sing-box"
    if [[ -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        show_menu
        return 1
    fi

    os_check && arch_check && install_base

    mkdir -p "${SING_BOX_CONFIG_PATH}"
    mkdir -p "${SING_BOX_LOG_PATH}"
    mkdir -p "${SING_BOX_LIB_PATH}"

    download_sing_box
    install_sing_box_systemd_service
    configuration_sing_box_config

    systemctl start sing-box
    
    if [[ $? == 0 ]]; then
        LOGI "sing-box 已完成安装并启动"
    else
        LOGE "sing-box 安装失败，请检查日志"
        return 1
    fi
}

# Update sing-box
update_sing-box() {
    LOGD "开始更新sing-box..."
    if [[ ! -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统未安装sing-box,更新失败"
        show_menu
        return 1
    fi

    os_check && arch_check

    systemctl stop sing-box
    rm -f ${SING_BOX_BINARY}
    
    download_sing_box
    
    systemctl restart sing-box
    
    if [[ $? == 0 ]]; then
        LOGI "sing-box 已完成升级"
    else
        LOGE "sing-box 升级失败，请检查日志"
        return 1
    fi
}

# Uninstall sing-box
uninstall_sing-box() {
    LOGD "开始卸载sing-box..."
    systemctl stop sing-box
    systemctl disable sing-box
    rm -f ${SING_BOX_SERVICE}
    systemctl daemon-reload
    rm -f ${SING_BOX_BINARY}
    rm -rf ${SING_BOX_CONFIG_PATH}
    rm -rf ${SING_BOX_LOG_PATH}
    rm -rf ${SING_BOX_LIB_PATH}
    LOGI "卸载sing-box成功"
}

# Show menu
show_menu() {
    echo -e "
${green}Sing-box 管理脚本${plain}
————————————————
${green}0.${plain} 退出脚本
————————————————
${green}1.${plain} 安装 sing-box
${green}2.${plain} 更新 sing-box
${green}3.${plain} 重启 sing-box
${green}4.${plain} 卸载 sing-box
————————————————
${green}5.${plain} 更新 sing-box 配置
${green}6.${plain} 修改 sing-box 配置
${green}7.${plain} 查看 sing-box 日志
${green}8.${plain} 查看 sing-box 报错

"
    show_sing_box_status
    echo && read -p "请输入选择 [0-8]:" num
    case "${num}" in
        0) exit 0
        ;;
        1) install_sing-box && show_menu
        ;;
        2) update_sing-box && show_menu
        ;;
        3) systemctl restart sing-box && show_menu
        ;;
        4) uninstall_sing-box && show_menu
        ;;
        5) configuration_sing_box_config && systemctl status sing-box && show_menu
        ;;
        6) nano ${SING_BOX_CONFIG_PATH}/config.json && show_menu
        ;;
        7) systemctl status sing-box && show_menu
        ;;
        8) journalctl -u sing-box.service -n 10 && show_menu
        ;;
        *) LOGE "请输入正确的选项 [0-8]" && show_menu
        ;;
    esac
}

main() {
    show_menu
}

main $*
