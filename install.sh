#!/bin/bash

# ===============================
# 🎨 UI COLORS
# ===============================
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
PURPLE="\033[35m"
RESET="\033[0m"

clear

echo -e "${PURPLE}"
echo "========================================="
echo "   🚀 BBR v3 AUTO INSTALLER (MomoFlora)"
echo "========================================="
echo -e "${RESET}"

# ===============================
# CHECK ROOT
# ===============================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}请使用 root 运行该脚本${RESET}"
    exit 1
fi

# ===============================
# CHECK ARCH
# ===============================
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    echo -e "${RED}❌ 仅支持 x86_64，你的架构：$ARCH${RESET}"
    exit 1
fi

echo -e "${GREEN}✔ 架构检查通过：$ARCH${RESET}"

# ===============================
# DEPENDENCIES
# ===============================
echo -e "${CYAN}📦 检查依赖...${RESET}"

for pkg in curl wget jq dpkg; do
    if ! command -v $pkg &>/dev/null; then
        echo -e "${YELLOW}安装依赖：$pkg${RESET}"
        apt-get update -y && apt-get install -y $pkg
    fi
done

# ===============================
# REPO CONFIG
# ===============================
REPO="MomoFlora/kernel-latest-bbr3"
API="https://api.github.com/repos/$REPO/releases"

# ===============================
# GET RELEASE INFO
# ===============================
get_latest_tag() {
    curl -fsSL "$API" | jq -r '.[0].tag_name'
}

get_download_links() {
    local tag="$1"
    curl -fsSL "$API" | jq -r --arg tag "$tag" '
        .[] | select(.tag_name==$tag) | .assets[].browser_download_url
        | select(test(".deb$"))
    '
}

# ===============================
# GET INSTALLED VERSION
# ===============================
get_installed() {
    dpkg -l | grep "linux-image" | grep "MomoFlora" | awk '{print $2}' | head -n1 | sed 's/linux-image-//'
}

# ===============================
# INSTALL KERNEL
# ===============================
install_kernel() {
    local tag="$1"

    echo -e "${BLUE}⬇ 下载内核版本：$tag${RESET}"

    rm -f /tmp/kernel-*.deb

    for url in $(get_download_links "$tag"); do
        echo -e "${CYAN}下载：$url${RESET}"
        wget -q --show-progress "$url" -P /tmp/
    done

    echo -e "${YELLOW}📦 安装内核中...${RESET}"

    dpkg -i /tmp/kernel-*.deb

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✔ 内核安装成功${RESET}"
    else
        echo -e "${RED}❌ 安装失败${RESET}"
        exit 1
    fi
}

# ===============================
# ENABLE BBR
# ===============================
enable_bbr() {
    echo -e "${CYAN}⚙ 配置 BBR + FQ...${RESET}"

    cat > /etc/sysctl.d/99-bbr.conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl --system > /dev/null

    echo -e "${GREEN}✔ BBR 已启用${RESET}"
}

# ===============================
# MAIN LOGIC
# ===============================
echo -e "${CYAN}🔍 检查版本信息...${RESET}"

LATEST=$(get_latest_tag)
INSTALLED=$(get_installed)

echo -e "${BLUE}最新版本：${RESET}${YELLOW}$LATEST${RESET}"
echo -e "${BLUE}已安装版本：${RESET}${YELLOW}${INSTALLED:-未安装}${RESET}"

# ===============================
# DECISION
# ===============================
if [[ -z "$INSTALLED" ]]; then
    echo -e "${YELLOW}📥 未安装内核，开始安装...${RESET}"
    install_kernel "$LATEST"
    enable_bbr

elif [[ "$INSTALLED" != "$LATEST" ]]; then
    echo -e "${YELLOW}🔄 检测到新版本，开始更新...${RESET}"
    install_kernel "$LATEST"
    enable_bbr

else
    echo -e "${GREEN}✔ 已是最新版本，无需更新${RESET}"
fi

# ===============================
# DONE
# ===============================
echo -e "${PURPLE}"
echo "========================================="
echo " 🎉 BBR v3 安装/更新完成"
echo " 💡 建议重启系统以确保生效"
echo "========================================="
echo -e "${RESET}"
