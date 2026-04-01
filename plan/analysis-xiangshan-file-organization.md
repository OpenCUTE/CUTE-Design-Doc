# 香山设计文档仓库 — 文件组织深度分析

> 基于 `/root/opencute/XiangShan-Design-Doc` 仓库的完整源码分析，提炼其文件组织方法论。

---

## 一、仓库全貌

### 1.1 顶层目录一览

```
XiangShan-Design-Doc/
├── .github/                 # CI/CD 与社区协作
│   ├── ISSUE_TEMPLATE/      #   Issue 模板（文档 Bug 报告、问题引导）
│   └── workflows/           #   GitHub Actions 工作流
├── docs/                    # 文档源文件（仓库核心）
│   ├── zh/                  #   中文文档（~128 个 .md）
│   ├── en/                  #   英文文档（~128 个 .md，翻译中）
│   └── shared/              #   中英文共享资源
├── tools/                   # 构建 / 质量工具
│   └── lint/                #   Markdown lint 容器化环境
├── utils/                   # Git 子模块：docs-utils（构建基础设施）
├── mkdocs.yml               # MkDocs 入口（环境变量分发）
├── mkdocs-zh.yml            # 中文站点配置（继承 base）
├── mkdocs-en.yml            # 英文站点配置（继承 base）
├── Makefile                 # PDF/HTML 构建脚本
├── .readthedocs.yaml        # ReadTheDocs 部署
├── .markdownlint.yml        # Markdown 格式规范
├── README.md / README.zh.md # 仓库说明
└── LICENSE                  # CC BY 4.0
```

**规模**：312 个 Markdown 文件、236+ 张图片（SVG/PNG/DrawIO/DOT）、12+ 配置文件。

### 1.2 核心目录 `docs/` 的完整结构

```
docs/
├── zh/                              # 中文文档（主语言）
│   ├── index.md                     # 总览与导航页
│   ├── pandoc-main-zh.md            # Pandoc 入口文件
│   ├── variables-zh.yml             # 中文变量（版本号、处理器名）
│   │
│   ├── frontend/                    # ── 前端子系统 ──
│   │   ├── index.md
│   │   ├── BPU/                     # 分支预测单元
│   │   │   ├── index.md             #   模块导航（术语→规格→功能描述）
│   │   │   ├── Composer.md          #   BPU 抽象模块
│   │   │   ├── FTB.md              #   取指目标缓冲
│   │   │   ├── uFTB.md             #   微取指目标缓冲
│   │   │   ├── TAGE-SC.md          #   主预测器
│   │   │   ├── ITTAGE.md           #   间接跳转预测器
│   │   │   └── RAS.md              #   返回地址栈
│   │   ├── FTQ/                     # 取指目标队列
│   │   │   └── index.md
│   │   ├── IFU/                     # 取指单元
│   │   │   ├── index.md
│   │   │   └── PreDecoder.md
│   │   ├── ICache/                  # 指令缓存
│   │   │   ├── index.md
│   │   │   ├── MainPipe.md
│   │   │   ├── IPrefetchPipe.md
│   │   │   ├── WayLookup.md
│   │   │   ├── MissUnit.md
│   │   │   ├── Replacer.md
│   │   │   └── CtrlUnit.md
│   │   ├── Pruned_Address/          # PC 类
│   │   │   └── index.md
│   │   └── figure/                  # 前端子系统图片
│   │       └── *.svg / *.png
│   │
│   ├── backend/                     # ── 后端子系统 ──
│   │   ├── index.md                 # 后端整体介绍（含架构框图）
│   │   ├── CtrlBlock/               # 控制模块
│   │   │   ├── index.md
│   │   │   ├── decode.md
│   │   │   ├── Rename.md
│   │   │   ├── Dispatch.md
│   │   │   └── Rob.md
│   │   ├── DataPath/                # 数据通路
│   │   │   ├── DataPath.md
│   │   │   ├── Og2ForVector.md
│   │   │   ├── WbDataPath.md
│   │   │   ├── WbFuBusyTable.md
│   │   │   └── BypassNetwork.md
│   │   ├── Schedule_And_Issue/      # 调度与发射
│   │   │   ├── Scheduler.md
│   │   │   ├── IssueQueue.md
│   │   │   └── IssueQueueEntries.md
│   │   ├── ExuBlock/               # 执行块
│   │   │   ├── ExuBlock.md
│   │   │   └── ExuUnit.md
│   │   ├── FunctionUnit/           # 功能单元
│   │   │   ├── IntFunctionUnit.md
│   │   │   ├── FpFunctionUnit.md
│   │   │   ├── VecFunctionUnit.md
│   │   │   └── MemFunctionUnit.md
│   │   ├── VFPU.md                 # 向量浮点功能单元
│   │   ├── CSR.md                  # 控制状态寄存器
│   │   ├── HPM.md                  # 硬件性能计数器
│   │   └── DebugModule/            # 调试模块
│   │       └── DM.md
│   │
│   ├── memblock/                    # ── 访存子系统 ──
│   │   ├── LSU/                     # 访存流水线
│   │   │   ├── index.md
│   │   │   ├── LoadUnit.md
│   │   │   ├── StoreUnit.md
│   │   │   ├── StdExeUnit.md
│   │   │   ├── AtomicsUnit.md
│   │   │   ├── VLSU/               # 向量访存
│   │   │   │   ├── index.md
│   │   │   │   ├── VLSplit.md
│   │   │   │   ├── VSSplit.md
│   │   │   │   ├── VLMergeBuffer.md
│   │   │   │   ├── VSMergeBuffer.md
│   │   │   │   ├── VSegmentUnit.md
│   │   │   │   └── VfofBuffer.md
│   │   │   ├── LSQ/                # 访存队列
│   │   │   │   ├── index.md
│   │   │   │   ├── VirtualLoadQueue.md
│   │   │   │   ├── LoadQueueRAR.md
│   │   │   │   ├── LoadQueueRAW.md
│   │   │   │   ├── LoadQueueReplay.md
│   │   │   │   ├── LoadQueueUncache.md
│   │   │   │   ├── LqExceptionBuffer.md
│   │   │   │   └── StoreQueue.md
│   │   │   ├── Uncache.md
│   │   │   ├── SBuffer.md
│   │   │   ├── LoadMisalignBuffer.md
│   │   │   └── StoreMisalignBuffer.md
│   │   ├── DCache/                 # 数据缓存
│   │   │   ├── index.md
│   │   │   ├── LoadPipe.md
│   │   │   ├── MissQueue.md
│   │   │   ├── ProbeQueue.md
│   │   │   ├── MainPipe.md
│   │   │   ├── WritebackQueue.md
│   │   │   └── Error.md
│   │   └── MMU/                    # 内存管理单元
│   │       ├── index.md
│   │       ├── L1TLB.md
│   │       ├── Repeater.md
│   │       ├── L2TLB/
│   │       │   ├── index.md
│   │       │   ├── PageCache.md
│   │       │   ├── PTW.md
│   │       │   ├── LLPTW.md
│   │       │   ├── HPTW.md
│   │       │   ├── MissQueue.md
│   │       │   └── Prefetcher.md
│   │       └── PMP-PMA.md
│   │
│   └── cache/                       # ── 缓存子系统 ──
│       └── l2cache/
│           ├── CoupledL2.md
│           ├── ReqBuf.md
│           ├── ReqArb_MainPipe.md
│           ├── Directory.md
│           ├── DataStorage.md
│           ├── MSHR.md
│           ├── upstream/            # 上游 TileLink 通道
│           │   ├── SinkA.md
│           │   ├── SinkC.md
│           │   └── GrantBuffer.md
│           ├── downstream/          # 下游 CHI 通道
│           │   ├── TXREQ.md
│           │   ├── RXRSP.md
│           │   ├── RXDAT.md
│           │   ├── RXSNP.md
│           │   ├── TXDAT.md
│           │   ├── TXRSP.md
│           │   ├── PCredit.md
│           │   └── LinkMonitor.md
│           ├── MMIOBridge.md
│           └── Error.md
│
├── en/                              # 英文文档（结构完全镜像 zh/）
│   └── ...                          # （与 zh/ 一一对应）
│
├── shared/                          # 中英文共享资源
│   ├── backend/
│   ├── cache/
│   ├── frontend/
│   └── memblock/
│
├── variables-en.yml                 # 英文变量
└── variables-zh.yml                 # 中文变量（根级副本）
```

---

## 二、组织方法论

### 2.1 方法论一：硬件模块同构映射

**原则**：目录结构 1:1 映射处理器的物理模块层次。

香山是一个超标量乱序 RISC-V 处理器，其微架构自然分为四大子系统：

```
香山处理器
├── Frontend（前端）     →  docs/zh/frontend/
├── Backend（后端）      →  docs/zh/backend/
├── MemBlock（访存）     →  docs/zh/memblock/
└── Cache（缓存子系统）  →  docs/zh/cache/
```

每一级子目录继续映射子模块：

```
Frontend（前端）
├── BPU（分支预测单元）  →  frontend/BPU/
├── FTQ（取指目标队列）  →  frontend/FTQ/
├── IFU（取指单元）      →  frontend/IFU/
├── ICache（指令缓存）   →  frontend/ICache/
└── Pruned Address       →  frontend/Pruned_Address/
```

BPU 内部继续细分：

```
BPU（分支预测单元）
├── Composer    →  BPU 抽象模块
├── FTB         →  取指目标缓冲
├── uFTB        →  微取指目标缓冲
├── TAGE-SC     →  主预测器
├── ITTAGE      →  间接跳转预测器
└── RAS         →  返回地址栈
```

**价值**：工程师阅读文档时，心智模型与代码仓库结构完全一致。找文档 = 找模块。

### 2.2 方法论二：统一内容模板

**原则**：每个模块文档遵循统一的章节模板，形成稳定的阅读预期。

以 `docs/zh/frontend/BPU/index.md` 为例，其典型结构为：

```markdown
# 模块名称（如：昆明湖 BPU 模块文档）

## 术语说明
| 缩写 | 全称 | 描述 |
| BPU  | Branch Prediction Unit | 分支预测单元 |
...

## 设计规格
1. 支持一次生成一个分支预测块...
2. 支持无空泡的简单预测...
...

## 功能描述
### 功能概述
### 子功能1
### 子功能2
...

## 总体设计
（架构框图 + 设计思路 + 关键通路）

## 参考文档
```

再以 `docs/zh/backend/index.md` 为例，子系统级文档的结构为：

```markdown
# 后端整体介绍

（开篇即引用架构框图）
![后端整体框架](figure/backend.svg){#fig:backend-overall}

## 基本技术规格
- 6 宽度译码、重命名、分派
- 160 项 ROB
...

（然后通过子模块列表导航到下一级）
```

**模板变体**：根据模块复杂度有三级变体——

| 层级 | 模板 | 示例 |
|---|---|---|
| 子系统级 | 概述 + 技术规格 + 子模块导航 | `backend/index.md` |
| 模块级 | 术语 → 规格 → 功能 → 设计 → 接口 | `BPU/index.md`, `ICache/index.md` |
| 子模块级 | 单一功能深度描述 | `MainPipe.md`, `TAGE-SC.md` |

### 2.3 方法论三：图片就近存放

**原则**：每个子系统的图片放在该子系统目录内的 `figure/` 子目录。

```
docs/zh/
├── frontend/
│   └── figure/          # 前端子系统图片
│       └── backend.svg
├── backend/
│   └── figure/          # 后端子系统图片
│       └── backend.svg
├── memblock/
│   └── ...              # 各模块图片就近存放
└── cache/
    └── ...
```

在 Markdown 中使用相对路径引用：

```markdown
![后端整体框架](figure/backend.svg){#fig:backend-overall}
```

**价值**：移动、重命名模块目录时，图片跟随移动，不会出现断链。

### 2.4 方法论四：中英双语完全镜像

**原则**：`docs/zh/` 和 `docs/en/` 保持完全一致的目录结构和文件名。

```
docs/
├── zh/
│   ├── frontend/BPU/TAGE-SC.md     # 中文
│   └── memblock/LSU/LoadUnit.md
├── en/
│   ├── frontend/BPU/TAGE-SC.md     # 英文（同名、同路径）
│   └── memblock/LSU/LoadUnit.md
└── shared/                          # 共享资源（避免重复）
```

**实现机制**：

1. **独立 MkDocs 配置**：`mkdocs-zh.yml` 的 `docs_dir: 'docs/zh'`，`mkdocs-en.yml` 的 `docs_dir: 'docs/en'`
2. **独立导航定义**：两个配置文件各自维护 `nav:` 部分，中文用中文名，英文用英文名
3. **共享资源**：`docs/shared/` 放中英文共用的图片等资源
4. **翻译管理**：通过 [Weblate](https://hosted.weblate.org/engage/openxiangshan/) 平台协作翻译

导航对比示例：

```yaml
# mkdocs-zh.yml
nav:
  - 前端:
    - 分支预测单元:
      - frontend/BPU/index.md
      - 主预测器TAGE-SC: frontend/BPU/TAGE-SC.md

# mkdocs-en.yml
nav:
  - Frontend:
    - Branch Prediction Unit:
      - frontend/BPU/index.md
      - Main Predictor TAGE-SC: frontend/BPU/TAGE-SC.md
```

### 2.5 方法论五：变量外部化

**原则**：版本号、项目名等可变信息集中到 YAML 变量文件，文档中用占位符引用。

```yaml
# docs/variables-zh.yml
replace_variables:
  processor_name: "昆明湖 V2R2"
```

在 Markdown 中：

```markdown
# {{processor_name}} BPU 模块文档
```

构建时由 Pandoc Lua 过滤器或 MkDocs Python 扩展自动替换。当处理器版本从 V2R2 升级到 V2R3 时，只需修改一处 YAML。

### 2.6 方法论六：index.md 作为模块入口

**原则**：每个目录下都有 `index.md`，充当该模块的导航页和概述。

`index.md` 承担两种角色：

1. **导航枢纽**：列出子模块链接，像目录页
2. **概述文档**：提供该模块的整体介绍、术语表、设计规格

示例（`frontend/BPU/index.md` 的结构）：

```markdown
# 昆明湖 BPU 模块文档

## 术语说明       ← 对 BPU 相关缩写的统一定义
## 设计规格       ← BPU 的功能规格列表
## 功能描述       ← 详细功能说明
### 功能概述
### 分支预测块生成
### meta 信息生成
...
```

子模块文档（如 `TAGE-SC.md`）则通过 MkDocs 导航直接链接。

### 2.7 方法论七：配置与内容分离

**原则**：构建配置、主题定制、过滤器和文档内容严格分离。

```
仓库根目录
├── mkdocs.yml              # 仅 1 行：环境变量分发
├── mkdocs-zh.yml           # 中文配置（docs_dir、nav、theme）
├── mkdocs-en.yml           # 英文配置
├── Makefile                # PDF 构建脚本
├── .readthedocs.yaml       # 部署配置
│
├── docs/                   # 纯内容（Markdown + 图片）
│   ├── zh/                 #   不含构建配置
│   ├── en/                 #   不含构建配置
│   └── shared/             #   不含构建配置
│
├── tools/lint/             # 质量工具（独立于内容）
└── utils/                  # 构建基础设施（Git 子模块，独立仓库）
    ├── mkdocs-base.yml     #   共享 MkDocs 配置
    ├── pandoc_filters/     #   Lua 过滤器
    ├── mdx_extensions/     #   Python Markdown 扩展
    ├── custom_theme/       #   主题定制
    ├── template.tex        #   LaTeX 模板
    └── requirements.txt    #   依赖
```

**`mkdocs.yml` 的分发机制**（仅 1 行）：

```yaml
INHERIT: !ENV [MKDOCS_YML_FILE, "mkdocs-zh.yml"]
```

ReadTheDocs 通过环境变量 `MKDOCS_YML_FILE` 选择构建中文还是英文。本地开发时直接指定配置文件：

```bash
mkdocs serve -f mkdocs-zh.yml    # 中文预览
mkdocs serve -f mkdocs-en.yml    # 英文预览
```

### 2.8 方法论八：Git 子模块管理构建工具链

**原则**：将构建基础设施（docs-utils）抽为独立 Git 子模块。

```
# .gitmodules
[submodule "utils"]
    path = utils
    url = https://github.com/OpenXiangShan/docs-utils.git
```

`utils/` 包含：

| 内容 | 说明 |
|---|---|
| `mkdocs-base.yml` | 两个语言站点共享的基础配置 |
| `custom_theme/` | Material 主题定制（CSS、JS、HTML partial） |
| `mdx_extensions/` | 6 个 Python Markdown 扩展 |
| `pandoc_filters/` | 3 个 Lua 过滤器 |
| `template.tex` | LaTeX 排版模板 |
| `dependency.sh` | Pandoc + LaTeX 环境安装脚本 |
| `Dockerfile` | 容器化构建环境 |
| `requirements.txt` | Python 依赖 |

**价值**：
- 多个文档仓库（User Guide、Design Doc 等）可复用同一套工具链
- 工具链更新只需推一个子模块，各仓库 `git submodule update` 即可同步
- 版本锁定：子模块指向特定 commit，保证构建可复现

### 2.9 方法论九：社区协作基础设施

**原则**：通过 Issue 模板和 CI 流水线降低协作门槛。

**Issue 模板**（`.github/ISSUE_TEMPLATE/document-bug.yml`）：

结构化的文档 Bug 报告表单，包含：

- **预检清单**：是否已阅读贡献指南、是否已搜索已有 Issue
- **文档元数据**：语言（中/英）、格式（Web/PDF）、版本（tag/commit）
- **定位信息**：章节层级、源文件路径
- **问题分类**：错别字 / 格式 / 翻译 / 链接失效 / 技术错误 / 其他
- **描述与建议**：问题描述、截图、建议修正

**`config.yml`** 将非文档类问题引导到主仓库：

```yaml
contact_links:
  - name: XiangShan Processor Question / Problem
    url: https://github.com/OpenXiangShan/XiangShan/issues
```

---

## 三、导航体系分析

### 3.1 三级导航设计

香山在 `mkdocs-zh.yml` 中定义了完整的三级导航（共 155 行）：

```
一级（Tab 标签）    二级（侧栏分组）         三级（具体页面）
───────────────    ────────────────         ──────────────
首页               —                        index.md
前端               分支预测单元              BPU/index.md
                                            Composer.md
                                            FTB.md
                                            uFTB.md
                                            TAGE-SC.md
                                            ITTAGE.md
                                            RAS.md
                   取指目标队列              FTQ/index.md
                   取指令单元                IFU/index.md
                                            PreDecoder.md
                   指令缓存                  ICache/index.md
                                            MainPipe.md
                                            ...
后端               控制模块 CtrlBlock        CtrlBlock/index.md
                                            decode.md
                                            Rename.md
                                            ...
                   数据通路 DataPath         DataPath.md
                                            ...
                   调度与发射                Scheduler.md
                                            IssueQueue.md
                   执行                     ExuBlock.md
                   功能单元                  IntFunctionUnit.md
                                            FpFunctionUnit.md
                                            ...
访存               访存流水线 LSU            LSU/index.md
                                            LoadUnit.md
                                            ...
                   向量访存                  VLSU/index.md
                                            ...
                   访存队列 LSQ             LSQ/index.md
                                            ...
                   数据缓存                  DCache/index.md
                                            ...
                   内存管理单元 MMU          MMU/index.md
                                            ...
缓存子系统          二级缓存                 CoupledL2.md
                                            ...
```

**设计特点**：
- 一级标签对应四大子系统，与目录结构完全一致
- 二级分组对应子模块，使用"中文名（英文名）"格式
- 三级页面既包含导航页 `index.md`，也包含详细设计页

### 3.2 交叉引用机制

文档内部使用 Pandoc-crossref 语法进行交叉引用：

```markdown
![后端整体框架](figure/backend.svg){#fig:backend-overall}

如 [@fig:backend-overall] 所示...
```

- 图片：`![描述](路径){#fig:标签}` 定义，`[@fig:标签]` 引用
- 表格：`Table: 标题 {#tbl:标签}` 定义，`[@tbl:标签]` 引用
- 章节：`### 标题 {#sec:标签}` 定义，`[@sec:标签]` 引用

这些语法同时被 MkDocs（通过 Python 扩展 `crossref.py`）和 Pandoc（通过 `pandoc-crossref` 过滤器）支持，实现网站和 PDF 的统一。

---

## 四、方法论总结

| # | 方法论 | 核心做法 | 解决的问题 |
|---|---|---|---|
| 1 | 硬件模块同构映射 | 目录 = 模块层次 | 代码与文档导航一致 |
| 2 | 统一内容模板 | 术语→规格→功能→设计 | 阅读预期稳定，多人协作风格统一 |
| 3 | 图片就近存放 | `figure/` 跟随模块 | 防止移动目录时断链 |
| 4 | 中英双语镜像 | `zh/` 和 `en/` 结构一致 | 翻译可追踪、可自动化 |
| 5 | 变量外部化 | YAML 变量 + `{{placeholder}}` | 版本升级一处修改 |
| 6 | index.md 入口 | 每个目录有导航+概述页 | 快速定位模块文档 |
| 7 | 配置与内容分离 | 构建配置在根目录，内容在 `docs/` | 职责清晰，不影响写作者 |
| 8 | 子模块管理工具链 | `utils/` Git 子模块 | 多仓库复用、版本锁定 |
| 9 | 社区协作基础设施 | Issue 模板 + 自动化 CI | 降低外部贡献者参与门槛 |

**一句话总结**：香山的文件组织遵循"**结构映射硬件、模板统一风格、配置分离内容、工具链独立维护**"四大原则，形成了一套可扩展、可维护、多人协作的硬件设计文档工程体系。
