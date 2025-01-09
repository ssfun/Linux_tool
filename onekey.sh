#!/bin/bash

#####################################################
# ssfun's Linux Onekey Tool
# Author: ssfun
# Date: 2025-01-08
# Version: 1.0.0
#####################################################

#Basic definitions
plain='\033[0m'
red='\033[0;31m'
blue='\033[1;34m'
pink='\033[1;35m'
green='\033[0;32m'
yellow='\033[0;33m'

#show menu
show_menu() {
    echo -e "
  ${green}ssfun's Linux Onekey Tool${plain}
  ————————————————
  ${green}Q.${plain} 退出脚本
  ————————————————
  ${green}1.${plain} 管理 sing-box
  ${green}2.${plain} 管理 frps
  ${green}3.${plain} 管理 webdav
  ${green}4.${plain} 管理 qBittorrent
  ${green}5.${plain} 管理 Plexmedia
 "
    echo && read -p "请输入选择[0-5]:" num

    case "${num}" in
    Q)
        exit 0
        ;;
    1)
        bash <(curl -sL https://raw.githubusercontent.com/ssfun/Linux_tool/main/sing-box/sing-box.sh)
        ;;
    2)
        bash <(curl -sL https://raw.githubusercontent.com/ssfun/Linux_tool/main/frps/frps.sh)
        ;;
    3)
        bash <(curl -sL https://raw.githubusercontent.com/ssfun/Linux_tool/main/webdav/webdav.sh)
        ;;
    4)
        bash <(curl -sL https://raw.githubusercontent.com/ssfun/Linux_tool/main/qbittorrent/qbittorrent.sh)
        ;;
    5)
        bash <(curl -sL https://raw.githubusercontent.com/ssfun/Linux_tool/main/plexmedia/plexmedia.sh)
        ;;
    *)
        LOGE "请输入正确的选项 [0-5]"
        ;;
    esac
}

main(){
    show_menu
}

main
