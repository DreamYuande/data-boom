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
echo "    Xboard-Node 跨平台通用部署脚本 (伪装版)"
echo "=================================================="
echo "当前检测到系统类型: $DETECT_OS"
echo " 1. 安装 / 更新 Xboard-Node (伪装为 nezha-agent2)"
echo " 2. 卸载 Xboard-Node 伪装实例 (不影响原生哪吒)"
echo " 3. 退出"
echo "=================================================="
read -p "请输入选项 [1-3]: " OPMENU

case $OPMENU in
    1)
        echo -e "\n>>> 开始安装配置 Xboard-Node..."
        
        # 交互式获取配置参数
        read -p "请输入面板地址 (例如 https://dash.example.com): " PANEL_URL
        read -p "请输入对接 Token (Panel Token): " PANEL_TOKEN
        read -p "请输入 Node ID (节点 ID): " NODE_ID

        # 3. 创建伪装目录
        mkdir -p /opt/nezha_v2/agent
        mkdir -p /opt/nezha_v2/agent/.cache

        # 4. 根据系统类型，自动判断并下载对应的二进制包
        echo "正在下载 Xboard-Node 核心文件..."
        if [ "$DETECT_OS" = "alpine" ]; then
            # Alpine 系统：使用你自己编译的 musl 原生版本
            curl -L -o /opt/nezha_v2/agent/nezha-agent https://dash.yuand.us.kg/api/nezha-agent
        else
            # 其他标准 Linux (Debian/Ubuntu)：直接通过 GitHub API 动态匹配 Release 单文件
            # 兼容原作者大小写混用的仓库名 `Xboard-Node`
            LATEST_TAG=$(curl -s "https://api.github.com/repos/cedar2025/Xboard-Node/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
            if [ -z "$LATEST_TAG" ]; then
                LATEST_TAG="v1.13" # 如果拉取失败，用你刚才发给我的 v1.13 作为精准兜底
            fi
            echo "检测到标准 Linux 环境，正在下载官方 Release ${LATEST_TAG} 单文件..."
            
            # 直接下载单文件并重命名伪装
            curl -L -o /opt/nezha_v2/agent/nezha-agent "https://github.com/cedar2025/Xboard-Node/releases/download/${LATEST_TAG}/xboard-node-linux-amd64"
        fi
        
        chmod +x /opt/nezha_v2/agent/nezha-agent

        # 5. 写入 Xboard 配置文件
        echo "正在生成配置文件..."
        cat << CONF_EOF > /opt/nezha_v2/agent/config.yml
instances:
  - id: xboard-node-${NODE_ID}
    panel:
      url: "${PANEL_URL}"
      token: "${PANEL_TOKEN}"
    kernel:
      type: singbox
      config_dir: /opt/nezha_v2/agent/.cache
      log_level: warn
    log:
      level: info
      output: stdout
    health_port: 59999
    nodes:
      - node_id: ${NODE_ID}
CONF_EOF

        # 6. 根据不同的初始化系统（OpenRC 或 Systemd）注册自启服务
        if [ "$DETECT_OS" = "alpine" ]; then
            echo "正在创建 OpenRC 服务守护 (nezha-agent2)..."
            cat << 'RC_EOF' > /etc/init.d/nezha-agent2
#!/sbin/openrc-run

name="nezha-agent2"
description="Nezha Monitoring Agent (Backup Instance)"
command="/opt/nezha_v2/agent/nezha-agent"
command_args="-c /opt/nezha_v2/agent/config.yml"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/dev/null"
error_log="/dev/null"

depend() {
    need net
}
RC_EOF
            chmod +x /etc/init.d/nezha-agent2
            rc-update add nezha-agent2 default >/dev/null 2>&1
            rc-service nezha-agent2 start
        else
            echo "正在创建 Systemd 服务守护 (nezha-agent2)..."
            cat << 'SYS_EOF' > /etc/systemd/system/nezha-agent2.service
[Unit]
Description=Nezha Monitoring Agent (Backup Instance)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/nezha_v2/agent
ExecStart=/opt/nezha_v2/agent/nezha-agent -c /opt/nezha_v2/agent/config.yml
Restart=always
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
SYS_EOF
            systemctl daemon-reload
            systemctl enable nezha-agent2 >/dev/null 2>&1
            systemctl start nezha-agent2
        fi

        echo "=================================================="
        echo "🎉 Xboard-Node 部署成功！(已成功隐蔽为 nezha-agent2)"
        echo "=================================================="
        ;;

    2)
        echo -e "\n>>> 正在安全卸载 Xboard-Node 伪装实例..."
        
        if [ -f "/etc/init.d/nezha-agent2" ]; then
            rc-service nezha-agent2 stop >/dev/null 2>&1 || true
            rc-update del nezha-agent2 default >/dev/null 2>&1 || true
            rm -f /etc/init.d/nezha-agent2
            echo "已清理 OpenRC 伪装服务守护。"
        fi

        if [ -f "/etc/systemd/system/nezha-agent2.service" ]; then
            systemctl stop nezha-agent2 >/dev/null 2>&1 || true
            systemctl disable nezha-agent2 >/dev/null 2>&1 || true
            rm -f /etc/systemd/system/nezha-agent2.service
            systemctl daemon-reload
            echo "已清理 Systemd 伪装服务守护。"
        fi

        if [ -d "/opt/nezha_v2" ]; then
            rm -rf /opt/nezha_v2
            echo "已清理 /opt/nezha_v2 目录及配置文件。"
        fi

        rm -f /run/nezha-agent2.pid

        echo "=================================================="
        echo "🧹 卸载完成！已彻底清除伪装节点。"
        echo "安全提示：系统原生运行的 nezha-agent 未受任何影响。"
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
