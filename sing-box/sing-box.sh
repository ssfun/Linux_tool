#!/bin/bash
#####################################################
# ssfun's Linux Tool
# Author: ssfun
# Date: 2026-09-04
# Version: 3.3.0
#####################################################

# 基本定义
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
green='\033[0;32m'
yellow='\033[0;33m'

# 操作系统架构环境
OS=''
ARCH=''

# GitHub 加速前缀, 通过 -p/--proxy 或环境变量 GITHUB_PROXY 设置
# 用法:
#   bash <(curl -sL https://raw.githubusercontent.com/ssfun/Linux_tool/main/sing-box/sing-box.sh) -p https://proxy.com
#   GITHUB_PROXY=https://proxy.com bash <(curl -sL https://raw.githubusercontent.com/ssfun/Linux_tool/main/sing-box/sing-box.sh)
GITHUB_PROXY="${GITHUB_PROXY:-}"

# 版本和配置类型 (稳定版)
SING_BOX_VERSION_TYPE="stable"
SING_BOX_CONFIG_TYPE="warp"

# sing-box 环境
SING_BOX_CONFIG_PATH='/usr/local/etc/sing-box'
SING_BOX_LOG_PATH='/var/log/sing-box'
SING_BOX_LIB_PATH='/var/lib/sing-box'
SING_BOX_BINARY='/usr/local/bin/sing-box'
SING_BOX_SERVICE='/etc/systemd/system/sing-box.service'
SING_BOX_LOGROTATE='/etc/logrotate.d/sing-box'

WARP_V4_ADDR='172.16.0.2/32'
WARP_PUBLIC_KEY='bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo='
GEOSITE_RULESET_BASE='https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set'

# sing-box 状态定义
declare -r SING_BOX_STATUS_RUNNING=1
declare -r SING_BOX_STATUS_NOT_RUNNING=0
declare -r SING_BOX_STATUS_NOT_INSTALL=255

# 工具函数
LOGE() {
    echo -e "${red}[错误] $* ${plain}"
}
LOGI() {
    echo -e "${green}[信息] $* ${plain}"
}
LOGD() {
    echo -e "${yellow}[调试] $* ${plain}"
}
echo_info() {
    local label="$1" value="$2" color="${3:-$green}"
    echo -e "[信息] ${label}: ${color}${value}${plain}"
}
confirm() {
    local temp
    if [[ $# -gt 1 ]]; then
        echo && read -p "$1 [默认$2]: " temp
        [[ -z "${temp}" ]] && temp=$2
    else
        read -p "$1 [y/n]: " temp
    fi
    [[ "${temp}" == "y" || "${temp}" == "Y" ]]
}
require_input() {
    local prompt="$1" var="$2" err="$3"
    read -p "${prompt}" "${var}"
    if [[ -z "${!var}" ]]; then
        LOGE "${err}"
        return 1
    fi
}
require_warp_creds() {
    local label="$1"
    require_input "请输入 ${label}warp ipv6: " "$2" "${label}warp ipv6 不能为空" || return 1
    require_input "请输入 ${label}warp private key: " "$3" "${label}warp private key 不能为空" || return 1
    require_input "请输入 ${label}warp reserved: " "$4" "${label}warp reserved 不能为空" || return 1
}
ensure_password() {
    [[ -n "${pswd}" ]] && return 0
    require_input "请输入 $1 密码: " pswd "$1 密码不能为空"
}

normalize_github_proxy() {
    local proxy="${1:-}"
    proxy="${proxy#"${proxy%%[![:space:]]*}"}"
    proxy="${proxy%"${proxy##*[![:space:]]}"}"
    [[ -z "${proxy}" ]] && return 0
    if [[ "${proxy}" != http://* && "${proxy}" != https://* ]]; then
        proxy="https://${proxy}"
    fi
    [[ "${proxy}" != */ ]] && proxy="${proxy}/"
    printf '%s' "${proxy}"
}

github_url() {
    printf '%s%s' "${GITHUB_PROXY}" "$1"
}

format_bytes() {
    awk -v b="${1:-0}" 'BEGIN {
        if (b >= 1073741824) printf "%.2f GB", b/1073741824
        else if (b >= 1048576) printf "%.2f MB", b/1048576
        else if (b >= 1024) printf "%.2f KB", b/1024
        else printf "%.0f B", b
    }'
}

parse_github_proxy_args() {
    local proxy="${GITHUB_PROXY:-}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--proxy)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    LOGE "参数 $1 需要代理地址, 例如: -p https://proxy.com"
                    exit 1
                fi
                proxy="$2"
                shift 2
                ;;
            -p=*|--proxy=*)
                proxy="${1#*=}"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    GITHUB_PROXY="$(normalize_github_proxy "${proxy}")"
}

curl_ua() {
    curl -A "Linux_tool" "$@"
}

# 检查是否为 root 用户
[[ $EUID -ne 0 ]] && LOGE "请使用 root 用户运行该脚本" && exit 1

# 系统检查
os_check() {
    LOGI "检测当前系统中..."
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif grep -Eqi "debian" /etc/issue /proc/version 2>/dev/null; then
        OS="debian"
    elif grep -Eqi "ubuntu" /etc/issue /proc/version 2>/dev/null; then
        OS="ubuntu"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue /proc/version 2>/dev/null; then
        OS="centos"
    else
        LOGE "系统检测错误,当前系统不支持!" && exit 1
    fi
    LOGI "系统检测完毕,当前系统为:${OS}"
}

# 架构检查
arch_check() {
    ARCH=$(arch)
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
    command -v tar >/dev/null 2>&1 && return 0
    case "${OS}" in
        ubuntu|debian) apt install tar -y ;;
        centos) yum install tar -y ;;
    esac
}

# 从 URL / HTML 中提取 releases/tag/vX.Y.Z
_extract_release_tag() {
    sed -n 's#.*releases/tag/\(v[^/"[:space:]#]*\).*#\1#p' | head -n1
}

_fetch_tag_from_github_latest() {
    local tag
    tag=$(curl_ua -sSL -m 15 -D - "$1" 2>/dev/null | tr -d '\r' | _extract_release_tag)
    [[ -n "${tag}" ]] && { printf '%s' "${tag}"; return 0; }
    return 1
}

_fetch_tag_from_github_api() {
    local tag
    tag=$(curl_ua -sSL -m 10 -H "Accept: application/vnd.github+json" "$1" 2>/dev/null | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)
    [[ -n "${tag}" ]] && { printf '%s' "${tag}"; return 0; }
    return 1
}

# 在当前 shell 填充 _CACHED_LATEST_TAG. 禁止放进 $(), 否则缓存会丢.
ensure_latest_version() {
    if [[ -n "${_VERSION_FETCH_DONE}" ]]; then
        [[ -n "${_CACHED_LATEST_TAG}" ]]
        return
    fi
    _VERSION_FETCH_DONE=1
    local url urls=()
    urls+=("$(github_url "https://github.com/SagerNet/sing-box/releases/latest")")
    urls+=("$(github_url "https://api.github.com/repos/SagerNet/sing-box/releases/latest")")
    if [[ -n "${GITHUB_PROXY}" ]]; then
        urls+=("https://github.com/SagerNet/sing-box/releases/latest")
        urls+=("https://api.github.com/repos/SagerNet/sing-box/releases/latest")
    fi
    for url in "${urls[@]}"; do
        if [[ "${url}" == *"/api.github.com/"* ]]; then
            _CACHED_LATEST_TAG=$(_fetch_tag_from_github_api "${url}") && return 0
        else
            _CACHED_LATEST_TAG=$(_fetch_tag_from_github_latest "${url}") && return 0
        fi
    done
    return 1
}

clear_version_cache() {
    unset _CACHED_LATEST_TAG _VERSION_FETCH_DONE
}

get_installed_version() {
    [[ -f "${SING_BOX_BINARY}" ]] || return 1
    "${SING_BOX_BINARY}" version | awk 'NR==1 {print $3}'
}

print_latest_version() {
    if [[ -n "$1" ]]; then
        echo_info "最新版本" "$1"
    else
        echo_info "最新版本" "获取失败" "${yellow}"
    fi
}

# sing-box 状态检查
sing_box_status_check() {
    if [[ ! -f "${SING_BOX_SERVICE}" ]]; then
        return ${SING_BOX_STATUS_NOT_INSTALL}
    fi
    if [[ "$(systemctl is-active sing-box)" == "active" ]]; then
        return ${SING_BOX_STATUS_RUNNING}
    fi
    return ${SING_BOX_STATUS_NOT_RUNNING}
}

# 显示 sing-box 状态
show_sing_box_status() {
    sing_box_status_check
    local status=$?
    local version="" version_info="" latest_version=""

    if [[ ${status} != ${SING_BOX_STATUS_NOT_INSTALL} ]]; then
        version_info=$(${SING_BOX_BINARY} version 2>/dev/null)
        version=$(printf '%s\n' "${version_info}" | awk 'NR==1 {print $3}')
    fi
    ensure_latest_version
    latest_version="${_CACHED_LATEST_TAG#v}"

    case ${status} in
        0)
            echo_info "sing-box 状态" "未运行" "${yellow}"
            if [[ -n "${version}" ]]; then
                echo_info "sing-box 版本" "${version}"
                print_latest_version "${latest_version}"
            fi
            show_sing_box_enable_status
            ;;
        1)
            echo_info "sing-box 状态" "已运行"
            if [[ -n "${version}" ]]; then
                echo_info "sing-box 版本" "${version}"
                print_latest_version "${latest_version}"
                if [[ -n "${latest_version}" && "${version}" != "${latest_version}" ]]; then
                    echo_info "发现新版本" "建议更新" "${yellow}"
                fi
                echo_info "环境信息" "$(printf '%s\n' "${version_info}" | awk '/Environment:/{print $2" "$3}')"
                echo_info "包含功能" "$(printf '%s\n' "${version_info}" | awk -F': ' '/Tags:/{print $2}')"
            fi
            if [[ -f "${SING_BOX_CONFIG_PATH}/install.info" ]]; then
                source "${SING_BOX_CONFIG_PATH}/install.info"
                echo_info "版本类型" "${SING_BOX_VERSION_TYPE}"
                echo_info "配置类型" "${SING_BOX_CONFIG_TYPE}"
            fi
            show_sing_box_enable_status
            show_sing_box_running_status
            ;;
        255)
            echo_info "sing-box 状态" "未安装" "${red}"
            print_latest_version "${latest_version}"
            ;;
    esac
}

show_sing_box_running_status() {
    local sing_box_runTime
    sing_box_runTime=$(systemctl show -p ActiveEnterTimestamp --value sing-box)
    LOGI "sing-box 运行时长：${sing_box_runTime}"
}

show_sing_box_enable_status() {
    if [[ "$(systemctl is-enabled sing-box)" == "enabled" ]]; then
        echo_info "sing-box 是否开机自启" "是"
    else
        echo_info "sing-box 是否开机自启" "否" "${red}"
    fi
}

# 下载 sing-box 二进制文件
install_sing_box_binary() {
    local version=$1
    local name=$2
    local temp_dir download_link new_binary_path curl_stats
    local size_download speed_download time_total

    if [[ -z "${version}" || -z "${name}" ]]; then
        LOGE "获取 sing-box 版本信息失败"
        return 1
    fi

    temp_dir=$(mktemp -d) || return 1
    new_binary_path="${SING_BOX_BINARY}.new"
    download_link="$(github_url "https://github.com/SagerNet/sing-box/releases/download/${version}/sing-box-${name}-linux-${ARCH}.tar.gz")"

    LOGD "开始下载 sing-box_${name}"
    LOGD "下载地址: ${download_link}"
    if ! curl_stats=$(curl_ua -fL --retry 3 --retry-delay 2 \
        -o "${temp_dir}/sing-box.tar.gz" \
        -w "%{size_download} %{speed_download} %{time_total}" \
        "${download_link}"); then
        rm -rf "${temp_dir}"
        LOGE "sing-box 下载失败"
        return 1
    fi
    read -r size_download speed_download time_total <<< "${curl_stats}"
    LOGI "下载完成: $(format_bytes "${size_download}"), 平均速度: $(format_bytes "${speed_download}")/s, 耗时: ${time_total}s"

    if ! tar -xzf "${temp_dir}/sing-box.tar.gz" -C "${temp_dir}" --strip-components=1; then
        rm -rf "${temp_dir}"
        LOGE "sing-box 解压失败"
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

# 安装 sing-box logrotate 配置
install_sing_box_logrotate() {
    LOGD "开始安装 sing-box logrotate 配置..."
    cat <<EOF >"${SING_BOX_LOGROTATE}"
${SING_BOX_LOG_PATH}/sing-box.log {
    daily
    size 10M
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    create 0644 root root
}
EOF
    LOGD "安装 sing-box logrotate 配置成功"
}

# 检测 IPv6 连通性
check_ipv6_support() {
    local ping_cmd="ping -6"
    command -v ping6 >/dev/null 2>&1 && ping_cmd="ping6"
    if ${ping_cmd} -c 1 -W 3 2001:4860:4860::8888 >/dev/null 2>&1; then
        LOGI "IPv6 连通正常"
        return 0
    fi
    LOGE "IPv6 无法连通"
    return 1
}

validate_sing_box_config() {
    if ! "${SING_BOX_BINARY}" check -c "${SING_BOX_CONFIG_PATH}/config.json"; then
        LOGE "sing-box 配置校验失败"
        return 1
    fi
}

check_he_ipv6_interface() {
    ip link show he-ipv6 >/dev/null 2>&1
}

# 配置 sing-box 配置
configuration_sing_box_config() {
    local config_backup=''
    local enable_warp=false
    local enable_ipv6_via_warp=false
    local enable_openai_rule=false
    local enable_openai_dns=false
    local enable_youtube_rule=false
    local enable_apple_rule=false
    local enable_perplexity_rule=false
    local enable_ss=false
    local enable_trojan=false
    local enable_mixed=false
    local enable_he_ipv6=false
    local enable_he_ss=false
    local enable_akile_dns=false
    local akile_dns_server=''
    local warpv6='' warpkey='' warpreserved=''
    local warpv4_he="${WARP_V4_ADDR}" warpv6_he='' warpkey_he='' warpreserved_he=''
    local sport='' tport='' mport='' muser='' pswd=''
    local he_sport=''
    local ipv6_support=1

    LOGD "开始配置 sing-box 配置文件..."

    if [[ -f "${SING_BOX_CONFIG_PATH}/config.json" ]]; then
        config_backup=$(mktemp) || return 1
        cp "${SING_BOX_CONFIG_PATH}/config.json" "${config_backup}" || return 1
    fi

    echo -e "\n${blue}=== 步骤 1/4: WARP 配置 ===${plain}"
    if confirm "是否启用 WARP"; then
        enable_warp=true
        SING_BOX_CONFIG_TYPE="warp"

        require_warp_creds "" warpv6 warpkey warpreserved || return 1

        echo -e "\n${blue}=== 步骤 2/4: WARP 策略配置 ===${plain}"
        check_ipv6_support
        ipv6_support=$?

        if [[ ${ipv6_support} == 0 ]]; then
            LOGI "检测到本机支持 IPv6"
        else
            LOGI "检测到本机不支持 IPv6"
            confirm "是否开启 IPv6 访问全局走 WARP" && enable_ipv6_via_warp=true
        fi

        if confirm "是否启用 OpenAI 规则 (走 WARP IPv6)"; then
            enable_openai_rule=true
            confirm "是否启用 OpenAI DNS (使用 Quad9 解析)" && enable_openai_dns=true
        fi

        confirm "是否启用 Apple 特殊规则 (走 WARP)" && enable_apple_rule=true
        confirm "是否启用 Perplexity 规则 (走 WARP IPv6)" && enable_perplexity_rule=true
    else
        SING_BOX_CONFIG_TYPE="nowarp"
        echo -e "${yellow}未启用 WARP，跳过策略配置${plain}"
    fi

    echo -e "\n${blue}=== DNS 配置 ===${plain}"
    if confirm "是否启用 Akile DNS"; then
        enable_akile_dns=true
        require_input "请输入 Akile DNS server: " akile_dns_server "Akile DNS server 不能为空" || return 1
        confirm "是否启用 YouTube 规则 (使用 Akile DNS 解析)" && enable_youtube_rule=true
    fi

    echo -e "\n${blue}=== 步骤 3/4: Inbounds 配置 ===${plain}"

    if confirm "是否配置 Mixed (SOCKS/HTTP)"; then
        enable_mixed=true
        require_input "请输入 Mixed 端口: " mport "Mixed 端口不能为空" || return 1
        require_input "请输入 Mixed 用户名: " muser "Mixed 用户名不能为空" || return 1
        require_input "请输入 Mixed 密码: " pswd "Mixed 密码不能为空" || return 1
    fi

    if confirm "是否配置 Shadowsocks"; then
        enable_ss=true
        require_input "请输入 Shadowsocks 端口: " sport "Shadowsocks 端口不能为空" || return 1
        ensure_password "Shadowsocks" || return 1
    fi

    if confirm "是否配置 Trojan"; then
        enable_trojan=true
        require_input "请输入 Trojan 端口: " tport "Trojan 端口不能为空" || return 1
        ensure_password "Trojan" || return 1
    fi

    echo -e "\n${blue}=== 步骤 4/4: HE IPv6 配置 ===${plain}"
    if check_he_ipv6_interface; then
        LOGI "检测到 he-ipv6 隧道接口"
    else
        echo -e "${yellow}未检测到 he-ipv6 隧道接口${plain}"
    fi

    if confirm "是否启用 HE IPv6 配置"; then
        enable_he_ipv6=true
        require_warp_creds "HE " warpv6_he warpkey_he warpreserved_he || return 1

        if confirm "是否配置 HE Shadowsocks"; then
            enable_he_ss=true
            require_input "请输入 HE Shadowsocks 端口: " he_sport "HE Shadowsocks 端口不能为空" || return 1
            ensure_password "HE Shadowsocks" || return 1
        fi
    fi

    if [[ "${enable_ss}" == false && "${enable_trojan}" == false && "${enable_mixed}" == false && "${enable_he_ss}" == false ]]; then
        LOGE "至少需要配置一个 Inbound (Mixed、Shadowsocks、Trojan 或 HE Shadowsocks)"
        return 1
    fi

    generate_dynamic_config

    if ! validate_sing_box_config; then
        if [[ -n "${config_backup}" ]]; then
            mv -f "${config_backup}" "${SING_BOX_CONFIG_PATH}/config.json"
        else
            rm -f "${SING_BOX_CONFIG_PATH}/config.json"
        fi
        return 1
    fi

    rm -f "${config_backup}"

    cat > "${SING_BOX_CONFIG_PATH}/install.info" <<EOF
SING_BOX_VERSION_TYPE=${SING_BOX_VERSION_TYPE}
SING_BOX_CONFIG_TYPE=${SING_BOX_CONFIG_TYPE}
IPV6_SUPPORT=$([ ${ipv6_support} == 0 ] && echo "yes" || echo "no")
ENABLE_WARP=${enable_warp}
ENABLE_IPV6_VIA_WARP=${enable_ipv6_via_warp}
ENABLE_OPENAI_RULE=${enable_openai_rule}
ENABLE_OPENAI_DNS=${enable_openai_dns}
ENABLE_YOUTUBE_RULE=${enable_youtube_rule}
ENABLE_APPLE_RULE=${enable_apple_rule}
ENABLE_PERPLEXITY_RULE=${enable_perplexity_rule}
ENABLE_SS=${enable_ss}
ENABLE_TROJAN=${enable_trojan}
ENABLE_MIXED=${enable_mixed}
ENABLE_HE_IPV6=${enable_he_ipv6}
ENABLE_HE_SS=${enable_he_ss}
ENABLE_AKILE_DNS=${enable_akile_dns}
AKILE_DNS_SERVER=${akile_dns_server}
EOF

    LOGI "sing-box 配置文件完成"
}

json_join() {
    local first=1 item
    for item in "$@"; do
        [[ -z "${item}" ]] && continue
        if (( first )); then
            first=0
        else
            printf ',\n'
        fi
        printf '%s' "${item}"
    done
}

json_quote_list() {
    local first=1 x
    for x in "$@"; do
        (( first )) || printf ','
        first=0
        printf '"%s"' "${x}"
    done
}

_json_udp_dns() {
    cat <<EOF
            {
                "type": "udp",
                "tag": "$1",
                "server": "$2",
                "server_port": 53
            }
EOF
}

_json_wg_endpoint() {
    local tag="$1" name="$2" addr4="$3" addr6="$4" key="$5" listen="$6" peer="$7" reserved="$8" bind="${9:-}"
    local bind_json=""
    [[ -n "${bind}" ]] && bind_json=",
            \"bind_interface\": \"${bind}\""
    cat <<EOF
        {
            "type": "wireguard",
            "tag": "${tag}",
            "system": false,
            "name": "${name}",
            "mtu": 1280,
            "address": [
                "${addr4}",
                "${addr6}"
            ],
            "private_key": "${key}",
            "listen_port": ${listen},
            "peers": [
                {
                    "address": "${peer}",
                    "port": 2408,
                    "public_key": "${WARP_PUBLIC_KEY}",
                    "allowed_ips": [
                        "0.0.0.0/0",
                        "::/0"
                    ],
                    "persistent_keepalive_interval": 30,
                    "reserved": [${reserved}]
                }
            ]${bind_json}
        }
EOF
}

_json_ss_inbound() {
    cat <<EOF
        {
            "type": "shadowsocks",
            "tag": "$1",
            "listen": "::",
            "listen_port": $2,
            "tcp_fast_open": true,
            "method": "aes-128-gcm",
            "password": "$3"
        }
EOF
}

_json_remote_ruleset() {
    cat <<EOF
            {
                "tag": "$1",
                "type": "remote",
                "format": "binary",
                "url": "${GEOSITE_RULESET_BASE}/geosite-$1.srs",
                "update_interval": "1d"
            }
EOF
}

# 动态生成配置文件
generate_dynamic_config() {
    local config_json="${SING_BOX_CONFIG_PATH}/config.json"
    local inbound_tags=() youtube_inbound_tags=() tag
    local dns_servers=() dns_rules=() endpoints=() inbounds=() outbounds=() route_rules=() rule_sets=()
    local he_dns_server="cloudflare"
    local endpoints_block=""

    [[ "${enable_openai_dns}" == true ]] && he_dns_server="quad9"

    dns_servers+=("$(_json_udp_dns cloudflare 1.1.1.1)")
    dns_servers+=("$(_json_udp_dns quad9 9.9.9.9)")
    [[ "${enable_akile_dns}" == true ]] && dns_servers+=("$(_json_udp_dns akile "${akile_dns_server}")")

    if [[ "${enable_he_ss}" == true ]]; then
        dns_rules+=("$(cat <<EOF
            {
                "inbound": "he-in",
                "action": "route",
                "server": "${he_dns_server}"
            }
EOF
)")
    fi
    if [[ "${enable_youtube_rule}" == true ]]; then
        dns_rules+=("$(cat <<'EOF'
            {
                "rule_set": "youtube",
                "action": "route",
                "server": "akile"
            }
EOF
)")
    fi
    if [[ "${enable_openai_dns}" == true ]]; then
        dns_rules+=("$(cat <<'EOF'
            {
                "rule_set": "openai",
                "action": "route",
                "server": "quad9"
            }
EOF
)")
    fi

    if [[ "${enable_warp}" == true ]]; then
        endpoints+=("$(_json_wg_endpoint wg-ep wg0 "${WARP_V4_ADDR}" "${warpv6}" "${warpkey}" 2408 engage.cloudflareclient.com "${warpreserved}")")
    fi
    if [[ "${enable_he_ipv6}" == true ]]; then
        endpoints+=("$(_json_wg_endpoint wg-ep-he wg1 "${warpv4_he}" "${warpv6_he}" "${warpkey_he}" 2409 2606:4700:d0::a29f:c001 "${warpreserved_he}" he-ipv6)")
    fi

    if [[ "${enable_mixed}" == true ]]; then
        inbound_tags+=("mixed-in")
        inbounds+=("$(cat <<EOF
        {
            "type": "mixed",
            "tag": "mixed-in",
            "listen": "::",
            "listen_port": ${mport},
            "users": [
                {
                    "username": "${muser}",
                    "password": "${pswd}"
                }
            ]
        }
EOF
)")
    fi
    if [[ "${enable_ss}" == true ]]; then
        inbound_tags+=("ss-in")
        inbounds+=("$(_json_ss_inbound ss-in "${sport}" "${pswd}")")
    fi
    if [[ "${enable_trojan}" == true ]]; then
        inbound_tags+=("trojan-in")
        inbounds+=("$(cat <<EOF
        {
            "type": "trojan",
            "tag": "trojan-in",
            "listen": "::",
            "listen_port": ${tport},
            "users": [
                {
                    "name": "trojan",
                    "password": "${pswd}"
                }
            ],
            "transport": {
                "type": "ws",
                "path": "/media-cdn",
                "max_early_data": 2048,
                "early_data_header_name": "Sec-WebSocket-Protocol"
            }
        }
EOF
)")
    fi
    if [[ "${enable_he_ss}" == true ]]; then
        inbound_tags+=("he-in")
        inbounds+=("$(_json_ss_inbound he-in "${he_sport}" "${pswd}")")
    fi

    outbounds+=("$(cat <<'EOF'
        {
            "type": "direct",
            "tag": "direct"
        }
EOF
)")
    if [[ "${enable_he_ipv6}" == true ]]; then
        outbounds+=("$(cat <<'EOF'
        {
            "type": "direct",
            "tag": "he-ipv6",
            "bind_interface": "he-ipv6"
        }
EOF
)")
    fi

    route_rules+=("$(cat <<EOF
            {
                "inbound": [$(json_quote_list "${inbound_tags[@]}")],
                "action": "sniff",
                "timeout": "1s"
            }
EOF
)")

    if [[ "${enable_he_ss}" == true ]]; then
        route_rules+=("$(cat <<EOF
            {
                "inbound": ["he-in"],
                "action": "resolve",
                "server": "${he_dns_server}"
            }
EOF
)")
        route_rules+=("$(cat <<'EOF'
            {
                "inbound": ["he-in"],
                "action": "route",
                "outbound": "wg-ep-he"
            }
EOF
)")
    fi

    if [[ "${enable_youtube_rule}" == true ]]; then
        for tag in "${inbound_tags[@]}"; do
            [[ "${tag}" != "he-in" ]] && youtube_inbound_tags+=("${tag}")
        done
        if [[ ${#youtube_inbound_tags[@]} -gt 0 ]]; then
            route_rules+=("$(cat <<EOF
            {
                "inbound": [$(json_quote_list "${youtube_inbound_tags[@]}")],
                "rule_set": "youtube",
                "action": "resolve",
                "server": "akile"
            }
EOF
)")
        fi
    fi

    if [[ "${enable_warp}" == true ]]; then
        route_rules+=("$(cat <<'EOF'
            {
                "domain": ["cfv4.sfun.ip-ddns.com", "cfv6.sfun.ip-ddns.com"],
                "action": "route",
                "outbound": "wg-ep"
            }
EOF
)")
    fi

    if [[ "${enable_he_ipv6}" == true ]]; then
        route_rules+=("$(cat <<'EOF'
            {
                "domain": ["he-cfv4.sfun.ip-ddns.com", "he-cfv6.sfun.ip-ddns.com"],
                "action": "route",
                "outbound": "wg-ep-he"
            }
EOF
)")
        route_rules+=("$(cat <<'EOF'
            {
                "domain": "hev6.sfun.ip-ddns.com",
                "action": "route",
                "outbound": "he-ipv6"
            }
EOF
)")
    fi

    if [[ "${enable_warp}" == true ]]; then
        if [[ "${enable_openai_rule}" == true ]]; then
            route_rules+=("$(cat <<'EOF'
            {
                "rule_set": "openai",
                "action": "resolve",
                "strategy": "prefer_ipv6"
            }
EOF
)")
        fi
        if [[ "${enable_perplexity_rule}" == true ]]; then
            route_rules+=("$(cat <<'EOF'
            {
                "domain_suffix": "perplexity.ai",
                "action": "resolve",
                "strategy": "prefer_ipv6"
            }
EOF
)")
        fi
    fi
    route_rules+=("$(cat <<'EOF'
            {
                "domain_suffix": "oyunfor.com",
                "action": "resolve",
                "strategy": "ipv4_only"
            }
EOF
)")
    if [[ "${enable_warp}" == true ]]; then
        if [[ "${enable_apple_rule}" == true ]]; then
            route_rules+=("$(cat <<'EOF'
            {
                "domain": [
                    "speedysub.itunes.apple.com",
                    "fpinit.itunes.apple.com",
                    "entitlements.itunes.apple.com"
                ],
                "action": "route",
                "outbound": "wg-ep"
            }
EOF
)")
        fi
        if [[ "${enable_perplexity_rule}" == true ]]; then
            route_rules+=("$(cat <<'EOF'
            {
                "domain_suffix": "perplexity.ai",
                "action": "route",
                "outbound": "wg-ep"
            }
EOF
)")
        fi
        route_rules+=("$(cat <<'EOF'
            {
                "ip_cidr": ["1.1.1.1/32"],
                "action": "route",
                "outbound": "wg-ep"
            }
EOF
)")
        if [[ "${enable_openai_rule}" == true ]]; then
            route_rules+=("$(cat <<'EOF'
            {
                "rule_set": "openai",
                "action": "route",
                "outbound": "wg-ep"
            }
EOF
)")
        fi
        if [[ "${enable_ipv6_via_warp}" == true ]]; then
            route_rules+=("$(cat <<'EOF'
            {
                "domain_keyword": ["ipv6"],
                "action": "route",
                "outbound": "wg-ep"
            }
EOF
)")
            route_rules+=("$(cat <<'EOF'
            {
                "ip_version": 6,
                "action": "route",
                "outbound": "wg-ep"
            }
EOF
)")
        fi
    fi

    if [[ "${enable_warp}" == true && "${enable_openai_rule}" == true ]]; then
        rule_sets+=("$(_json_remote_ruleset openai)")
    fi
    if [[ "${enable_youtube_rule}" == true ]]; then
        rule_sets+=("$(_json_remote_ruleset youtube)")
    fi

    if [[ ${#endpoints[@]} -gt 0 ]]; then
        endpoints_block="    \"endpoints\": [
$(json_join "${endpoints[@]}")
    ],
"
    fi

    cat > "${config_json}" <<EOF
{
    "log": {
        "disabled": false,
        "level": "info",
        "output": "${SING_BOX_LOG_PATH}/sing-box.log",
        "timestamp": true
    },
    "dns": {
        "servers": [
$(json_join "${dns_servers[@]}")
        ],
        "rules": [
$(json_join "${dns_rules[@]}")
        ],
        "final": "cloudflare"
    },
    "http_clients": [
        {
            "tag": "direct-http",
            "detour": "direct"
        }
    ],
${endpoints_block}    "inbounds": [
$(json_join "${inbounds[@]}")
    ],
    "outbounds": [
$(json_join "${outbounds[@]}")
    ],
    "route": {
        "default_domain_resolver": {
            "server": "cloudflare"
        },
        "default_http_client": "direct-http",
        "rules": [
$(json_join "${route_rules[@]}")
        ],
        "rule_set": [
$(json_join "${rule_sets[@]}")
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

# 安装 sing-box
install_sing_box() {
    local latest_version latest_name

    LOGD "开始安装 sing-box"
    if [[ -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统已安装 sing-box,请使用更新命令"
        return 1
    fi

    os_check || return 1
    arch_check || return 1
    install_base || return 1

    mkdir -p "${SING_BOX_CONFIG_PATH}" "${SING_BOX_LOG_PATH}" "${SING_BOX_LIB_PATH}" || return 1

    clear_version_cache
    if ! ensure_latest_version; then
        LOGE "获取 sing-box 最新版本失败"
        return 1
    fi
    latest_version="${_CACHED_LATEST_TAG}"
    latest_name="${_CACHED_LATEST_TAG#v}"

    install_sing_box_binary "${latest_version}" "${latest_name}" || return 1
    install_sing_box_systemd_service || return 1
    install_sing_box_logrotate || return 1
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
    local current_version latest_version latest_name

    LOGD "开始更新 sing-box..."
    if [[ ! -f "${SING_BOX_SERVICE}" ]]; then
        LOGE "当前系统未安装 sing-box, 更新失败"
        return 1
    fi

    current_version=$(get_installed_version)
    LOGD "当前版本: ${current_version}"

    if [[ ! -f "${SING_BOX_CONFIG_PATH}/install.info" ]]; then
        LOGI "未找到安装信息文件,默认使用stable版本"
        echo "SING_BOX_VERSION_TYPE=${SING_BOX_VERSION_TYPE}" > "${SING_BOX_CONFIG_PATH}/install.info"
    else
        source "${SING_BOX_CONFIG_PATH}/install.info"
    fi

    if ! ensure_latest_version; then
        LOGE "获取 sing-box 最新版本失败"
        return 1
    fi
    latest_version="${_CACHED_LATEST_TAG}"
    latest_name="${_CACHED_LATEST_TAG#v}"

    if [[ "${current_version}" == "${latest_name}" ]]; then
        LOGI "当前已是最新版本,无需更新"
        return 0
    fi

    LOGD "最新版本: ${latest_version}"
    LOGD "版本类型: ${SING_BOX_VERSION_TYPE}"

    if ! confirm "确认更新到最新版本?"; then
        LOGI "取消更新"
        return 0
    fi

    os_check || return 1
    arch_check || return 1

    install_sing_box_binary "${latest_version}" "${latest_name}" || return 1

    if systemctl is-active --quiet sing-box; then
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
    rm -f "${SING_BOX_SERVICE}" "${SING_BOX_LOGROTATE}" "${SING_BOX_BINARY}"
    systemctl daemon-reload || return 1
    rm -rf "${SING_BOX_CONFIG_PATH}" "${SING_BOX_LOG_PATH}" "${SING_BOX_LIB_PATH}"
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
            0) exit 0 ;;
            1) install_sing_box ;;
            2) update_sing_box ;;
            3) systemctl restart sing-box ;;
            4) configuration_sing_box_config && reload_sing_box_config ;;
            5) nano "${SING_BOX_CONFIG_PATH}/config.json" ;;
            6) systemctl status sing-box ;;
            7) journalctl -u sing-box.service -n 50 --no-pager ;;
            8) uninstall_sing_box ;;
            *) LOGE "请输入正确的选项 [0-8]" ;;
        esac
    done
}

main() {
    parse_github_proxy_args "$@"
    if [[ -n "${GITHUB_PROXY}" ]]; then
        LOGI "已启用 GitHub 加速: ${GITHUB_PROXY}"
    fi
    show_menu
}
main "$@"
