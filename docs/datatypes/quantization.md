# 量化与 Block-Scale

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| Scale Factor | 缩放因子，用于将低精度数值恢复到原始精度范围 |
| Block-Scale | 块缩放，每 N 个连续元素共享一个缩放因子 |
| MXFP | Microscaling Floating Point，OCP 定义的微缩放浮点格式 |
| NVFP | NVIDIA 定义的 FP4 微缩放格式 |
| ScaleWidth | 每个 ReduceGroup 对应的缩放因子位宽 |
| ScaleElementWidth | 缩放因子单个元素位宽（8 bit，E5M2 格式） |
| MinGroupSize | 最小块缩放分组大小（16 个元素） |
| MinDataTypeWidth | PE 支持的最小数据类型位宽（4 bit） |

## 2. 整数量化方案

CUTE 通过 INT8/UINT8 数据类型直接支持量化推理。量化/反量化在软件侧完成，CUTE 硬件仅负责低精度矩阵乘法。

计算公式：`D[m][n] = Σ_k(quant_A[m][k] × quant_B[k][n]) + bias[n]`

| 数据类型 | 编码 | 量化方式 | 累加精度 |
|---------|------|---------|---------|
| I8×I8→I32 | 0 | 对称量化 | INT32 |
| I8×U8→I32 | 4 | 非对称量化 | INT32 |
| U8×I8→I32 | 5 | 非对称量化 | INT32 |
| U8×U8→I32 | 6 | 非对称量化 | INT32 |

INT32 累加器避免中间结果溢出。

## 3. Block-Scale 机制

### 3.1 缩放精度层次对比

| 方案 | 缩放因子粒度 | 精度 | 开销 |
|------|-------------|------|------|
| Per-tensor | 整个张量 1 个 | 最低 | 最小 |
| Per-channel | 每个通道 1 个 | 中等 | 中等 |
| Block-Scale | 每 N 个元素 1 个 | 最高 | 最大 |

### 3.2 支持的块缩放格式

| 格式 | 元素位宽 | 块大小 | 缩放因子位宽 | 缩放因子格式 | 源码名称 |
|------|---------|--------|-------------|-------------|---------|
| MXFP8 E4M3 | 8 bit | 32 | 8 bit | E5M2（无符号） | `DataTypeMxfp8e4m3F32` |
| MXFP8 E5M2 | 8 bit | 32 | 8 bit | E5M2（无符号） | `DataTypeMxfp8e5m2F32` |
| MXFP4 | 4 bit | 32 | 8 bit | E5M2（无符号） | `DataTypemxfp4F32` |
| NVFP4 | 4 bit | 16 | 8 bit | E5M2（无符号） | `DataTypenvfp4F32` |

### 3.3 MXFP 缩放原理

MXFP 的缩放过程：提取块内最大指数编码为 8-bit 缩放因子（E5M2 无符号格式），各元素除以缩放因子后存储为低精度浮点。

恢复计算时：`value = fp_element × scale_factor`

### 3.4 ScaleWidth 计算

```
ScaleWidth = ReduceWidthByte × 8 × ScaleElementWidth / MinDataTypeWidth / MinGroupSize
           = ReduceWidthByte × 8 × 8 / 4 / 16
           = ReduceWidthByte（字节）
```

以默认配置 ReduceWidthByte=32 为例：
- MXFP8 (groupSize=32): 每个 PE 每周期接受 `32×8/8/32 = 1` 个 8-bit 缩放因子
- MXFP4 (groupSize=32): 每个 PE 每周期接受 `32×8/4/32 = 2` 个 8-bit 缩放因子
- NVFP4 (groupSize=16): 每个 PE 每周期接受 `32×8/4/16 = 4` 个 8-bit 缩放因子

## 4. 硬件数据路径

### 4.1 Scale 子系统架构

```
主存
  │
  ├──→ AScaleLoader ──→ A Scale Scratchpad[i] ──→ AScaleController ──ScaleA──→ MatrixTE
  │                                                                         │
  └──→ BScaleLoader ──→ B Scale Scratchpad[i] ──→ BScaleController ──ScaleB──→ │
                                                                              │
  ┌───────────────────────────────────────────────────────────────────────────┘
  │
Data Scratchpad ──→ DataController ──→ VectorA/VectorB ──→ MatrixTE ──→ FReducePE
                                                           │
                                                     D = Σ(A × scaleA × B × scaleB) + C
```

### 4.2 各模块职责

| 模块 | 源文件 | 职责 |
|------|--------|------|
| AScaleLoader | `AScaleLoader.scala` | 从主存加载 A 矩阵的缩放因子到 A Scale Scratchpad |
| BScaleLoader | `BScaleLoader.scala` | 从主存加载 B 矩阵的缩放因子到 B Scale Scratchpad |
| AScaleScratchpad | `AScaleScratchpad.scala` | 双缓冲 SRAM，存储 A 矩阵缩放因子 |
| BScaleScratchpad | `BScaleScratchpad.scala` | 双缓冲 SRAM，存储 B 矩阵缩放因子 |
| AScaleController | `AScaleController.scala` | 按 M/K 迭代从 A Scale Scratchpad 读取缩放因子，传递给 MTE |
| BScaleController | `BScaleController.scala` | 按 N/K 迭代从 B Scale Scratchpad 读取缩放因子，传递给 MTE |

### 4.3 Scale 数据流时序

Scale 数据的加载和计算时序与数据矩阵一致，遵循三阶段流水线：

```
[Load Phase]
  TaskController 发出加载任务 → AScaleLoader/BScaleLoader
  AScaleLoader → LocalMMU → TileLink → DRAM → A Scale Scratchpad[i]
  BScaleLoader → LocalMMU → TileLink → DRAM → B Scale Scratchpad[i]

[Compute Phase]
  AScaleController 从 A Scale Scratchpad[i] 读取缩放因子
  BScaleController 从 B Scale Scratchpad[i] 读取缩放因子
  缩放因子与数据向量同步传入 MTE 的 ScaleA/ScaleB 端口
  FReducePE 在乘法计算中应用缩放因子
```

### 4.4 Scale Scratchpad 容量

| 参数 | A Scale | B Scale |
|------|---------|---------|
| 总容量 | `AScaleSize = Tensor_M × ReduceGroupSize × ScaleWidth` | `BScaleSize = Tensor_N × ReduceGroupSize × ScaleWidth` |
| Slice 数 | `AScaleNSlices = outsideDataWidth / ScaleWidth / ReduceGroupSize` | `BScaleNSlices = outsideDataWidth / ScaleWidth / ReduceGroupSize` |
| Bank 条目数 | `AScaleBankNEntrys = AScaleSize / (AScaleNSlices × ScaleWidth × ReduceGroupSize)` | `BScaleBankNEntrys = BScaleSize / (BScaleNSlices × ScaleWidth × ReduceGroupSize)` |

以默认配置（Tensor_M=N=128, Tensor_K=64, ReduceWidthByte=32, outsideDataWidth=512）为例：
- ScaleWidth = 32 × 8 × 8 / 4 / 16 = 32 bit
- ReduceGroupSize = 64 / 32 = 2
- AScaleSize = 128 × 2 × 4 = 1024 byte
- AScaleNSlices = 512 / 32 / 2 = 8
- AScaleBankNEntrys = 1024 / (8 × 4 × 2) = 16

## 5. 与其他模块的交互

| 模块 | 方向 | 说明 |
|------|------|------|
| AScaleScratchpad / BScaleScratchpad | ← | AScaleLoader/BScaleLoader 写入缩放因子 |
| AScaleController / BScaleController | ← | 从 Scale Scratchpad 读取缩放因子 |
| AScaleController / BScaleController | → | 输出 ScaleA/ScaleB 给 MatrixTE |
| LocalMMU | ←→ | AScaleLoader/BScaleLoader 通过 LocalMMU 访问主存 |
| TaskController | ← | 接收加载任务和配置 |

## 6. 参考

- Scale Scratchpad 设计：[scale-scratchpads.md](../hardware/memory-system/scale-scratchpads.md)
- 参数定义：`src/main/scala/CUTEParameters.scala`（`CuteFPEParams`、`ScaleWidth`、`ScaleVecWidth`）
- Scale 源码：`AScaleScratchpad.scala`、`BScaleScratchpad.scala`、`AScaleController.scala`、`BScaleController.scala`、`AScaleLoader.scala`、`BScaleLoader.scala`
