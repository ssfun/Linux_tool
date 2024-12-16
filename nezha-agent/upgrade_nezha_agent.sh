#!/bin/sh

NZ_BASE_PATH="/opt/nezha"
NZ_AGENT_PATH="${NZ_BASE_PATH}/agent"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

err() {
    printf "${red}%s${plain}\n" "$*" >&2
}

success() {
    printf "${green}%s${plain}\n" "$*"
}

info() {
    printf "${yellow}%s${plain}\n" "$*"
}

sudo() {
    myEUID=$(id -ru)
    if [ "$myEUID" -ne 0 ]; then
        if command -v sudo > /dev/null 2>&1; then
            command sudo "$@"
        else
            err "ERROR: sudo is not installed on the system, the action cannot be proceeded."
            exit 1
        fi
    else
        "$@"
    fi
}

deps_check() {
    deps="wget unzip grep"
    for dep in $deps; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            err "$dep not found, please install it first."
            exit 1
        fi
    done
}

env_check() {
    mach=$(uname -m)
    case "$mach" in
        amd64|x86_64) os_arch="amd64" ;;
        i386|i686) os_arch="386" ;;
        aarch64|arm64) os_arch="arm64" ;;
        *arm*) os_arch="arm" ;;
        s390x) os_arch="s390x" ;;
        riscv64) os_arch="riscv64" ;;
        mips) os_arch="mips" ;;
        mipsel|mipsle) os_arch="mipsle" ;;
        *) err "Unknown architecture: $mach"; exit 1 ;;
    esac

    system=$(uname)
    case "$system" in
        *Linux*) os="linux" ;;
        *Darwin*) os="darwin" ;;
        *FreeBSD*) os="freebsd" ;;
        *) err "Unknown OS: $system"; exit 1 ;;
    esac
}

check_nezha_agent() {
    if [ ! -d "$NZ_AGENT_PATH" ]; then
        err "nezha-agent is not installed."
        exit 1
    fi
}

download_latest_agent() {
    # 默认 PPOXY_URL 为空，如果环境变量中设置了 PPOXY_URL，则使用传入的值
    PPOXY_URL="${PPOXY_URL:-}"
    NZ_AGENT_URL="${PPOXY_URL}https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_${os}_${os_arch}.zip"

    _cmd="wget -t 2 -T 60 -O /tmp/nezha-agent_${os}_${os_arch}.zip $NZ_AGENT_URL >/dev/null 2>&1"
    if ! eval "$_cmd"; then
        err "Download nezha-agent release failed, check your network connectivity"
        exit 1
    fi
}

upgrade_nezha_agent() {
    sudo unzip -qo /tmp/nezha-agent_${os}_${os_arch}.zip -d $NZ_AGENT_PATH &&
        sudo rm -rf /tmp/nezha-agent_${os}_${os_arch}.zip

    success "nezha-agent successfully upgraded"
}

restart_nezha_agent() {
    sudo "$NZ_AGENT_PATH/nezha-agent" service restart
    success "nezha-agent service restarted"
}

show_version() {
    if [ -f "$NZ_AGENT_PATH/nezha-agent" ]; then
        version=$(sudo "$NZ_AGENT_PATH/nezha-agent" --version 2>&1)
        if [ $? -eq 0 ]; then
            success "Current nezha-agent version: ${version}"
        else
            err "Failed to retrieve nezha-agent version."
        fi
    else
        err "nezha-agent binary not found in $NZ_AGENT_PATH."
    fi
}

main() {
    deps_check
    env_check
    check_nezha_agent
    download_latest_agent
    upgrade_nezha_agent
    restart_nezha_agent
    show_version
}

main
