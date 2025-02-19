#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: Snell Server 管理脚本
#=================================================

Snell_Ver="4.1.1"
filepath=$(cd "$(dirname "$0")"; pwd)
file_1=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
FOLDER="/usr/local/etc/snell/"
FILE="/usr/local/bin/snell-server"
CONF="/usr/local/etc/snell/config.conf"
Now_ver_File="/usr/local/etc/snell/ver.txt"
Local="/etc/sysctl.d/local.conf"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m" && Yellow_font_prefix="\033[0;33m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Yellow_font_prefix}[注意]${Font_color_suffix}"

checkRoot(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}

checkSys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
}

InstallationDependency(){
	if [[ ${release} == "centos" ]]; then
		yum update
		yum install gzip wget curl unzip jq -y
	else
		apt-get update
		apt-get install gzip wget curl unzip jq -y
	fi
	sysctl -w net.core.rmem_max=26214400
	sysctl -w net.core.rmem_default=26214400
	\cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

sysArch() {
    uname=$(uname -m)
    if [[ "$uname" == "i686" ]] || [[ "$uname" == "i386" ]]; then
        arch="i386"
    elif [[ "$uname" == *"armv7"* ]] || [[ "$uname" == "armv6l" ]]; then
        arch="armv7l"
    elif [[ "$uname" == *"armv8"* ]] || [[ "$uname" == "aarch64" ]]; then
        arch="aarch64"
    else
        arch="amd64"
    fi    
}

enableSystfo() {
	kernel=$(uname -r | awk -F . '{print $1}')
	if [ "$kernel" -ge 3 ]; then
		echo 3 >/proc/sys/net/ipv4/tcp_fastopen
		[[ ! -e $Local ]] && echo "fs.file-max = 51200
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.netdev_max_backlog = 4096
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_ecn=1
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control = bbr" >>/etc/sysctl.d/local.conf && sysctl --system >/dev/null 2>&1
	else
		echo -e "$Error系统内核版本过低，无法支持 TCP Fast Open ！"
	fi
}

checkInstalledStatus(){
	[[ ! -e ${FILE} ]] && echo -e "${Error} Snell Server 没有安装，请检查！" && exit 1
}

checkStatus(){
	status=`systemctl status snell-server | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1`
}

getSnellv4Url(){
	sysArch
	snell_v4_url="https://dl.nssurge.com/snell/snell-server-v${Snell_Ver}-linux-${arch}.zip"
}

getVer(){
	getSnellv4Url
	filename=$(basename "${snell_v4_url}")
	if [[ $filename =~ v([0-9]+\.[0-9]+\.[0-9]+(rc[0-9]*|b[0-9]*)?) ]]; then
    new_ver=${BASH_REMATCH[1]}
    echo -e "${Info} 检测到 Snell 最新版本为 [ ${new_ver} ]"
		else
    echo -e "${Error} Snell Server 最新版本获取失败！"
		fi
}

v4_download(){
	echo -e "${Info} 试图请求 ${Yellow_font_prefix}v4 官网源版${Font_color_suffix} Snell Server ……"
	getVer
	wget --no-check-certificate -N "${snell_v4_url}"
	if [[ ! -e "snell-server-v${new_ver}-linux-${arch}.zip" ]]; then
		echo -e "${Error} Snell Server ${Yellow_font_prefix}v4 官网源版${Font_color_suffix} 下载失败！"
		return 1 && exit 1
	else
		unzip -o "snell-server-v${new_ver}-linux-${arch}.zip"
	fi
	if [[ ! -e "snell-server" ]]; then
		echo -e "${Error} Snell Server ${Yellow_font_prefix}v4 官网源版${Font_color_suffix} 解压失败！"
		echo -e "${Error} Snell Server${Yellow_font_prefix}v4 官网源版${Font_color_suffix} 安装失败！"
		return 1 && exit 1
	else
		rm -rf "snell-server-v${new_ver}-linux-${arch}.zip"
		chmod +x snell-server
		mv -f snell-server "${FILE}"
		echo "v${new_ver}" > ${Now_ver_File}
		echo -e "${Info} Snell Server 主程序下载安装完毕！"
		return 0
	fi
}

Service(){
	echo '
[Unit]
Description= Snell Service
After=network-online.target
Wants=network-online.target systemd-networkd-wait-online.service
[Service]
LimitNOFILE=32767 
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStartPre=/bin/sh -c 'ulimit -n 51200'
ExecStart=/usr/local/bin/snell-server -c /usr/local/etc/snell/config.conf
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/snell-server.service
	systemctl enable --now snell-server
	echo -e "${Info} Snell Server 服务配置完成！"
}

writeConfig(){
	cat > ${CONF}<<-EOF
[snell-server]
listen = ::0:${port}
ipv6 = ${ipv6}
psk = ${psk}
tfo = ${tfo}
dns = ${dns}
EOF
}

readConfig(){
	[[ ! -e ${CONF} ]] && echo -e "${Error} Snell Server 配置文件不存在！" && exit 1
	ipv6=$(cat ${CONF}|grep 'ipv6 = '|awk -F 'ipv6 = ' '{print $NF}')
	port=$(grep -E '^listen\s*=' ${CONF} | awk -F ':' '{print $NF}' | xargs)
	psk=$(cat ${CONF}|grep 'psk = '|awk -F 'psk = ' '{print $NF}')
	tfo=$(cat ${CONF}|grep 'tfo = '|awk -F 'tfo = ' '{print $NF}')
	dns=$(cat ${CONF}|grep 'dns = '|awk -F 'dns = ' '{print $NF}')
}

setPort(){
	while true
		do
		echo -e "${Tip} 本步骤不涉及系统防火墙端口操作，请手动放行相应端口！"
		echo -e "请输入 Snell Server 端口${Yellow_font_prefix}[1-65535]${Font_color_suffix}"
		read -e -p "(默认: 2345):" port
		[[ -z "${port}" ]] && port="2345"
		echo $((${port}+0)) &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${port} -ge 1 ]] && [[ ${port} -le 65535 ]]; then
				echo && echo "=============================="
				echo -e "端口 : ${Red_background_prefix} ${port} ${Font_color_suffix}"
				echo "==============================" && echo
				break
			else
				echo "输入错误, 请输入正确的端口。"
			fi
		else
			echo "输入错误, 请输入正确的端口。"
		fi
		done
}

setIpv6(){
	echo -e "是否开启 IPv6 解析 ？
==================================
${Green_font_prefix} 1.${Font_color_suffix} 开启  ${Green_font_prefix} 2.${Font_color_suffix} 关闭
=================================="
	read -e -p "(默认：2.关闭)：" ipv6
	[[ -z "${ipv6}" ]] && ipv6="false"
	if [[ ${ipv6} == "1" ]]; then
		ipv6=true
	else
		ipv6=false
	fi
	echo && echo "=================================="
	echo -e "IPv6 解析 开启状态：${Red_background_prefix} ${ipv6} ${Font_color_suffix}"
	echo "==================================" && echo
}

setPSK(){
	echo "请输入 Snell Server 密钥 [0-9][a-z][A-Z] "
	read -e -p "(默认: 随机生成):" psk
	[[ -z "${psk}" ]] && psk=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16)
	echo && echo "=============================="
	echo -e "密钥 : ${Red_background_prefix} ${psk} ${Font_color_suffix}"
	echo "==============================" && echo
}

setTFO(){
	echo -e "是否开启 TCP Fast Open ？
==================================
${Green_font_prefix} 1.${Font_color_suffix} 开启  ${Green_font_prefix} 2.${Font_color_suffix} 关闭
=================================="
	read -e -p "(默认：1.开启)：" tfo
	[[ -z "${tfo}" ]] && tfo="1"
	if [[ ${tfo} == "1" ]]; then
		tfo=true
		enableSystfo
	else
		tfo=false
	fi
	echo && echo "=================================="
	echo -e "TCP Fast Open 开启状态：${Red_background_prefix} ${tfo} ${Font_color_suffix}"
	echo "==================================" && echo
}

setDNS(){
	echo -e "${Tip} 请输入正确格式的的 DNS，多条记录以英文逗号隔开，仅支持 v4.1.0b1 版本及以上。"
	read -e -p "(默认值：1.1.1.1, 8.8.8.8, 2001:4860:4860::8888)：" dns
	[[ -z "${dns}" ]] && dns="1.1.1.1, 8.8.8.8, 2001:4860:4860::8888"
	echo && echo "=================================="
	echo -e "当前 DNS 为：${Red_background_prefix} ${dns} ${Font_color_suffix}"
	echo "==================================" && echo
}

Install_v4(){
	checkRoot
	[[ -e ${FILE} ]] && echo -e "${Error} 检测到 Snell Server 已安装 ,请先卸载旧版再安装新版!" && exit 1
	echo -e "${Info} 开始设置 配置..."
	setPort
	setPSK
	setIpv6
	setTFO
	setDNS
	echo -e "${Info} 开始安装/配置 依赖..."
	InstallationDependency

	# 确保目录存在
	mkdir -p "${FOLDER}"
	if [[ ! -d "${FOLDER}" ]]; then
		echo -e "${Error} 无法创建目录 ${FOLDER}，请检查权限！"
		exit 1
	fi

	echo -e "${Info} 开始下载/安装..."
	v4_download
	echo -e "${Info} 开始安装 服务脚本..."
	Service
	echo -e "${Info} 开始写入 配置文件..."
	writeConfig
	echo -e "${Info} 所有步骤 安装完毕，开始启动..."
	Start
	echo -e "${Info} 启动完成，查看配置..."
    	View
}

Start(){
    checkInstalledStatus
    checkStatus
    if [[ "$status" == "running" ]]; then
        echo -e "${Info} Snell Server 已在运行！"
    else
        systemctl start snell-server
        checkStatus
        if [[ "$status" == "running" ]]; then
            echo -e "${Info} Snell Server 启动成功！"
        else
            echo -e "${Error} Snell Server 启动失败！"
            exit 1
        fi
    fi
    sleep 3s
}

Stop(){
	checkInstalledStatus
	checkStatus
	[[ !"$status" == "running" ]] && echo -e "${Error} Snell Server 没有运行，请检查！" && exit 1
	systemctl stop snell-server
	echo -e "${Info} Snell Server 停止成功！"
    sleep 3s
    startMenu
}

Restart(){
	checkInstalledStatus
	systemctl restart snell-server
	echo -e "${Info} Snell Server 重启完毕!"
	sleep 3s
    startMenu
}

Uninstall(){
	checkInstalledStatus
	echo "确定要卸载 Snell Server 并清除所有配置文件吗？ (y/N)"
	echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		systemctl stop snell-server
        systemctl disable snell-server
		echo -e "${Info} 移除主程序..."
		rm -rf "${FILE}"
		echo -e "${Info} 移除配置文件..."
		rm -rf "${FOLDER}"
		echo -e "${Info} 移除服务文件..."
		rm -f /etc/systemd/system/snell-server.service
		systemctl daemon-reload
		echo && echo "Snell Server 已彻底卸载！" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
    sleep 3s
    startMenu
}

getIpv4(){
	ipv4=$(wget -qO- -4 -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ipv4}" ]]; then
		ipv4=$(wget -qO- -4 -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ipv4}" ]]; then
			ipv4=$(wget -qO- -4 -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ipv4}" ]]; then
				ipv4="IPv4_Error"
			fi
		fi
	fi
}

getIpv6(){
	ip6=$(wget -qO- -6 -t1 -T2 ifconfig.co)
	if [[ -z "${ip6}" ]]; then
		ip6="IPv6_Error"
	fi
}

View(){
	checkInstalledStatus
	readConfig
	getIpv4
	getIpv6
	clear && echo
	echo -e "Snell Server 配置信息："
	echo -e "—————————————————————————"
	[[ "${ipv4}" != "IPv4_Error" ]] && echo -e " 地址\t: ${Green_font_prefix}${ipv4}${Font_color_suffix}"
	[[ "${ip6}" != "IPv6_Error" ]] && echo -e " 地址\t: ${Green_font_prefix}${ip6}${Font_color_suffix}"
	echo -e " 端口\t: ${Green_font_prefix}${port}${Font_color_suffix}"
	echo -e " 密钥\t: ${Green_font_prefix}${psk}${Font_color_suffix}"
	echo -e " IPv6\t: ${Green_font_prefix}${ipv6}${Font_color_suffix}"
	echo -e " TFO\t: ${Green_font_prefix}${tfo}${Font_color_suffix}"
	echo -e " DNS\t: ${Green_font_prefix}${dns}${Font_color_suffix}"
	echo -e "—————————————————————————"
	echo -e "${Info} Surge 配置："
	if [[ "${ipv4}" != "IPv4_Error" ]]; then
		echo -e "$(uname -n) = snell, ${ipv4}, ${port}, psk=${psk}, tfo=${tfo}, version=4, reuse=true, ecn=true"
	else
		echo -e "$(uname -n) = snell, ${ip6}, ${port}, psk=${psk}, tfo=${tfo}, version=4, reuse=true, ecn=true"
	fi
   	echo -e "—————————————————————————"
	beforeStartMenu
}

Status(){
	echo -e "${Info} 获取 Snell Server 活动日志 ……"
	echo -e "${Tip} 返回主菜单请按 q ！"
	systemctl status snell-server
	startMenu
}

beforeStartMenu() {
    echo && echo -n -e "${yellow}* 按回车返回主菜单 *${plain}" && read temp
    startMenu
}

startMenu(){
clear
checkRoot
checkSys
sysArch
action=$1
	echo && echo -e "  
==============================
Snell Server 管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
==============================
 ${Green_font_prefix} 1.${Font_color_suffix} 安装 Snell Server
 ${Green_font_prefix} 2.${Font_color_suffix} 卸载 Snell Server
——————————————————————————————
 ${Green_font_prefix} 3.${Font_color_suffix} 启动 Snell Server
 ${Green_font_prefix} 4.${Font_color_suffix} 停止 Snell Server
 ${Green_font_prefix} 5.${Font_color_suffix} 重启 Snell Server
——————————————————————————————
 ${Green_font_prefix} 6.${Font_color_suffix} 查看 配置信息
 ${Green_font_prefix} 7.${Font_color_suffix} 查看 运行状态
——————————————————————————————
 ${Green_font_prefix} 8.${Font_color_suffix} 退出脚本
==============================" && echo
	if [[ -e ${FILE} ]]; then
		checkStatus
		if [[ "$status" == "running" ]]; then
			echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix}并${Green_font_prefix}已启动${Font_color_suffix}"
		else
			echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix}但${Red_font_prefix}未启动${Font_color_suffix}"
		fi
	else
		echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
	fi
	echo
	read -e -p " 请输入数字[1-8]:" num
	case "$num" in
		1)
		Install_v4
		;;
		2)
		Uninstall
		;;
		3)
		Start
		;;
		4)
		Stop
		;;
		5)
		Restart
		;;
		6)
		View
		;;
		7)
		Status
		;;
		8)
		exit 1
		;;
		*)
		echo "请输入正确数字${Yellow_font_prefix}[1-8]${Font_color_suffix}"
		;;
	esac
}
startMenu
