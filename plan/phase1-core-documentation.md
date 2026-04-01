# Phase 1 — 核心文档

## 方法论

本阶段采用 **自顶向下（Top-Down）** 与 **文档即设计（Documentation-as-Design）** 方法论：

- **自顶向下（Top-Down）**：从全局概述（overview/）开始，逐步细化到硬件子系统（hardware/）的各模块。读者先理解 CUTE 的整体定位和架构，再深入具体模块。写作顺序遵循 `overview → hardware/compute-engine → memory-system → control-logic → integration`。
- **文档即设计（Documentation-as-Design）**：设计文档不是代码的附属品，而是设计过程的产物。每个模块文档必须回答"为什么这样设计"，而不仅仅是"代码做了什么"。
- **内容模板标准化（Standardized Content Template）**：沿用香山的模块文档结构 — 术语 → 规格 → 功能描述 → 微架构设计 → 接口时序 → 参考 — 确保所有模块文档有统一的阅读预期。
- **从现有资料提炼（Extract & Refine）**：从 CUTE 源码中的 README、Chisel 注释、已有文档中提取信息，经过结构化整理后写入文档，避免从零开始。

---

## 整体框架进度

```
Phase 0 ─── [已完成] 框架搭建
Phase 1 ─── [当前阶段] 核心文档（overview/ + hardware/）
Phase 2 ─── 指令集与数据类型
Phase 3 ─── 软件与测试
Phase 4 ─── 自动化与发布
```

**当前进度：0%** — 目录骨架已由 Phase 0 搭建完成，所有 index.md 为占位页面，待填充实际内容。

完成后将达到：overview/ 全部完成、hardware/ 下 4 个子模块的核心文档完成（每个模块遵循标准化模板）、配套架构图和数据流图就位。

---

## 实施细节

### 步骤 1.1 — 项目概述文档（overview/）

**方法论：自顶向下 + 从现有资料提炼**

#### 1.1.1 `docs/index.md` — 首页

内容要点：

- CUTE 项目一句话定位（CPU 集成张量加速器）
- 快速导航链接到各主要章节
- 文档版本与维护信息

```markdown
# CUTE 设计文档

CUTE（CPU Unified Tensor Engine）是一个集成在 RISC-V 处理器中的张量加速器，用于高效执行矩阵运算。

## 快速导航

| 章节 | 说明 |
|---|---|
| [项目概述](overview/) | 背景、架构总览、快速上手 |
| [硬件设计](hardware/) | 计算引擎、存储系统、控制逻辑、集成方案 |
| [指令集](instruction-set/) | YGJK 指令编码与融合算子 |
| [数据类型](datatypes/) | 支持的精度格式与量化方案 |
| [软件与测试](software/) | 测试框架与基准测试 |

## 版本

- 文档版本：v0.1（初始版本）
- 对应 CUTE 源码版本：待标注
```

#### 1.1.2 `docs/overview/introduction.md` — 项目背景与目标

内容要点：
- CUTE 解决什么问题（AI 推理中的矩阵运算效率）
- CUTE 的核心定位（RoCC 协处理器，紧耦合于 CPU 流水线）
- 与同类方案（如 NVDLA、Gemmini）的差异
- 目标性能指标（如果有）

**信息来源：** CUTE 仓库根目录 README、论文/技术报告（如果有）。

#### 1.1.3 `docs/overview/architecture-overview.md` — 整体架构总览

内容要点：
- CUTE 在系统中的位置（CPU 核 + RoCC 接口 + CUTE 加速器）
- 顶层模块框图（使用 Mermaid 或 Draw.io 绘制）
- 四大子系统概览：计算引擎、存储系统、控制逻辑、接口集成
- 数据流全局路径：CPU 指令 → TaskController → 数据搬运 → MTE 计算 → 结果写回
- 关键参数总表（矩阵维度、数据位宽、存储容量等）

**图表产出：**
- `shared/figures/architecture/cute-top-level.svg` — 顶层架构图
- `shared/figures/architecture/cute-data-flow.mmd` — 全局数据流 Mermaid 源码

#### 1.1.4 `docs/overview/getting-started.md` — 快速上手指南

内容要点：
- 环境依赖（Java / SBT / Verilator / DRAMSim3）
- 克隆与编译命令
- 运行第一个测试
- 常见问题（FAQ）

**信息来源：** CUTE 仓库的 README 和 build 脚本。

---

### 步骤 1.2 — 硬件设计文档（hardware/）

**方法论：内容模板标准化 + 文档即设计**

每个子模块文档遵循统一模板：

```markdown
# {模块名称}

## 1. 术语说明
   本文档使用的关键术语定义
## 2. 设计规格
   - 参数配置表（位宽、深度、延迟等）
   - 接口信号列表（名称、方向、位宽、说明）
## 3. 功能描述
   模块的职责与行为描述
## 4. 微架构设计
   - 总体框图（使用 Draw.io 或 Mermaid）
   - 关键数据通路说明
   - 关键控制流说明
## 5. 数据类型支持
   该模块支持哪些精度格式
## 6. 接口时序
   使用 WaveDrom 描述关键接口时序
## 7. 与其他模块的交互
   上游/下游模块、数据流方向
## 8. 参考
   源码文件路径、相关论文/规范
```

---

#### 1.2.1 `docs/hardware/index.md` — 硬件设计导航

```markdown
# 硬件设计

CUTE 硬件设计分为以下子系统：

| 子系统 | 说明 | 详细文档 |
|---|---|---|
| 计算引擎 | MTE 阵列、ReducePE、后处理 | [compute-engine/](compute-engine/) |
| 存储系统 | Scratchpad、数据控制器、MMU | [memory-system/](memory-system/) |
| 控制逻辑 | TaskController、参数配置、接口 | [control-logic/](control-logic/) |
| 集成方案 | Rocket/BOOM/Shuttle 核集成 | [integration/](integration/) |
```

---

#### 1.2.2 `docs/hardware/compute-engine/` — 计算引擎

##### `mte.md` — Matrix Tensor Engine

**信息来源：** CUTE 源码中 MTE 相关的 Chisel 文件、README 中的架构描述。

需覆盖内容：

| 章节 | 关键内容 |
|---|---|
| 术语说明 | MTE、PE、MAC、Tile、Systolic Array |
| 设计规格 | 阵列维度（4×4）、数据位宽、流水级数、吞吐率 |
| 功能描述 | 矩阵乘法加速流程、分块（Tiling）策略 |
| 微架构设计 | PE 阵列结构、数据广播/移位路径、累加器组织 |
| 数据类型支持 | I8/FP16/BF16/TF32/FP8/FP4/MXFP 等的计算路径 |
| 接口时序 | 输入数据加载时序、计算启动/完成握手 |
| 模块交互 | 上游：Scratchpad A/B；下游：ReducePE / Scratchpad C |

**图表产出：**
- `shared/figures/microarch/mte-array.svg` — PE 阵列结构图
- `shared/figures/microarch/mte-data-path.svg` — 数据通路图
- `shared/figures/timing/mte-load-timing.json` — 数据加载时序（WaveDrom）

##### `reduce-pe.md` — ReducePE 运算单元

需覆盖内容：

| 章节 | 关键内容 |
|---|---|
| 术语说明 | ReducePE、MAC、累加、归约 |
| 设计规格 | 输入位宽、累加器位宽、支持的运算类型 |
| 功能描述 | MAC 运算、跨 PE 归约、后处理流水线 |
| 微架构设计 | ReducePE 内部结构、运算流水线 |
| 数据类型支持 | 各精度格式在 ReducePE 中的处理方式 |
| 模块交互 | 上游：MTE 输出；下游：AfterOps |

##### `after-ops.md` — 后处理操作

需覆盖内容：

| 章节 | 关键内容 |
|---|---|
| 术语说明 | 后处理、激活函数、缩放、量化 |
| 设计规格 | 支持的后处理操作列表 |
| 功能描述 | 每种后处理操作的行为 |
| 微架构设计 | 后处理流水线结构 |
| 模块交互 | 上游：ReducePE；下游：Scratchpad C 写回 |

---

#### 1.2.3 `docs/hardware/memory-system/` — 存储系统

##### `scratchpads.md` — A/B/C Scratchpad

| 章节 | 关键内容 |
|---|---|
| 设计规格 | 容量、位宽、端口数、Bank 结构 |
| 功能描述 | A/B Scratchpad（输入）和 C Scratchpad（输出/累加）的读写行为 |
| 微架构设计 | Bank 组织、地址映射、读写仲裁 |
| 接口时序 | 读写时序（WaveDrom） |

##### `scale-scratchpads.md` — Scale Factor Scratchpad

| 章节 | 关键内容 |
|---|---|
| 设计规格 | 容量、与 MXFP 等量化格式的对应关系 |
| 功能描述 | 缩放因子的存储与分发机制 |
| 模块交互 | 与 MTE 的缩放因子传递路径 |

##### `data-controllers.md` — 数据流控制器

| 章节 | 关键内容 |
|---|---|
| 功能描述 | 控制 Scratchpad 与 MTE 之间的数据搬运节奏 |
| 微架构设计 | 状态机、数据预取策略、双缓冲机制 |

##### `memory-loaders.md` — 内存加载器

| 章节 | 关键内容 |
|---|---|
| 功能描述 | 从主存加载矩阵数据到 Scratchpad |
| 微架构设计 | DMA 式加载、地址生成、突发传输 |

##### `local-mmu.md` — 本地内存管理单元

| 章节 | 关键内容 |
|---|---|
| 功能描述 | 地址翻译、内存映射 |
| 微架构设计 | TLB 或直接映射方案 |

---

#### 1.2.4 `docs/hardware/control-logic/` — 控制逻辑

##### `task-controller.md` — 指令译码与调度

| 章节 | 关键内容 |
|---|---|
| 术语说明 | TaskController、指令队列、RoCC opcode |
| 设计规格 | 指令队列深度、支持的自定义指令列表 |
| 功能描述 | 接收 RoCC 指令、译码、生成内部控制信号 |
| 微架构设计 | 指令解码器、状态机、与 MTE/存储系统的握手协议 |
| 接口时序 | RoCC 接口时序（WaveDrom） |

##### `cute-parameters.md` — 硬件参数配置

| 章节 | 关键内容 |
|---|---|
| 设计规格 | 所有可配置参数的列表、默认值、取值范围 |
| 功能描述 | 参数如何影响各模块的行为和资源使用 |

##### `cute2ygjk.md` — YGJK / RoCC 接口

| 章节 | 关键内容 |
|---|---|
| 术语说明 | YGJK、RoCC、Rocket Custom Coprocessor |
| 功能描述 | CUTE 如何通过 RoCC 接口与 CPU 核通信 |
| 微架构设计 | RoCC 接口信号、命令/响应通道 |
| 接口时序 | RoCC 命令/响应时序（WaveDrom） |

---

#### 1.2.5 `docs/hardware/integration/` — 集成方案

##### `rocket-core.md` — Rocket 核集成

| 章节 | 关键内容 |
|---|---|
| 功能描述 | CUTE 如何通过 RoCC 接口集成到 Rocket Chip |
| 集成步骤 | 配置文件修改、顶层连线 |
| 已知限制 | Rocket 核的约束（如 64-bit RoCC 接口限制） |

##### `boom-core.md` — BOOM 核集成

| 章节 | 关键内容 |
|---|---|
| 功能描述 | CUTE 与 BOOM 乱序核的集成方案 |
| 差异点 | 与 Rocket 集成的区别（乱序执行对 RoCC 的影响） |

##### `shuttle-core.md` — Shuttle 核集成

| 章节 | 关键内容 |
|---|---|
| 功能描述 | CUTE 与 Shuttle 核的集成方案 |
| 差异点 | 与 Rocket/BOOM 的差异 |

---

### 步骤 1.3 — 配套图表绘制

**方法论：文档即设计 — 图表是设计的核心表达**

需要绘制的图表清单：

| 图表 | 格式 | 存放路径 |
|---|---|---|
| CUTE 顶层架构图 | Draw.io → SVG | `shared/figures/architecture/cute-top-level.svg` |
| 全局数据流图 | Mermaid（内嵌） | `overview/architecture-overview.md` |
| MPE 阵列结构图 | Draw.io → SVG | `shared/figures/microarch/mte-array.svg` |
| MTE 数据通路图 | Draw.io → SVG | `shared/figures/microarch/mte-data-path.svg` |
| Scratchpad 组织图 | Draw.io → SVG | `shared/figures/microarch/scratchpad-org.svg` |
| RoCC 接口时序 | WaveDrom JSON | `shared/figures/timing/rocc-timing.json` |
| MTE 数据加载时序 | WaveDrom JSON | `shared/figures/timing/mte-load-timing.json` |

---

## 产出物

| 产出物 | 路径 | 页数估计 |
|---|---|---|
| 首页 | `docs/index.md` | 1 页 |
| 项目背景与目标 | `docs/overview/introduction.md` | 2-3 页 |
| 整体架构总览 | `docs/overview/architecture-overview.md` | 3-5 页 |
| 快速上手指南 | `docs/overview/getting-started.md` | 2-3 页 |
| 硬件设计导航 | `docs/hardware/index.md` | 1 页 |
| MTE 文档 | `docs/hardware/compute-engine/mte.md` | 5-8 页 |
| ReducePE 文档 | `docs/hardware/compute-engine/reduce-pe.md` | 3-5 页 |
| 后处理操作文档 | `docs/hardware/compute-engine/after-ops.md` | 2-3 页 |
| Scratchpad 文档 | `docs/hardware/memory-system/scratchpads.md` | 3-5 页 |
| 数据流控制器文档 | `docs/hardware/memory-system/data-controllers.md` | 2-3 页 |
| 内存加载器文档 | `docs/hardware/memory-system/memory-loaders.md` | 2-3 页 |
| TaskController 文档 | `docs/hardware/control-logic/task-controller.md` | 3-5 页 |
| YGJK 接口文档 | `docs/hardware/control-logic/cute2ygjk.md` | 3-5 页 |
| 集成方案文档 | `docs/hardware/integration/*.md` | 各 2-3 页 |
| 配套图表 | `docs/shared/figures/` | 7+ 张 |

---

## 依赖与风险

| 项目 | 说明 |
|---|---|
| **依赖：CUTE 源码** | 需要访问 CUTE 的 Chisel 源码以提取设计规格和接口信息 |
| **依赖：Phase 0 完成** | 目录骨架和构建工具必须已就绪 |
| **风险：信息不完整** | 部分模块可能缺少详细的 Chisel 注释，需要与开发者确认 |
| **风险：图表工具选择** | Draw.io 需要手动绘制，耗时较长；可先用 Mermaid 草图替代，后续替换为正式矢量图 |
