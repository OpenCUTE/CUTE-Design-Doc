#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

# 自动激活 venv
if [ ! -d "$VENV_DIR" ]; then
    echo "未找到虚拟环境，请先运行: ./setup-env.sh"
    exit 1
fi

source "$VENV_DIR/bin/activate"
cd "$SCRIPT_DIR"

echo "=== 启动 CUTE 设计文档本地服务 ==="
echo "访问地址: http://127.0.0.1:8000"
echo "按 Ctrl+C 停止"
echo ""

mkdocs serve -a 127.0.0.1:8000
