# CUTE 设计文档仓库规划

> 参考香山（XiangShan）设计文档仓库的文件组织与技术栈，为 CUTE 项目量身定制文档仓库方案。

---

## 第一章 香山设计文档仓库 — 文件组织

### 1.1 顶层目录结构

```
XiangShan-Design-Doc/
├── .github/                 # CI/CD 与 Issue 模板
│   ├── ISSUE_TEMPLATE/      # Bug 报告模板
│   └── workflows/           # GitHub Actions（自动构建 PDF、Release）
├── docs/                    # 文档源文件（核心目录）
│   ├── zh/                  # 中文文档
│   ├── en/                  # 英文文档
│   └── shared/              # 中英文共享资源（图片等）
├── tools/                   # 构建 / 检查工具
│   └── lint/                # Markdown lint（Docker 化）
├── utils/                   # Git 子模块：docs-utils（MkDocs 基础配置）
├── mkdocs.yml               # MkDocs 入口（按环境变量选择语言）
├── mkdocs-zh.yml            # 中文站点配置
├── mkdocs-en.yml            # 英文站点配置
├── Makefile                 # 构建脚本（PDF / HTML）
├── .readthedocs.yaml        # ReadTheDocs 部署配置
├── .markdownlint.yml        # Markdown 规范
├── README.md / README.zh.md # 仓库说明
└── LICENSE                  # CC BY 4.0
```

### 1.2 文档目录组织模式

香山按**处理器微架构子系统**分层组织，三级目录：

```
docs/zh/
├── index.md                 # 总览与导航
├── frontend/                # 前端（取指 / 分支预测）
│   ├── index.md
│   ├── BPU/                 # 分支预测单元
│   │   ├── TAGE-SC.md
│   │   ├── FTB.md
│   │   └── ...
│   ├── IFU/                 # 取指单元
│   ├── ICache/              # 指令缓存
│   └── FTQ/                 # 取指目标队列
├── backend/                 # 后端（执行 / 调度）
│   ├── CtrlBlock/           # 控制块（译码 / 重命名 / 派遣 / ROB）
│   ├── Schedule_And_Issue/  # 调度与发射
│   ├── ExuBlock/            # 执行块
│   └── FunctionUnit/        # 功能单元（整 / 浮 / 向量 / 访存）
├── memblock/                # 访存子系统
│   ├── LSU/                 # Load-Store Unit
│   ├── DCache/              # 数据缓存
│   └── MMU/                 # 内存管理单元
└── cache/                   # L2 缓存子系统
    └── l2cache/
```

### 1.3 关键组织原则

| 原则 | 做法 |
|---|---|
| **按子系统分层** | 目录层级对应硬件模块层次 |
| **每模块一个 index.md** | 作为模块导航页 |
| **图片就近存放** | 每个子模块内 `figure/` 目录 |
| **中英双语平行** | `docs/zh/` 与 `docs/en/` 结构完全镜像，共享资源放 `shared/` |
| **变量外部化** | `variables-zh.yml` / `variables-en.yml` 集中管理版本号、项目名 |
| **模块内容标准化** | 每个模块文档包含：术语 → 规格 → 功能描述 → 总体设计 → 接口时序 → 寄存器 → 参考 |

---

## 第二章 香山设计文档仓库 — 技术栈

### 2.1 文档框架与构建

| 工具 | 用途 |
|---|---|
| **MkDocs + mkdocs-material** | 静态网站生成，提供搜索、导航、主题 |
| **Pandoc + XeLaTeX** | Markdown → PDF 转换，支持中文字体 |
| **Make** | 统一构建入口（`make pdf`、`make html`） |
| **Lua Filter** | 自定义 Pandoc 过滤器（变量替换、SVG 处理） |
| **Python 3.13** | MkDocs 运行时 |

### 2.2 图表与绘图

| 格式 | 说明 |
|---|---|
| SVG | 主要矢量图格式（49+ 文件） |
| Draw.io (`.drawio`) | 可编辑架构图源文件 |
| DOT (Graphviz) | 自动化关系图 |
| PNG | 位图辅助 |

### 2.3 质量保证

| 工具 | 用途 |
|---|---|
| **markdownlint-cli2** | Markdown 格式检查 |
| **lint-md** | 中文 Markdown 专项检查 |
| **Docker** | 容器化 lint 环境，保证一致性 |
| **GitHub Actions** | 自动构建 PDF / Release、Issue 管理 |

### 2.4 发布与部署

| 平台 | 用途 |
|---|---|
| **ReadTheDocs** | 在线文档托管（`.readthedocs.yaml`） |
| **GitHub Releases** | PDF 附件分发 |
| **GitHub Pages**（通过 MkDocs） | 备选静态站点 |

### 2.5 技术栈总结图

```
写作 → Markdown (.md)
  ↓
检查 → markdownlint + lint-md
  ↓
构建 → MkDocs (网站) / Pandoc+XeLaTeX (PDF)
  ↓
部署 → ReadTheDocs / GitHub Releases
  ↓
CI/CD → GitHub Actions（自动构建、自动发布）
```

---

## 第三章 CUTE 设计文档仓库 — 文件组织方案

### 3.1 设计思路

CUTE 与香山的差异：

| 维度 | 香山 | CUTE |
|---|---|---|
| 类型 | 完整 RISC-V 处理器 | CPU 集成张量加速器 |
| 模块数 | 前端/后端/访存/L2 四大子系统 | 计算引擎/存储系统/控制逻辑/接口 |
| 文档受众 | 芯片设计工程师 | 硬件工程师 + 算法/测试工程师 |
| 语言需求 | 中英双语 | 以中文为主，关键部分提供英文 |

基于此，CUTE 的文档组织遵循 **"按硬件模块 + 按开发阶段"双维度** 结构。

### 3.2 推荐目录结构

```
CUTE/doc/design-doc/
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── config.yml
│   │   └── document-bug.yml
│   └── workflows/
│       ├── build-pandoc.yml       # 自动构建 PDF
│       └── deploy.yml             # 部署到 GitHub Pages
│
├── docs/
│   ├── index.md                   # CUTE 项目总览
│   │
│   ├── overview/                  # 项目概述
│   │   ├── index.md               # 概述导航
│   │   ├── introduction.md        # 项目背景与目标
│   │   ├── architecture-overview.md  # 整体架构总览
│   │   └── getting-started.md     # 快速上手指南
│   │
│   ├── hardware/                  # 硬件设计文档
│   │   ├── index.md
│   │   ├── compute-engine/        # 计算引擎
│   │   │   ├── index.md
│   │   │   ├── mte.md             # Matrix Tensor Engine（4×4 PE 阵列）
│   │   │   ├── reduce-pe.md       # ReducePE — MAC 运算单元
│   │   │   └── after-ops.md       # 后处理操作
│   │   ├── memory-system/         # 存储系统
│   │   │   ├── index.md
│   │   │   ├── scratchpads.md     # A/B/C Scratchpad 设计
│   │   │   ├── scale-scratchpads.md  # Scale Factor Scratchpad
│   │   │   ├── data-controllers.md   # 数据流控制器
│   │   │   ├── memory-loaders.md     # 内存加载器
│   │   │   └── local-mmu.md      # 本地内存管理单元
│   │   ├── control-logic/         # 控制逻辑
│   │   │   ├── index.md
│   │   │   ├── task-controller.md # 指令译码与调度
│   │   │   ├── cute-parameters.md # 硬件参数配置
│   │   │   └── cute2ygjk.md       # YGJK / RoCC 接口
│   │   └── integration/           # 集成方案
│   │       ├── index.md
│   │       ├── rocket-core.md     # Rocket 核集成
│   │       ├── boom-core.md       # BOOM 核集成
│   │       └── shuttle-core.md    # Shuttle 核集成
│   │
│   ├── instruction-set/           # 指令集文档
│   │   ├── index.md
│   │   ├── instruction-encoding.md   # YGJK 指令编码
│   │   ├── fusion-operators.md       # 融合算子说明
│   │   └── instruction-reference.md  # 指令速查表
│   │
│   ├── datatypes/                 # 数据类型文档
│   │   ├── index.md
│   │   ├── precision-formats.md   # 精度格式总览（I8/FP16/BF16/TF32/FP8/FP4/MXFP）
│   │   ├── quantization.md        # 量化与 Block-Scale
│   │   └── datatype-support.md    # 各模块数据类型支持矩阵
│   │
│   ├── software/                  # 软件与测试
│   │   ├── index.md
│   │   ├── test-framework.md      # 测试框架设计（5 层架构）
│   │   ├── test-writing-guide.md  # 测试编写指南
│   │   ├── dramsim-config.md      # DRAMSim 配置说明
│   │   └── benchmark-results.md   # 基准测试结果
│   │
│   ├── appendix/                  # 附录
│   │   ├── glossary.md            # 术语表
│   │   ├── references.md          # 参考文献
│   │   └── changelog.md           # 文档变更记录
│   │
│   └── shared/                    # 共享资源
│       └── figures/               # 全局图片
│           ├── architecture/      # 架构图
│           ├── microarch/         # 微架构图
│           └── timing/            # 时序图
│
├── tools/
│   └── lint/
│       ├── Dockerfile
│       └── run-lint.sh
│
├── mkdocs.yml                     # MkDocs 主配置
├── Makefile                       # 构建脚本
├── .readthedocs.yaml              # ReadTheDocs 部署
├── .markdownlint.yml              # Markdown 规范
├── .gitignore
├── README.md
└── LICENSE                        # 建议 CC BY 4.0
```

### 3.3 模块内容模板

每个硬件模块文档建议遵循以下结构：

```markdown
# 模块名称

## 1. 术语说明
## 2. 设计规格
   - 参数配置
   - 接口列表
## 3. 功能描述
## 4. 微架构设计
   - 总体框图
   - 关键通路说明
## 5. 数据类型支持
## 6. 接口时序（波形图）
## 7. 与其他模块的交互
## 8. 参考
```

---

## 第四章 CUTE 设计文档仓库 — 技术栈方案

### 4.1 推荐技术栈

#### 文档框架

| 工具 | 版本建议 | 用途 |
|---|---|---|
| **MkDocs** | ≥ 1.6 | 静态网站生成 |
| **mkdocs-material** | ≥ 9.x | 主题（搜索、导航、暗色模式、Mermaid 图表） |
| **Python** | ≥ 3.11 | MkDocs 运行时 |

选择理由：MkDocs 成熟稳定、社区活跃；mkdocs-material 支持内嵌 Mermaid 流程图（适合硬件架构图），且与香山保持一致，降低学习成本。

#### PDF 生成

| 工具 | 用途 |
|---|---|
| **Pandoc** | Markdown → LaTeX/HTML 中间转换 |
| **XeLaTeX** | 支持中文的 PDF 排版引擎 |
| **pandoc-crossref** | 图表公式交叉引用 |

#### 图表绘制

| 工具 | 用途 |
|---|---|
| **Draw.io** | 架构图、模块框图（`.drawio` 源文件） |
| **Mermaid** | 内嵌 Markdown 的流程图 / 时序图（轻量级） |
| **WaveDrom** | 数字波形 / 时序图（硬件接口时序） |
| **SVG / PNG** | 最终发布格式 |

WaveDrom 的引入是相比香山的重要补充 — 它是硬件设计的标准时序图工具，非常适合描述 RoCC 接口、Scratchpad 读写时序等。

#### 质量保证

| 工具 | 用途 |
|---|---|
| **markdownlint-cli2** | Markdown 格式检查 |
| **markdown-link-check** | 链接有效性检查 |
| **GitHub Actions** | 自动化 CI（lint + build） |

#### 部署

| 平台 | 用途 |
|---|---|
| **GitHub Pages** | 在线文档托管（首选，免费且与仓库紧耦合） |
| **ReadTheDocs**（可选） | 备选托管方案 |
| **GitHub Releases** | PDF 版本发布 |

### 4.2 MkDocs 配置要点

```yaml
# mkdocs.yml 示例
site_name: CUTE Design Document
theme:
  name: material
  language: zh
  features:
    - navigation.tabs           # 顶部导航标签
    - navigation.indexes        # 目录 index 页
    - search.suggest            # 搜索建议
    - content.mermaid           # Mermaid 图表支持
    - content.code.copy         # 代码块一键复制

plugins:
  - search
  - mermaid2                    # Mermaid 图表渲染

markdown_extensions:
  - pymdownx.superfences        # 代码块增强
  - pymdownx.arithmatex         # LaTeX 数学公式
  - tables                      # 表格
  - footnotes                   # 脚注
  - attr_list                   # 属性列表

nav:
  - 首页: index.md
  - 项目概述: overview/
  - 硬件设计: hardware/
  - 指令集: instruction-set/
  - 数据类型: datatypes/
  - 软件与测试: software/
  - 附录: appendix/
```

### 4.3 Makefile 构建目标

```makefile
# 核心目标
.PHONY: serve build pdf lint clean

serve:          # 本地预览（热更新）
	mkdocs serve

build:          # 构建静态站点
	mkdocs build

pdf:            # 生成 PDF
	pandoc docs/index.md ... -o build/cute-design-doc.pdf

lint:           # 格式检查
	markdownlint-cli2 "docs/**/*.md"

clean:          # 清理构建产物
	rm -rf site/ build/
```

### 4.4 技术栈对比

| 维度 | 香山 | CUTE（本方案） | 差异原因 |
|---|---|---|---|
| 多语言 | 中英双语完全平行 | 以中文为主 | CUTE 受众以国内为主，降低维护成本 |
| 时序图 | SVG 手绘 / Draw.io | **WaveDrom** | 硬件时序图标准化需求 |
| 轻量图表 | 无 | **Mermaid** | 快速绘制模块关系、数据流 |
| 部署 | ReadTheDocs | **GitHub Pages** | 与 CUTE 主仓库紧耦合 |
| 子模块 | docs-utils 外部共享 | 不使用子模块 | CUTE 文档规模适中，无需拆分 |

---

## 第五章 总结

### 香山经验的核心启示

1. **模块化文档结构**：按硬件子系统组织，每个模块一个独立目录 + index.md，便于多人协作和增量维护。
2. **标准化内容模板**：统一的文档结构（术语 → 规格 → 设计 → 接口 → 参考）让读者形成稳定的阅读预期。
3. **自动化构建流水线**：Make + Pandoc + CI 实现从 Markdown 到 网站/PDF 的一键发布。
4. **变量外部化**：版本号、项目名集中管理，升级时一处修改全局生效。

### CUTE 方案的关键定制

| 定制点 | 原因 |
|---|---|
| 增加 `instruction-set/` 目录 | CUTE 的 YGJK 自定义指令集是核心知识，需要独立成章 |
| 增加 `datatypes/` 目录 | CUTE 支持 13 种数据类型（FP8/FP4/MXFP 等），复杂度远超普通项目 |
| 增加 `software/` 目录 | CUTE 有 355 个测试文件和 5 层测试框架，需要专门文档 |
| 引入 WaveDrom | 硬件时序图是设计文档的核心内容 |
| 引入 Mermaid | 快速绘制数据流和模块交互图 |
| 简化多语言方案 | 先以中文为主，避免初期维护负担 |
| 使用 GitHub Pages | 与 CUTE 主仓库统一管理 |

### 落地步骤建议

1. **Phase 0 — 框架搭建**：初始化 MkDocs 项目、目录骨架、CI 配置
2. **Phase 1 — 核心文档**：补齐 `overview/` 和 `hardware/` 下的模块文档（从现有 README 和源码注释提炼）
3. **Phase 2 — 指令集与数据类型**：完善 `instruction-set/` 和 `datatypes/`，这是使用 CUTE 的关键参考
4. **Phase 3 — 软件与测试**：整理测试框架文档，从 `cutetest/docs/` 迁移并扩充
5. **Phase 4 — 自动化与发布**：配置 CI 自动构建、部署 GitHub Pages、PDF 发布
