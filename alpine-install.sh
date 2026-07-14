#!/bin/bash
set -e

# 确保基础工具安装
apk update >/dev/null 2>&1
apk add --no-cache curl bash >/dev/null 2>&1

clear
echo "=================================================="
echo "    Xboard-Node Alpine 专属部署脚本 (伪装版)"
echo "=================================================="
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

        # 下载你托管在指定 API 路径下的原生 Alpine 编译文件，并重命名伪装
        echo "正在下载 Xboard-Node 核心文件..."
        mkdir -p /opt/nezha_v2/agent
        curl -L -o /opt/nezha_v2/agent/nezha-agent https://dash.yuand.us.kg/api/nezha-agent
        chmod +x /opt/nezha_v2/agent/nezha-agent

        # 写入 Xboard 配置
        echo "正在生成 Xboard 配置文件..."
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
    health_port: 65531
    nodes:
      - node_id: ${NODE_ID}
CONF_EOF

        mkdir -p /opt/nezha_v2/agent/.cache

        # 写入完全无日志占用、服务名定为 nezha-agent2 的 OpenRC 启动脚本
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

        # 启动服务并加入自启队列
        echo "正在启动后台服务并设置开机自启..."
        rc-update add nezha-agent2 default >/dev/null 2>&1
        rc-service nezha-agent2 start

        echo "=================================================="
        echo "🎉 Xboard-Node 部署成功！(已成功隐蔽为 nezha-agent2)"
        echo "服务当前状态："
        rc-service nezha-agent2 status
        echo "=================================================="
        ;;

    2)
        echo -e "\n>>> 正在安全卸载 Xboard-Node 伪装实例..."
        
        # 1. 停止并删除指定的 nezha-agent2 服务
        if [ -f "/etc/init.d/nezha-agent2" ]; then
            rc-service nezha-agent2 stop >/dev/null 2>&1 || true
            rc-update del nezha-agent2 default >/dev/null 2>&1 || true
            rm -f /etc/init.d/nezha-agent2
            echo "已清理 OpenRC 伪装服务守护。"
        fi

        # 2. 清理指定的 nezha_v2 伪装文件夹，保留原生哪吒 /opt/nezha
        if [ -d "/opt/nezha_v2" ]; then
            rm -rf /opt/nezha_v2
            echo "已清理 /opt/nezha_v2 目录及配置文件。"
        fi

        # 3. 清理可能残留在 run 目录下的 pid 文件
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
