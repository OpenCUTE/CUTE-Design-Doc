# 硬件参数配置（CUTEParameters）

## 1. 概述

CUTE 的所有硬件参数集中在 `CUTEParameters.scala` 中定义，通过 Scala 的 `case class` 和 Chipyard 的 `Config` 系统实现参数化设计。

## 2. 核心参数

### 2.1 基础维度参数

| 参数 | 含义 | 默认值 | 约束 |
|------|------|--------|------|
| `Tensor_M` | 输出行方向 tile 大小 | 128 | 2 的幂 |
| `Tensor_N` | 输出列方向 tile 大小 | 128 | 2 的幂 |
| `Tensor_K` | 归约维度 tile 大小 | 64 | 2 的幂 |
| `Matrix_M` | PE 阵列行数 | 4 | 2 的幂 |
| `Matrix_N` | PE 阵列列数 | 4 | 2 的幂 |

### 2.2 位宽参数

| 参数 | 含义 | 默认值 |
|------|------|--------|
| `outsideDataWidth` | 外部总线数据宽度 (bit) | 512 |
| `MemoryDataWidth` | 内存数据宽度 (bit) | 64 |
| `VectorWidth` | 向量宽度 (bit) | 256 |
| `ReduceWidthByte` | 归约宽度（字节） | 64 |
| `ResultWidthByte` | 结果宽度（字节） | 4 |

### 2.3 派生参数（自动计算）

| 参数 | 计算公式 |
|------|---------|
| `ReduceWidth` | `ReduceWidthByte × 8` |
| `ReduceGroupSize` | `Tensor_K / ReduceWidthByte` |
| `AScratchpadSize` | `Tensor_M × ReduceGroupSize × ReduceWidthByte` |
| `AScratchpadNBanks` | `Matrix_M` |
| `BScratchpadNBanks` | `Matrix_N` |
| `CScratchpadNBanks` | `Matrix_N` |

### 2.4 系统参数

| 参数 | 含义 | 默认值 |
|------|------|--------|
| `LLCSourceMaxNum` | LLC Source ID 最大数 | 64 |
| `MemorysourceMaxNum` | Memory Source ID 最大数 | 64 |
| `MMUAddrWidth` | MMU 地址宽度 | 39 |
| `ApplicationMaxTensorSize` | 应用层最大张量尺寸 | 65535 |
| `EnablePerfCounter` | 性能计数器开关 | false |

## 3. 性能预设配置

| 配置名 | Matrix_M | Matrix_N | ReduceWidthByte | 估算性能 |
|--------|----------|----------|-----------------|---------|
| `CUTE_32Tops` | 16 | 16 | 32 | 32 TOPS |
| `CUTE_16Tops` | 8 | 8 | 64 | 16 TOPS |
| `CUTE_8Tops` | 8 | 8 | 32 | 8 TOPS |
| `CUTE_4Tops` | 4 | 4 | 64 | 4 TOPS |
| `CUTE_2Tops` | 4 | 4 | 32 | 2 TOPS |
| `CUTE_1Tops` | 2 | 2 | 64 | 1 TOPS |
| `CUTE_05Tops` | 2 | 2 | 32 | 0.5 TOPS |

## 4. 数据类型编码

13 种数据类型，4-bit 编码：

| 编码 | 名称 | A 类型 | B 类型 | 累加类型 |
|------|------|--------|--------|---------|
| 0 | I8I8I32 | INT8 | INT8 | INT32 |
| 1 | F16F16F32 | FP16 | FP16 | FP32 |
| 2 | BF16BF16F32 | BF16 | BF16 | FP32 |
| 3 | TF32TF32F32 | TF32 | TF32 | FP32 |
| 4 | I8U8I32 | INT8 | UINT8 | INT32 |
| 5 | U8I8I32 | UINT8 | INT8 | INT32 |
| 6 | U8U8I32 | UINT8 | UINT8 | INT32 |
| 7 | MXFP8E4M3 | MXFP8 | MXFP8 | FP32 |
| 8 | MXFP8E5M2 | MXFP8 | MXFP8 | FP32 |
| 9 | NVFP4 | NVFP4 | NVFP4 | FP32 |
| 10 | MXFP4 | MXFP4 | MXFP4 | FP32 |
| 11 | FP8E4M3 | FP8 | FP8 | FP32 |
| 12 | FP8E5M2 | FP8 | FP8 | FP32 |

## 5. 算力-带宽约束模型

论文提出的约束公式（保证计算不被访存瓶颈限制）：

```
M_scp × N_scp × K_scp     (M_scp + N_scp) × K_scp
────────────────────── ≤ ─────────────────────────
Freq × M_pe × N_pe × K_pe     DataBandwidth
```

其中 `DataBandwidth` 由缓存结构、片上网络、内存带宽等系统因素决定。

## 6. 参考

- 源码：`src/main/scala/CUTEParameters.scala`
