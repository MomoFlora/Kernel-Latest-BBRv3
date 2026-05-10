#!/bin/bash

# =========================================================
# Project: MomoFlora BBR3 Kernel Installer
# Repository: https://github.com/MomoFlora/kernel-latest-bbr3
# Architecture: x86_64 Only
# =========================================================

# --- 终端颜色与日志格式设定 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 核心变量 ---
REPO="MomoFlora/kernel-latest-bbr3"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
SYSCTL_CONF="/etc/sysctl.d/99-momoflora-bbr.conf"
MODULES_CONF="/etc/modules-load.d/momoflora-qdisc.conf"
SECURITY_MODPROBE_CONF="/etc/modprobe.d/99-momoflora-security.conf"
GITHUB_API_TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"

# --- 打印专业 Banner ---
print_banner() {
    clear
    echo -e "${BLUE}"
    cat << "EOF"
 ███╗   ███╗ ██████╗ ███╗   ███╗ ██████╗ 
 ████╗ ████║██╔═══██╗████╗ ████║██╔═══██╗
 ██╔████╔██║██║   ██║██╔████╔██║██║   ██║
 ██║╚██╔╝██║██║   ██║██║╚██╔╝██║██║   ██║
 ██║ ╚═╝ ██║╚██████╔╝██║ ╚═╝ ██║╚██████╔╝
 ╚═╝     ╚═╝ ╚═════╝ ╚═╝     ╚═╝ ╚═════╝ 
        Kernel BBR3 Auto-Installer
EOF
    echo -e "${NC}"
    echo -e " Repository: https://github.com/${REPO}"
    echo -e " Architecture: x86_64 | OS: Debian/Ubuntu"
    echo -e " =========================================================\n"
}

# --- 环境检查 ---
check_env() {
    if ! command -v apt-get &> /dev/null; then
        log_error "此脚本仅支持基于 Debian/Ubuntu 的系统。"
        exit 1
    fi

    if [[ "$(id -u)" -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            sudo() { command sudo "$@"; }
        else
            log_error "缺少依赖：sudo。请在 root 环境下运行或安装 sudo。"
            exit 1
        fi
    else
        sudo() { "$@"; }
    fi

    local ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]]; then
        log_error "此脚本仅支持 x86_64 架构。您的系统架构为：$ARCH"
        exit 1
    fi

    local REQUIRED_CMDS=("curl" "wget" "dpkg" "awk" "sed" "sysctl" "jq")
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            log_warn "缺少依赖：$cmd，正在自动安装..."
            sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y $cmd >/dev/null 2>&1
        fi
    done
}

# --- GitHub API 请求包装 ---
gh_api_get() {
    if [[ -n "$GITHUB_API_TOKEN" ]]; then
        curl -sSL -H "Authorization: Bearer $GITHUB_API_TOKEN" -H "Accept: application/vnd.github+json" "$1"
    else
        curl -sSL "$1"
    fi
}

# --- 安全策略配置 (CVE & Dirty Frag) ---
apply_security_mitigations() {
    local changed=0
    sudo touch "$SECURITY_MODPROBE_CONF"
    
    ensure_rule() {
        if ! grep -Fqx "$1" "$SECURITY_MODPROBE_CONF" 2>/dev/null; then
            echo "$1" | sudo tee -a "$SECURITY_MODPROBE_CONF" > /dev/null
            changed=1
        fi
    }

    ensure_rule "# Managed by MomoFlora BBR3 Script"
    ensure_rule "blacklist algif_aead"
    ensure_rule "install algif_aead /bin/false"
    ensure_rule "blacklist esp4"
    ensure_rule "install esp4 /bin/false"
    ensure_rule "blacklist esp6"
    ensure_rule "install esp6 /bin/false"
    ensure_rule "blacklist rxrpc"
    ensure_rule "install rxrpc /bin/false"

    for mod in algif_aead esp4 esp6 rxrpc; do
        if lsmod | grep -q "^$mod"; then
            sudo modprobe -r "$mod" 2>/dev/null || log_warn "模块 $mod 被占用，重启后安全策略生效"
        fi
    done

    [[ "$changed" -eq 1 ]] && log_success "安全防御策略已配置更新。"
}

# --- 获取系统当前 BBR/队列 状态 ---
get_current_status() {
    CURRENT_ALGO=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    CURRENT_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null)
}

# --- 更新与安装内核 ---
install_latest_kernel() {
    log_info "正在连接 GitHub API 检索最新版本..."
    
    local RELEASE_DATA=$(gh_api_get "$API_URL")
    local LATEST_TAG=$(echo "$RELEASE_DATA" | jq -r '.tag_name')
    
    if [[ -z "$LATEST_TAG" || "$LATEST_TAG" == "null" ]]; then
        log_error "获取最新版本信息失败，请检查网络或 GitHub API 限制。"
        return 1
    fi
    
    local CURRENT_KERNEL=$(uname -r)
    log_info "最新发布版本: $LATEST_TAG"
    log_info "当前系统内核: $CURRENT_KERNEL"

    # --- 版本检测逻辑：如果当前内核是以最新 Tag 开头的，则无需更新 ---
    if [[ "$CURRENT_KERNEL" == "$LATEST_TAG"* ]]; then
        log_success "检测到当前内核已经是最新版本 ($LATEST_TAG)，无需重复安装。"
        return 0
    fi

    log_warn "发现新版本，准备开始安装程序..."

    # 提取以 .deb 结尾的下载链接
    local ASSET_URLS=$(echo "$RELEASE_DATA" | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url')
    
    if [[ -z "$ASSET_URLS" ]]; then
        log_error "该 Release 版本中未找到任何 .deb 安装包。"
        return 1
    fi

    rm -f /tmp/linux-*.deb
    
    log_info "开始从 GitHub 获取内核组件..."
    for URL in $ASSET_URLS; do
        log_info "下载 -> $(basename "$URL")"
        wget -q --show-progress "$URL" -P /tmp/ || { log_error "下载失败：$URL"; return 1; }
    done

    log_info "正在调用 dpkg 安装内核..."
    if sudo dpkg -i /tmp/linux-*.deb; then
        command -v update-grub &> /dev/null && sudo update-grub >/dev/null 2>&1
        log_success "内核安装包部署成功！"
        
        echo -n -e "${YELLOW}[PROMPT]${NC} 内核更新需要重启系统生效。是否立即重启？(y/n): "
        read -r REBOOT_NOW
        if [[ "$REBOOT_NOW" =~ ^[Yy]$ ]]; then
            log_info "系统执行重启..."
            sudo reboot
        else
            log_warn "请稍后务必手动执行重启命令以应用新内核。"
        fi
    else
        log_error "内核安装失败，请检查上方 dpkg 报错详情。"
    fi
}

# --- 配置 TCP 拥塞控制与队列算法 ---
configure_bbr() {
    local TARGET_QDISC="$1"
    
    log_info "正在应用网络配置: BBR + $TARGET_QDISC ..."
    sudo sysctl -w net.core.default_qdisc="$TARGET_QDISC" > /dev/null 2>&1
    sudo sysctl -w net.ipv4.tcp_congestion_control="bbr" > /dev/null 2>&1

    local NEW_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    local NEW_ALGO=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)

    if [[ "$NEW_QDISC" == "$TARGET_QDISC" && "$NEW_ALGO" == "bbr" ]]; then
        log_success "配置已实时生效！"
        echo -n -e "${YELLOW}[PROMPT]${NC} 是否永久保存此配置至系统？(y/n): "
        read -r SAVE
        if [[ "$SAVE" =~ ^[Yy]$ ]]; then
            sudo touch "$SYSCTL_CONF"
            sudo sed -i '/net.core.default_qdisc/d' "$SYSCTL_CONF"
            sudo sed -i '/net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
            echo "net.core.default_qdisc=$TARGET_QDISC" | sudo tee -a "$SYSCTL_CONF" > /dev/null
            echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a "$SYSCTL_CONF" > /dev/null
            
            if [[ "$TARGET_QDISC" != "fq" && "$TARGET_QDISC" != "fq_codel" ]]; then
                echo "sch_$TARGET_QDISC" | sudo tee "$MODULES_CONF" > /dev/null
            else
                sudo rm -f "$MODULES_CONF"
            fi
            log_success "配置已永久固化至系统。"
        else
            log_info "当前为临时生效，重启后会还原。"
        fi
    else
        log_error "配置应用失败。请确保您已切换到支持 BBR3 的内核。"
    fi
}

# --- 系统检测分析 ---
analyze_system() {
    log_info "正在执行系统底层网络参数扫描..."
    
    local BBR_MODULE_INFO=$(modinfo tcp_bbr 2>/dev/null)
    if [[ -z "$BBR_MODULE_INFO" ]]; then
        depmod -a >/dev/null 2>&1
        BBR_MODULE_INFO=$(modinfo tcp_bbr 2>/dev/null)
    fi
    
    if [[ -z "$BBR_MODULE_INFO" ]]; then
        log_error "未检测到 tcp_bbr 模块。请先运行选项 1 安装内核并重启。"
        return
    fi
    
    local BBR_VERSION=$(echo "$BBR_MODULE_INFO" | awk '/^version:/ {print $2}')
    if [[ "$BBR_VERSION" == "3" ]]; then
        log_success "BBR 版本状态: v$BBR_VERSION (BBR3 已就绪)"
    else
        log_warn "BBR 版本状态: v${BBR_VERSION:-未知} (当前非 BBR3 环境)"
    fi

    get_current_status
    log_info "当前运行状态:"
    echo -e "  - TCP 拥塞控制: ${GREEN}$CURRENT_ALGO${NC}"
    echo -e "  - 队列调度算法: ${GREEN}$CURRENT_QDISC${NC}"
}

# --- 卸载逻辑 ---
uninstall_kernel() {
    log_warn "正在检索系统中的自定义 BBR3 内核包..."
    local PKGS=$(dpkg -l | grep -iE 'linux-image-.*-bbr3|linux-headers-.*-bbr3' | awk '{print $2}' | tr '\n' ' ')
    
    if [[ -n "$PKGS" ]]; then
        log_info "即将卸载以下包: $PKGS"
        sudo apt-get remove --purge $PKGS -y
        command -v update-grub &> /dev/null && sudo update-grub >/dev/null 2>&1
        log_success "内核组件已移除。请务必立即重启系统以回退到默认内核！"
    else
        log_info "系统未发现特定命名的 BBR3 内核包。"
    fi
}

# --- 主控循环 ---
main() {
    check_env
    apply_security_mitigations
    
    while true; do
        print_banner
        get_current_status
        
        echo -e "  当前 TCP 算法 : ${GREEN}${CURRENT_ALGO}${NC}"
        echo -e "  当前队列调度 : ${GREEN}${CURRENT_QDISC}${NC}"
        echo -e " ---------------------------------------------------------"
        echo -e "  ${BLUE}1.${NC} 安装 / 更新最新版 BBR v3"
        echo -e "  ${BLUE}2.${NC} 检测系统 BBR 运行状态"
        echo -e "  ${BLUE}3.${NC} 启用 BBR + FQ (标准推荐)"
        echo -e "  ${BLUE}4.${NC} 启用 BBR + FQ_CODEL"
        echo -e "  ${BLUE}5.${NC} 启用 BBR + FQ_PIE"
        echo -e "  ${BLUE}6.${NC} 启用 BBR + CAKE"
        echo -e "  ${BLUE}7.${NC} 卸载定制内核组件"
        echo -e "  ${BLUE}8.${NC} 退出脚本"
        echo -e " ---------------------------------------------------------"
        
        echo -n -e "${YELLOW}请选择操作编号 [1-8]: ${NC}"
        read -r ACTION
        echo ""

        case "$ACTION" in
            1) install_latest_kernel ;;
            2) analyze_system ;;
            3) configure_bbr "fq" ;;
            4) configure_bbr "fq_codel" ;;
            5) configure_bbr "fq_pie" ;;
            6) configure_bbr "cake" ;;
            7) uninstall_kernel ;;
            8) log_info "退出程序。"; exit 0 ;;
            *) log_error "输入无效，请输入 1 到 8 之间的数字。" ;;
        esac
        
        echo ""
        echo -n -e "${BLUE}按回车键继续...${NC}"
        read -r
    done
}

main
