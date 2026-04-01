# CUTE 设计文档仓库

CUTE（CPU-centric and Ultra-utilized Tensor Engine）设计文档，基于 MkDocs + mkdocs-material 构建。

## 快速开始

```bash
# 1. 初始化环境（首次）
./setup-env.sh

# 2. 启动本地预览
./serve.sh
# 浏览器访问 http://127.0.0.1:8000
```

## 项目状态

### 已完成

| 阶段 | 状态 | 说明 |
|------|------|------|
| **Phase 0** — 框架搭建 | ✅ 已完成 | MkDocs 配置、目录骨架、CI 流水线、lint 工具 |
| **Phase 1** — 核心文档 | 🔍 **待 Review** | overview/ + hardware/ 全部文档已生成，内容从源码和 v2 论文提取 |

### Phase 1 文档清单（待 Review）

| 文档 | 内容 |
|------|------|
| `docs/overview/introduction.md` | 项目背景、三大设计原则、性能亮点、已集成 CPU 平台 |
| `docs/overview/architecture-overview.md` | 系统架构、三阶段流水线、数据流路径、13 种数据类型 |
| `docs/overview/getting-started.md` | 环境准备、编译构建、运行仿真 |
| `docs/hardware/compute-engine/mte.md` | MPE 阵列、外积数据流、吞吐公式 |
| `docs/hardware/compute-engine/reduce-pe.md` | FReducePE 5 级流水线、数据类型解码路径 |
| `docs/hardware/compute-engine/after-ops.md` | 后处理模块（当前透传） |
| `docs/hardware/memory-system/scratchpads.md` | A/B/C SCP 双缓冲、多 Bank |
| `docs/hardware/memory-system/scale-scratchpads.md` | Scale Factor SCP |
| `docs/hardware/memory-system/data-controllers.md` | ADC/BDC/CDC/ASC/BSC |
| `docs/hardware/memory-system/memory-loaders.md` | 5 个 Loader、im2col、Source ID CAM |
| `docs/hardware/memory-system/local-mmu.md` | LocalMMU、TLB、5 路仲裁 |
| `docs/hardware/control-logic/task-controller.md` | 指令组装、Tiling 循环、三阶段 FSM |
| `docs/hardware/control-logic/cute-parameters.md` | 全部硬件参数、性能预设 |
| `docs/hardware/control-logic/cute2ygjk.md` | RoCC 接口、指令编码、编程模型 |
| `docs/hardware/integration/rocket-core.md` | Rocket 核集成 |
| `docs/hardware/integration/boom-core.md` | BOOM 核集成 |
| `docs/hardware/integration/shuttle-core.md` | Shuttle 核集成（含评估结果） |

### 待实施

| 阶段 | 说明 |
|------|------|
| **Phase 2** — 指令集与数据类型 | instruction-set/ 和 datatypes/ 文档 |
| **Phase 3** — 软件与测试 | 测试框架、编写指南、基准测试 |
| **Phase 4** — 自动化与发布 | PDF 生成、GitHub Pages 部署 |

## 目录结构

```
design-doc/
├── mkdocs.yml              # MkDocs 配置
├── Makefile                # 构建脚本
├── setup-env.sh            # 环境初始化
├── serve.sh                # 本地预览服务
├── docs/                   # 文档源文件
├── plan/                   # 各 Phase 实施计划
│   ├── phase0-framework-scaffolding.md
│   ├── phase1-core-documentation.md
│   ├── phase2-instruction-set-datatypes.md
│   ├── phase3-software-testing.md
│   └── phase4-automation-publishing.md
├── .github/workflows/      # CI 配置
└── tools/lint/             # Markdown 检查工具
```

## 文档构建

```bash
# 需要 venv
source .venv/bin/activate

# 本地预览
mkdocs serve

# 构建静态站点
mkdocs build

# Markdown 格式检查
make lint

# 生成 PDF（需安装 Pandoc + XeLaTeX）
make pdf
```
