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
| `ReduceWidthByte` | 归约宽度（字节） | 32 |
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
| `ScaleWidth` | `ReduceWidthByte × 8 × ScaleElementWidth / MinDataTypeWidth / MinGroupSize` |
| `AScaleSize` | `Tensor_M × ReduceGroupSize × ScaleWidth` |
| `BScaleSize` | `Tensor_N × ReduceGroupSize × ScaleWidth` |
| `AScaleNSlices` | `outsideDataWidth / ScaleWidth / ReduceGroupSize` |
| `BScaleNSlices` | `outsideDataWidth / ScaleWidth / ReduceGroupSize` |
| `AScaleBankNEntrys` | `AScaleSize / (AScaleNSlices × ScaleWidth × ReduceGroupSize)` |
| `BScaleBankNEntrys` | `BScaleSize / (BScaleNSlices × ScaleWidth × ReduceGroupSize)` |

### 2.4 系统参数

| 参数 | 含义 | 默认值 |
|------|------|--------|
| `LLCSourceMaxNum` | LLC Source ID 最大数 | 64 |
| `MemorysourceMaxNum` | Memory Source ID 最大数 | 64 |
| `MMUAddrWidth` | MMU 地址宽度 | 39 |
| `ApplicationMaxTensorSize` | 应用层最大张量尺寸 | 65535 |
| `EnablePerfCounter` | 性能计数器开关 | false |

## 3. 性能预设配置

| 配置名 | Matrix_M | Matrix_N | ReduceWidthByte | 估算性能(8bit) |
|--------|----------|----------|-----------------|---------|
| `CUTE_32Tops` | 16 | 16 | 32 | 32 TOPS |
| `CUTE_16Tops` | 8 | 8 | 64 | 16 TOPS |
| `CUTE_8Tops` | 8 | 8 | 32 | 8 TOPS |
| `CUTE_4Tops` | 4 | 4 | 64 | 4 TOPS |
| `CUTE_2Tops` | 4 | 4 | 32 | 2 TOPS |
| `CUTE_1Tops` | 2 | 2 | 64 | 1 TOPS |
| `CUTE_05Tops` | 2 | 2 | 32 | 0.5 TOPS |

## 4. 数据类型编码

CUTE 支持 13 种数据类型，4-bit 编码（`DataTypeBitWidth = 4`）：

| 编码 | 源码名称 | A 类型 | B 类型 | 累加类型 | 需要 Scale |
|------|---------|--------|--------|---------|-----------|
| 0 | `DataTypeI8I8I32` | INT8 | INT8 | INT32 | 否 |
| 1 | `DataTypeF16F16F32` | FP16 | FP16 | FP32 | 否 |
| 2 | `DataTypeBF16BF16F32` | BF16 | BF16 | FP32 | 否 |
| 3 | `DataTypeTF32TF32F32` | TF32 | TF32 | FP32 | 否 |
| 4 | `DataTypeI8U8I32` | INT8 | UINT8 | INT32 | 否 |
| 5 | `DataTypeU8I8I32` | UINT8 | INT8 | INT32 | 否 |
| 6 | `DataTypeU8U8I32` | UINT8 | UINT8 | INT32 | 否 |
| 7 | `DataTypeMxfp8e4m3F32` | MXFP8 E4M3 | MXFP8 E4M3 | FP32 | 是（GroupSize=32） |
| 8 | `DataTypeMxfp8e5m2F32` | MXFP8 E5M2 | MXFP8 E5M2 | FP32 | 是（GroupSize=32） |
| 9 | `DataTypenvfp4F32` | NVFP4 | NVFP4 | FP32 | 是（GroupSize=16） |
| 10 | `DataTypemxfp4F32` | MXFP4 | MXFP4 | FP32 | 是（GroupSize=32） |
| 11 | `DataTypefp8e4m3F32` | FP8 E4M3 | FP8 E4M3 | FP32 | 否 |
| 12 | `DataTypefp8e5m2F32` | FP8 E5M2 | FP8 E5M2 | FP32 | 否 |

## 5. LocalMMU 任务类型

| 编码 | 名称 | 说明 |
|------|------|------|
| 0 | `AFirst` | A MemoryLoader |
| 1 | `BFirst` | B MemoryLoader |
| 2 | `CFirst` | C MemoryLoader |
| 3 | `BScaleFirst` | B ScaleLoader |
| 4 | `AScaleFirst` | A ScaleLoader |

`TaskTypeMax = 5`，`TaskTypeBitWidth = 3`。

## 6. 算力-带宽约束模型

论文提出的约束公式（保证计算不被访存瓶颈限制）：

```
M_scp × N_scp × K_scp     (M_scp + N_scp) × K_scp
────────────────────── ≤ ─────────────────────────
Freq × M_pe × N_pe × K_pe     DataBandwidth
```

其中 `DataBandwidth` 由缓存结构、片上网络、内存带宽等系统因素决定。

## 7. 参考

- 源码：`src/main/scala/CUTEParameters.scala`
