#!/bin/bash
# ==========================================
# Ookla Speedtest CLI 一键下载、运行并自动销毁脚本
# ==========================================

# 1. 切换到临时目录
cd /tmp || exit 1

# 2. 识别系统架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        OOKLA_ARCH="x86_64"
        ;;
    aarch64)
        OOKLA_ARCH="aarch64"
        ;;
    armv7l|armv8l)
        OOKLA_ARCH="armhf"
        ;;
    i386|i686)
        OOKLA_ARCH="i386"
        ;;
    *)
        echo "❌ 不支持的系统架构: $ARCH"
        exit 1
        ;;
esac

# 设定当前官方最新版本号
VERSION="1.2.0"
DOWNLOAD_URL="https://install.speedtest.net/app/cli/ookla-speedtest-${VERSION}-linux-${OOKLA_ARCH}.tgz"
TAR_FILE="speedtest_cli.tgz"
EXECUTABLE="speedtest"

# 🌟 关键：设置清理钩子
# 无论脚本是正常结束(EXIT)还是被 Ctrl+C 中止(INT/TERM)，都会执行删除命令
trap 'rm -f /tmp/$EXECUTABLE /tmp/$TAR_FILE; echo "🧹 已自动清理临时文件。"' EXIT

echo "🔍 检测到系统架构: $OOKLA_ARCH"
echo "⬇️  正在下载并准备测速..."

# 3. 下载
if command -v wget &> /dev/null; then
    wget -qO $TAR_FILE "$DOWNLOAD_URL"
elif command -v curl &> /dev/null; then
    curl -sL -o $TAR_FILE "$DOWNLOAD_URL"
else
    echo "❌ 错误: 未找到 wget 或 curl"
    exit 1
fi

# 4. 解压
tar -xzf $TAR_FILE $EXECUTABLE

if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ 解压失败！"
    exit 1
fi

# 5. 赋予执行权限
chmod +x $EXECUTABLE

# 6. 运行测速
echo "🚀 开始执行网络测速..."
echo "-------------------------------------------------------"
./$EXECUTABLE --accept-license --accept-gdpr
echo "-------------------------------------------------------"

# 脚本到此结束，触发 trap 自动执行 rm 命令
