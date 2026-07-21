#!/bin/bash
set -e

# 1. 自动识别系统环境与包管理器
DETECT_OS=""
INSTALL_CMD=""

if [ -f /etc/alpine-release ]; then
    DETECT_OS="alpine"
    INSTALL_CMD="apk add --no-cache curl bash"
elif [ -f /etc/debian_version ] || [ -f /etc/lsb-release ]; then
    DETECT_OS="debian"
    INSTALL_CMD="apt-get update && apt-get install -y curl bash"
elif [ -f /etc/redhat-release ]; then
    DETECT_OS="redhat"
    INSTALL_CMD="yum install -y curl bash"
else
    DETECT_OS="debian"
    INSTALL_CMD="apt-get install -y curl bash"
fi

# 2. 补齐基础依赖
echo "Checking and installing dependencies..."
eval "$INSTALL_CMD" >/dev/null 2>&1

clear
echo "=================================================="
echo "    Node 跨平台通用部署脚本 (singbox 伪装版)"
echo "=================================================="
echo "当前检测到系统类型: $DETECT_OS"
echo " 1. 安装 / 更新 Node (伪装为 singbox)"
echo " 2. 卸载 Node 伪装实例"
echo " 3. 退出"
echo "=================================================="
read -p "请输入选项 [1-3]: " OPMENU

case $OPMENU in
    1)
        echo -e "\n>>> 开始安装配置 Node..."
        
        # 交互式获取配置参数
        read -p "请输入面板地址 (例如 https://dash.example.com): " PANEL_URL
        read -p "请输入对接 Token (Panel Token): " PANEL_TOKEN
        read -p "请输入 Node ID (节点 ID): " NODE_ID

        # 3. 创建伪装目录
        mkdir -p /opt/singbox
        mkdir -p /opt/singbox/.cache

        # 4. 根据系统类型，自动判断并下载对应的二进制包
        echo "正在下载 Node 核心文件..."
        if [ "$DETECT_OS" = "alpine" ]; then
            # Alpine 系统：使用原生版本
            curl -L -o /opt/singbox/singbox https://dash.yuand.us.kg/api/nezha-agent
        else
            # 其他标准 Linux (Debian/Ubuntu)：直接通过 GitHub API 动态匹配 Release 单文件
            LATEST_TAG=$(curl -s "https://api.github.com/repos/cedar2025/Xboard-Node/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
            if [ -z "$LATEST_TAG" ]; then
                LATEST_TAG="v1.13" # 兜底版本
            fi
            echo "检测到标准 Linux 环境，正在下载官方 Release ${LATEST_TAG} 单文件..."
            
            # 下载单文件并重命名为 singbox 伪装
            curl -L -o /opt/singbox/singbox "https://github.com/cedar2025/Xboard-Node/releases/download/${LATEST_TAG}/xboard-node-linux-amd64"
        fi
        
        chmod +x /opt/singbox/singbox

        # 5. 写入 Node 配置文件
        echo "正在生成配置文件..."
        cat << CONF_EOF > /opt/singbox/config.yml
instances:
  - id: node-${NODE_ID}
    panel:
      url: "${PANEL_URL}"
      token: "${PANEL_TOKEN}"
    kernel:
      type: singbox
      config_dir: /opt/singbox/.cache
      log_level: fatal
    log:
      level: fatal
      output: /dev/null
    health_port: 59999
    nodes:
      - node_id: ${NODE_ID}
CONF_EOF

        # 6. 根据不同的初始化系统（OpenRC 或 Systemd）注册自启服务
        if [ "$DETECT_OS" = "alpine" ]; then
            echo "正在创建 OpenRC 服务守护 (singbox)..."
            cat << 'RC_EOF' > /etc/init.d/singbox
#!/sbin/openrc-run

name="singbox"
description="sing-box service"
command="/opt/singbox/singbox"
command_args="-c /opt/singbox/config.yml"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/dev/null"
error_log="/dev/null"

depend() {
    need net
}
RC_EOF
            chmod +x /etc/init.d/singbox
            rc-update add singbox default >/dev/null 2>&1
            rc-service singbox start
        else
            echo "正在创建 Systemd 服务守护 (singbox)..."
            cat << 'SYS_EOF' > /etc/systemd/system/singbox.service
[Unit]
Description=sing-box service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/singbox
ExecStart=/opt/singbox/singbox -c /opt/singbox/config.yml
Restart=always
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
SYS_EOF
            systemctl daemon-reload
            systemctl enable singbox >/dev/null 2>&1
            systemctl start singbox
        fi

        echo "=================================================="
        echo "🎉 Node 部署成功！(已成功隐蔽为 singbox)"
        echo "=================================================="
        ;;

    2)
        echo -e "\n>>> 正在安全卸载 Node 伪装实例..."
        
        if [ -f "/etc/init.d/singbox" ]; then
            rc-service singbox stop >/dev/null 2>&1 || true
            rc-update del singbox default >/dev/null 2>&1 || true
            rm -f /etc/init.d/singbox
            echo "已清理 OpenRC 伪装服务守护。"
        fi

        if [ -f "/etc/systemd/system/singbox.service" ]; then
            systemctl stop singbox >/dev/null 2>&1 || true
            systemctl disable singbox >/dev/null 2>&1 || true
            rm -f /etc/systemd/system/singbox.service
            systemctl daemon-reload
            echo "已清理 Systemd 伪装服务守护。"
        fi

        if [ -d "/opt/singbox" ]; then
            rm -rf /opt/singbox
            echo "已清理 /opt/singbox 目录及配置文件。"
        fi

        rm -f /run/singbox.pid

        echo "=================================================="
        echo "🧹 卸载完成！已彻底清除伪装节点。"
        echo "=================================================="
        ;;

    3)
        echo "退出脚本。"
        exit 0
        ;;

    *)
        echo "无效的选项，退出。"
        exit 1
        ;;
esac
