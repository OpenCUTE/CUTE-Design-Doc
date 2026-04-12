# 整体架构总览

## 1. 系统定位

CUTE 作为 CPU 的矩阵扩展协处理器工作，位于 CPU 核内部，通过 TileLink 总线访问主存。CUTE 支持 RoCC 和 CSR 两种接口方式与 CPU 通信，具体集成方式取决于目标 CPU 平台（详见[集成方案](../hardware/integration/index.md)）。

![CUTE整体架构图](v3.png)

## 2. 四大子系统

| 子系统 | 核心模块 | 职责 |
|--------|---------|------|
| **控制逻辑** | TaskController, CUTE2YGJK | 接收 CPU 指令，分解为微任务，调度执行 |
| **存储系统** | Scratchpads, Scale Scratchpads, DataControllers, ScaleControllers, MemoryLoaders, ScaleLoaders, LocalMMU | 数据搬运、缓冲、缩放因子管理、地址翻译 |
| **计算引擎** | MatrixTE, FReducePE, AfterOps | 矩阵乘法运算和后处理 |
| **接口集成** | CUTE2YGJK, Cute2TL | 协处理器接口适配（RoCC/CSR）、TileLink 总线接口 |

## 3. 三阶段执行流水线

CUTE 的计算采用 **Load → Compute → Store** 三阶段流水线，支持跨 tile 重叠执行：

![CUTE 双缓冲流水线时序](pipeline.png)

**双缓冲机制**：所有 Scratchpad（包括数据 Scratchpad 和 Scale Scratchpad）均实例化 ×2，当前 tile 的 Compute 阶段使用 SCP[0] 的数据时，下一个 tile 的 Load 阶段同时向 SCP[1] 写入新数据。TaskController 通过 `SCPControlInfo` 信号交替选择 Scratchpad 组。

## 4. 数据流路径

```
CPU 发送矩阵乘法配置指令（通过协处理器接口）
  → TaskController 组装 MacroInst
  → TaskController 分解为 Load/Compute/Store 微指令三元组

[Load Phase]
  AMemoryLoader → LocalMMU → TileLink → DRAM
  AMemoryLoader → A Scratchpad[i] (写入)
  BMemoryLoader → B Scratchpad[i] (写入)
  CMemoryLoader → C Scratchpad[i] (写入或清零)
  AScaleLoader → LocalMMU → TileLink → DRAM        (块缩放数据类型时)
  AScaleLoader → A Scale Scratchpad[i] (写入)
  BScaleLoader → B Scale Scratchpad[i] (写入)

[Compute Phase]
  ADataController ← A Scratchpad[i] (读取)
  BDataController ← B Scratchpad[i] (读取)
  CDataController ← C Scratchpad[i] (读取累加值)
  AScaleController ← A Scale Scratchpad[i] (读取)   (块缩放数据类型时)
  BScaleController ← B Scale Scratchpad[i] (读取)
      ↓
  MatrixTE (M×N 个 FReducePE 并行计算)
      ↓
  CDataController → AfterOps → C Scratchpad[i] (写回结果)

[Store Phase]
  CMemoryLoader ← C Scratchpad[i] (读取结果)
  CMemoryLoader → LocalMMU → TileLink → DRAM
```

## 5. 关键参数总表

| 参数 | 含义 | 默认值 | 说明 |
|------|------|--------|------|
| `Tensor_M` | 输出矩阵行方向的 tile 大小 | 128 | 决定 A Scratchpad 容量 |
| `Tensor_N` | 输出矩阵列方向的 tile 大小 | 128 | 决定 B/C Scratchpad 容量 |
| `Tensor_K` | 归约维度 tile 大小 | 64 | 决定每次计算 K 方向的循环次数 |
| `Matrix_M` | PE 阵列行数 | 4 | 计算吞吐：`Matrix_M × Matrix_N` 个 PE |
| `Matrix_N` | PE 阵列列数 | 4 | |
| `ReduceWidthByte` | 每个归约通道的字节宽度 | 32 | 影响 PE 内部运算宽度 |
| `outsideDataWidth` | 外部总线数据宽度 (bit) | 512 | TileLink 接口位宽 |
| `VectorWidth` | 向量运算宽度 (bit) | 256 | |
| `MemoryDataWidth` | 内存数据宽度 (bit) | 64 | |
| `ScaleWidth` | 缩放因子位宽 (bit) | 自动推导 | `ReduceWidthByte × 8 × ScaleElementWidth / MinDataTypeWidth / MinGroupSize` |

## 6. 性能配置预设

CUTE 提供多种性能等级的预设配置：

| 配置名 | Matrix_M | Matrix_N | ReduceWidthByte | 估算性能 |
|--------|----------|----------|-----------------|---------|
| `CUTE_32Tops` | 16 | 16 | 32 | 32 TOPS |
| `CUTE_16Tops` | 8 | 8 | 64 | 16 TOPS |
| `CUTE_8Tops` | 8 | 8 | 32 | 8 TOPS |
| `CUTE_4Tops` | 4 | 4 | 64 | 4 TOPS |
| `CUTE_2Tops` | 4 | 4 | 32 | 2 TOPS |
| `CUTE_1Tops` | 2 | 2 | 64 | 1 TOPS |
| `CUTE_05Tops` | 2 | 2 | 32 | 0.5 TOPS |

还有带 `SCP` 后缀的变体（如 `CUTE_4Tops_128SCP`），修改了 `Tensor_M/N/K` 的 tile 尺寸。

## 7. 支持的数据类型

CUTE 支持 13 种数据类型，4-bit 编码（`DataTypeBitWidth = 4`），覆盖从低精度整数到微缩放浮点的广泛范围：

| 编码 | 源码名称 | 输入 A | 输入 B | 累加/输出 | 说明 |
|------|---------|--------|--------|----------|------|
| 0 | `DataTypeI8I8I32` | INT8 | INT8 | INT32 | 整数量化推理 |
| 1 | `DataTypeF16F16F32` | FP16 | FP16 | FP32 | 半精度浮点 |
| 2 | `DataTypeBF16BF16F32` | BF16 | BF16 | FP32 | 脑浮点（训练常用） |
| 3 | `DataTypeTF32TF32F32` | TF32 | TF32 | FP32 | TensorFloat-32 |
| 4 | `DataTypeI8U8I32` | INT8 | UINT8 | INT32 | 混合符号 |
| 5 | `DataTypeU8I8I32` | UINT8 | INT8 | INT32 | 混合符号 |
| 6 | `DataTypeU8U8I32` | UINT8 | UINT8 | INT32 | 无符号整数 |
| 7 | `DataTypeMxfp8e4m3F32` | MXFP8 E4M3 | MXFP8 E4M3 | FP32 | 微缩放 FP8（4-bit 指数，需 Scale） |
| 8 | `DataTypeMxfp8e5m2F32` | MXFP8 E5M2 | MXFP8 E5M2 | FP32 | 微缩放 FP8（5-bit 指数，需 Scale） |
| 9 | `DataTypenvfp4F32` | NVFP4 | NVFP4 | FP32 | NVIDIA FP4（需 Scale） |
| 10 | `DataTypemxfp4F32` | MXFP4 | MXFP4 | FP32 | 微缩放 FP4（需 Scale） |
| 11 | `DataTypefp8e4m3F32` | FP8 E4M3 | FP8 E4M3 | FP32 | 标准 FP8（4-bit 指数） |
| 12 | `DataTypefp8e5m2F32` | FP8 E5M2 | FP8 E5M2 | FP32 | 标准 FP8（5-bit 指数） |

> 编码 7-10 为块缩放（microscaling）数据类型，需要 Scale Scratchpad 提供对应的缩放因子。编码 0-6 和 11-12 为标准数据类型，不需要 Scale 支持。
