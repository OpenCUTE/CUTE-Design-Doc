# Phase 2 — 指令集与数据类型

## 方法论

本阶段采用 **接口契约优先（Interface Contract First）** 与 **类型系统驱动（Type-System-Driven）** 方法论：

- **接口契约优先（Interface Contract First）**：指令集是软件与硬件之间的契约。文档必须精确定义每条指令的编码格式、语义、约束条件，使其成为软硬件协作的唯一权威参考。任何歧义都可能导致功能错误，因此文档需要达到 ISA 规范级别的严谨性。
- **类型系统驱动（Type-System-Driven）**：CUTE 支持 13 种数据类型，形成了一个复杂的类型系统。文档需要以"类型 → 编码 → 硬件支持 → 软件使用"的线索组织，使读者能从任意维度查找到所需信息。
- **表格驱动参考（Table-Driven Reference）**：指令速查表和数据类型支持矩阵是高频查阅资料，需要设计为可快速检索的表格格式，辅以示例说明。
- **交叉引用一致性（Cross-Reference Consistency）**：指令集文档与数据类型文档之间存在大量交叉引用（如指令支持哪些数据类型），需要通过 MkDocs 的内部链接机制确保引用一致。

---

## 整体框架进度

```
Phase 0 ─── [已完成] 框架搭建
Phase 1 ─── [已完成] 核心文档（overview/ + hardware/）
Phase 2 ─── [当前阶段] 指令集与数据类型
Phase 3 ─── 软件与测试
Phase 4 ─── 自动化与发布
```

**当前进度：0%** — Phase 1 完成了硬件子系统文档，但指令集和数据类型的专门文档尚未开始。

完成后将达到：`instruction-set/` 和 `datatypes/` 两个目录的文档全部完成，形成 CUTE 的完整 API 参考手册。

---

## 实施细节

### 步骤 2.1 — 指令集文档（instruction-set/）

**方法论：接口契约优先**

#### 2.1.1 `docs/instruction-set/index.md` — 指令集导航

```markdown
# 指令集

CUTE 通过 YGJK 自定义指令集扩展 RISC-V ISA，提供矩阵运算加速指令。

## 文档结构

| 文档 | 说明 |
|---|---|
| [指令编码](instruction-encoding.md) | YGJK 指令的编码格式与字段定义 |
| [融合算子](fusion-operators.md) | 多指令融合的高级算子说明 |
| [指令速查表](instruction-reference.md) | 所有指令的一览表与快速参考 |
```

#### 2.1.2 `docs/instruction-set/instruction-encoding.md` — YGJK 指令编码

**信息来源：** CUTE 源码中的指令定义文件、YGJK 规范文档。

内容结构：

```markdown
# YGJK 指令编码

## 1. 概述
   - YGJK 扩展的设计目标
   - 基于 RISC-V 自定义指令的编码空间
   - 与 RoCC opcode 的映射关系

## 2. 编码格式
   - R-type 指令格式（寄存器-寄存器操作）
   - I-type 指令格式（立即数操作）
   - 每种格式的字段划分图

   示例：
   | 31-25 | 24-20 | 19-15 | 14-12 | 11-7 | 6-0 |
   |-------|-------|-------|-------|------|-----|
   | funct7| rs2   | rs1   | funct3| rd   | opcode |

## 3. 指令分类
   按功能分组：
   - **数据搬运类**：Load/Store 矩阵数据
   - **计算类**：矩阵乘法、归约、后处理
   - **配置类**：设置参数、数据类型、矩阵维度
   - **控制类**：同步、状态查询

## 4. 每条指令的详细描述
   对每条指令提供：

   ### 指令名称

   **编码：**
   ```
   [二进制编码图]
   ```

   **格式：** `instruction rd, rs1, rs2`

   **语义：** 该指令执行的操作描述

   **约束条件：**
   - 寄存器约束
   - 对齐要求
   - 数据类型要求

   **示例：**
   ```asm
   # 示例代码
   ```

   **异常：** 可能触发的异常
```

**图表产出：**
- `shared/figures/architecture/encoding-layout.svg` — 指令编码字段布局图

#### 2.1.3 `docs/instruction-set/fusion-operators.md` — 融合算子

**方法论：接口契约优先 — 融合算子是多条指令的语义组合，需要精确定义**

内容结构：

```markdown
# 融合算子

## 1. 概述
   - 什么是融合算子（Fusion Operator）
   - 为什么需要指令融合（减少 RoCC 交互开销、提高吞吐）
   - 融合算子与单条指令的关系

## 2. 支持的融合算子列表
   表格形式列出所有融合算子：

   | 算子名称 | 组成指令 | 数据类型 | 功能描述 |
   |---------|---------|---------|---------|
   | ...     | ...     | ...     | ...     |

## 3. 每个融合算子的详细说明
   对每个融合算子：

   ### 算子名称

   **语义：** 该算子执行的完整操作流程

   **指令序列：**
   ```asm
   # 组成该算子的指令序列
   ```

   **数据流图：**（Mermaid）
   ```mermaid
   graph LR
       A[Load A] --> C[MTE]
       B[Load B] --> C
       C --> D[Reduce]
       D --> E[Store C]
   ```

   **性能说明：** 相比单条指令的加速比
```

#### 2.1.4 `docs/instruction-set/instruction-reference.md` — 指令速查表

**方法论：表格驱动参考**

```markdown
# 指令速查表

## 完整指令列表

| 指令 | 格式 | funct3 | funct7 | 语义 | 支持数据类型 |
|------|------|--------|--------|------|-------------|
| ...  | ...  | ...    | ...    | ...  | ...         |

## 按功能分类索引

### 数据搬运
- `CUTE.LOAD.*` — 加载矩阵数据
- `CUTE.STORE.*` — 存储矩阵数据

### 计算
- `CUTE.MAC.*` — 矩阵乘加
- ...

## 按数据类型索引

| 数据类型 | 支持的指令 |
|---------|-----------|
| I8      | ...       |
| FP16    | ...       |
| ...     | ...       |
```

---

### 步骤 2.2 — 数据类型文档（datatypes/）

**方法论：类型系统驱动**

#### 2.2.1 `docs/datatypes/index.md` — 数据类型导航

```markdown
# 数据类型

CUTE 支持多达 13 种数据类型，覆盖从低精度整数到高精度浮点的广泛范围。

| 文档 | 说明 |
|------|------|
| [精度格式总览](precision-formats.md) | 所有支持的数据类型编码与格式 |
| [量化与 Block-Scale](quantization.md) | 量化机制与缩放因子 |
| [数据类型支持矩阵](datatype-support.md) | 各模块对各数据类型的支持情况 |
```

#### 2.2.2 `docs/datatypes/precision-formats.md` — 精度格式总览

**信息来源：** CUTE 源码中的数据类型定义、相关论文（如 MXFP 规范）。

内容结构：

```markdown
# 精度格式总览

## 1. 概述
   - CUTE 数据类型体系的设计目标
   - 为什么需要支持这么多精度格式
   - 精度 vs 性能 vs 面积的权衡

## 2. 整数类型

### INT8 (I8)
   - 编码格式（符号位、数值范围）
   - 在 MTE 中的使用方式
   - 适用场景

## 3. 标准浮点类型

### FP16 (IEEE 754 半精度)
   - 编码格式（S/E/M 位划分）
   - 特殊值处理（NaN/Inf/Subnormal）

### BF16 (Brain Float)
   - 编码格式
   - 与 FP16 的区别及选择建议

### TF32
   - 编码格式
   - 使用场景

### FP32 (用于累加)
   - 累加器位宽说明

## 4. 低精度浮点类型

### FP8 (E4M3 / E5M2)
   - 两种 FP8 变体的编码与差异
   - 在矩阵乘法中的使用方式

### FP4
   - 编码格式
   - 适用场景与精度损失评估

## 5. 块缩放类型

### MXFP (Microscaling FP)
   - MXFP 的设计原理
   - 块大小、缩放因子编码
   - 与其他低精度格式的对比

## 6. 数据类型对比总表

| 类型 | 总位宽 | 指数位 | 尾数位 | 范围 | 精度 | 适用场景 |
|------|--------|--------|--------|------|------|---------|
| I8   | 8      | -      | -      | -128~127 | 1 | 量化推理 |
| FP16 | 16     | 5      | 10     | ... | ... | 训练/推理 |
| BF16 | 16     | 8      | 7      | ... | ... | 训练 |
| ...  | ...    | ...    | ...    | ... | ... | ...     |
```

**图表产出：**
- `shared/figures/architecture/datatype-bit-layout.svg` — 各类型的位宽分布对比图

#### 2.2.3 `docs/datatypes/quantization.md` — 量化与 Block-Scale

**方法论：类型系统驱动 — 量化是连接高精度和低精度的桥梁**

```markdown
# 量化与 Block-Scale

## 1. 量化概述
   - 为什么需要量化（模型压缩、计算加速）
   - CUTE 的量化策略概述

## 2. 缩放因子（Scale Factor）
   - 缩放因子的计算方式
   - 缩放因子在硬件中的表示
   - Scale Factor Scratchpad 的组织

## 3. Block-Scale 机制
   - Block-Scale 的原理
   - 块大小（Block Size）的配置
   - 逐块缩放 vs 逐张量缩放

## 4. 量化流程
   数据流：
   原始数据 → 量化 → 存储 → 反量化（可选）

   ```mermaid
   graph TD
       A[FP32/BF16 输入] --> B[量化器]
       B --> C[INT8/FP8/FP4 存储]
       C --> D[MTE 计算]
       D --> E[FP32 累加]
       E --> F[可选：反量化输出]
   ```

## 5. MXFP 量化详解
   - MXFP 的块缩放编码
   - 与传统量化的差异
```

#### 2.2.4 `docs/datatypes/datatype-support.md` — 数据类型支持矩阵

**方法论：表格驱动参考 + 交叉引用一致性**

```markdown
# 数据类型支持矩阵

## 各模块支持的数据类型

### MTE（计算引擎）

| 数据类型 | 输入 A | 输入 B | 累加 | 输出 C | 说明 |
|---------|--------|--------|------|--------|------|
| I8      | ✓      | ✓      | I32  | I32    | ...  |
| FP16    | ✓      | ✓      | FP32 | FP32   | ...  |
| BF16    | ✓      | ✓      | FP32 | FP32   | ...  |
| TF32    | ✓      | ✓      | FP32 | FP32   | ...  |
| FP8 E4M3| ✓      | ✓      | FP32 | FP32   | ...  |
| FP8 E5M2| ✓      | ✓      | FP32 | FP32   | ...  |
| FP4     | ✓      | ✓      | FP32 | FP32   | ...  |
| MXFP    | ✓      | ✓      | FP32 | FP32   | ...  |

### ReducePE

| 数据类型 | 输入 | 输出 | 支持的操作 |
|---------|------|------|-----------|
| ...     | ...  | ...  | ...       |

### AfterOps

| 后处理操作 | 支持的输入类型 | 输出类型 |
|-----------|--------------|---------|
| ...       | ...          | ...     |

### Scratchpad 存储

| 数据类型 | A Scratchpad | B Scratchpad | C Scratchpad | Scale Scratchpad |
|---------|-------------|-------------|-------------|-----------------|
| ...     | ...         | ...         | ...         | ...             |

## 数据类型兼容性规则

- 哪些输入类型组合是合法的
- 累加器类型的选择规则
- 类型转换的硬件路径
```

---

### 步骤 2.3 — 交叉引用与一致性检查

**方法论：交叉引用一致性**

确保以下交叉引用正确：

| 来源 | 引用目标 | 检查项 |
|------|---------|--------|
| 指令速查表中的"支持数据类型"列 | `precision-formats.md` | 链接正确，类型名称一致 |
| `datatype-support.md` 中的指令引用 | `instruction-encoding.md` | 指令名称一致 |
| `fusion-operators.md` 中的组成指令 | `instruction-reference.md` | 指令编码匹配 |
| 硬件文档中的接口描述 | 指令集文档 | 信号名与指令字段对应 |

**检查方式：**
1. MkDocs 的 `mkdocs build --strict` 会检查内部链接
2. `markdown-link-check` 检查所有链接有效性
3. 人工审查关键表格的一致性

---

## 产出物

| 产出物 | 路径 | 页数估计 |
|---|---|---|
| 指令集导航 | `docs/instruction-set/index.md` | 1 页 |
| 指令编码文档 | `docs/instruction-set/instruction-encoding.md` | 8-12 页 |
| 融合算子文档 | `docs/instruction-set/fusion-operators.md` | 4-6 页 |
| 指令速查表 | `docs/instruction-set/instruction-reference.md` | 3-4 页 |
| 数据类型导航 | `docs/datatypes/index.md` | 1 页 |
| 精度格式总览 | `docs/datatypes/precision-formats.md` | 6-8 页 |
| 量化与 Block-Scale | `docs/datatypes/quantization.md` | 4-6 页 |
| 数据类型支持矩阵 | `docs/datatypes/datatype-support.md` | 3-4 页 |
| 编码布局图 | `shared/figures/architecture/encoding-layout.svg` | — |
| 数据类型位宽图 | `shared/figures/architecture/datatype-bit-layout.svg` | — |

---

## 依赖与风险

| 项目 | 说明 |
|---|---|
| **依赖：Phase 1 完成** | 硬件模块文档为指令集文档提供硬件上下文 |
| **依赖：YGJK 规范** | 需要完整的 YGJK 指令集规范文档或源码定义 |
| **依赖：CUTE 源码** | 数据类型定义和指令译码逻辑在源码中 |
| **风险：规范不完整** | 如果 YGJK 没有独立的规范文档，需要从源码反向工程指令编码 |
| **风险：数据类型数量多** | 13 种数据类型的文档工作量较大，可优先完成常用类型（I8/FP16/BF16/FP8），其余后续补充 |
