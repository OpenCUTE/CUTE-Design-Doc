#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"

echo "=== CUTE 设计文档环境初始化 ==="

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到 python3，请先安装 Python 3.11+"
    exit 1
fi

echo "[1/3] 创建 Python 虚拟环境..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    echo "  虚拟环境已创建: $VENV_DIR"
else
    echo "  虚拟环境已存在，跳过"
fi

echo "[2/3] 安装依赖..."
source "$VENV_DIR/bin/activate"
pip install -q mkdocs-material mkdocs-mermaid2-plugin
echo "  mkdocs-material + mermaid2 已安装"

echo "[3/3] 验证构建..."
cd "$SCRIPT_DIR"
if mkdocs build -q 2>&1 | grep -q "ERROR"; then
    echo "  构建存在错误，请检查"
    exit 1
else
    echo "  构建验证通过"
fi

echo ""
echo "=== 初始化完成 ==="
echo "启动本地服务: source .venv/bin/activate && ./serve.sh"
echo "或直接运行:   ./serve.sh"
