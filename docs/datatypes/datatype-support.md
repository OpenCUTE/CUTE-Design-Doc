# 数据类型支持矩阵

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| `dataType` | 数据类型编码字段，4 bit（`DataTypeBitWidth = 4`） |
| `bias_type` | C 矩阵加载方式编码 |
| ScaleVecWidth | 每个 PE 每周期接受的缩放因子宽度，由数据类型决定 |

## 2. MTE / FReducePE 支持

全部 13 种数据类型均已在 FReducePE 中实现解码和计算路径：

| 编码 | 源码名称 | 输入 A | 输入 B | 累加 (C) | 输出 (D) | A 字节 | C 字节 | 需要 Scale |
|------|---------|--------|--------|---------|---------|--------|--------|-----------|
| 0 | `DataTypeI8I8I32` | INT8 | INT8 | INT32 | INT32 | 1 | 4 | 否 |
| 1 | `DataTypeF16F16F32` | FP16 | FP16 | FP32 | FP32 | 2 | 4 | 否 |
| 2 | `DataTypeBF16BF16F32` | BF16 | BF16 | FP32 | FP32 | 2 | 4 | 否 |
| 3 | `DataTypeTF32TF32F32` | TF32 | TF32 | FP32 | FP32 | 4 | 4 | 否 |
| 4 | `DataTypeI8U8I32` | INT8 | UINT8 | INT32 | INT32 | 1 | 4 | 否 |
| 5 | `DataTypeU8I8I32` | UINT8 | INT8 | INT32 | INT32 | 1 | 4 | 否 |
| 6 | `DataTypeU8U8I32` | UINT8 | UINT8 | INT32 | INT32 | 1 | 4 | 否 |
| 7 | `DataTypeMxfp8e4m3F32` | MXFP8 | MXFP8 | FP32 | FP32 | 1 | 4 | 是 |
| 8 | `DataTypeMxfp8e5m2F32` | MXFP8 | MXFP8 | FP32 | FP32 | 1 | 4 | 是 |
| 9 | `DataTypenvfp4F32` | NVFP4 | NVFP4 | FP32 | FP32 | 1 | 4 | 是 |
| 10 | `DataTypemxfp4F32` | MXFP4 | MXFP4 | FP32 | FP32 | 1 | 4 | 是 |
| 11 | `DataTypefp8e4m3F32` | FP8 | FP8 | FP32 | FP32 | 1 | 4 | 否 |
| 12 | `DataTypefp8e5m2F32` | FP8 | FP8 | FP32 | FP32 | 1 | 4 | 否 |

## 3. ScaleVecWidth（各类型每 PE 每周期的缩放因子宽度）

| 数据类型 | ScaleVecWidth 公式 | ReduceWidthByte=32 时 |
|---------|-------------------|---------------------|
| MXFP8 E4M3 | `ReduceWidthByte × 8 / 8 / 32` | 1 |
| MXFP8 E5M2 | `ReduceWidthByte × 8 / 8 / 32` | 1 |
| NVFP4 | `ReduceWidthByte × 8 / 4 / 16` | 4 |
| MXFP4 | `ReduceWidthByte × 8 / 4 / 32` | 2 |
| 其他类型 | 0（不使用 Scale） | 0 |

## 4. Scratchpad 存储

### 4.1 数据 Scratchpad

| 数据类型 | A/B 元素字节宽度 | ReduceWidthByte=32 时每 PE 输入元素数 |
|---------|----------------|--------------------------------------|
| INT8/UINT8 | 1 | 32 |
| FP8/MXFP8 (E4M3/E5M2) | 1 | 32 |
| FP16/BF16 | 2 | 16 |
| TF32 | 4 | 8 |
| FP4/NVFP4/MXFP4 | 1 | 32 |

C Scratchpad 统一以 32-bit（FP32/INT32）宽度存储累加值和结果。

### 4.2 Scale Scratchpad

| 参数 | A Scale | B Scale |
|------|---------|---------|
| 总容量公式 | `Tensor_M × ReduceGroupSize × ScaleWidth` | `Tensor_N × ReduceGroupSize × ScaleWidth` |
| Slice 数公式 | `outsideDataWidth / ScaleWidth / ReduceGroupSize` | 同左 |
| 实例数 | 2（双缓冲） | 2（双缓冲） |
| Bank 数 | 1 | 1 |

Scale Scratchpad 仅在使用块缩放数据类型（编码 7-10）时需要加载和使用。

## 5. MemoryLoader 数据搬运

| Loader | 支持的数据宽度 | 说明 |
|--------|--------------|------|
| AML (A MemoryLoader) | 1/2/4 byte | 由 `dataType` 决定 |
| BML (B MemoryLoader) | 1/2/4 byte | 由 `dataType` 决定 |
| CML (C MemoryLoader) Load | 4 byte | C 矩阵（累加初值） |
| CML (C MemoryLoader) Store | 4 byte | D 结果写回 |
| ASL (A ScaleLoader) | 由 `ScaleVecWidth` 决定 | 块缩放类型时加载 |
| BSL (B ScaleLoader) | 由 `ScaleVecWidth` 决定 | 块缩放类型时加载 |

## 6. LocalMMU 访问

| 请求源 | TaskType 编码 | 说明 |
|--------|-------------|------|
| AML | 0 (`AFirst`) | A 矩阵加载 |
| BML | 1 (`BFirst`) | B 矩阵加载 |
| CML | 2 (`CFirst`) | C 矩阵加载/D 结果存储 |
| BSL | 3 (`BScaleFirst`) | B 缩放因子加载 |
| ASL | 4 (`AScaleFirst`) | A 缩放因子加载 |

## 7. AfterOps 后处理

| 后处理操作 | 支持的输入类型 | 状态 |
|-----------|--------------|------|
| 转置 (Transpose) | 所有类型 | 已实现 |
| 数据重排 (Reorder) | 所有类型 | 已实现 |
| 缩放 (Scale) | — | 代码中存在 `Is_EasyScale_Only_Ops` 标志，当前未启用 |

## 8. 数据类型兼容性规则

### 输入类型组合

A 和 B 的类型由 `dataType` 单一编码决定，当前不支持跨类型混合运算（如 FP16×INT8）。

### Bias 类型（C 矩阵）

Bias 类型由 `bias_type` 字段独立控制，与 `dataType` 无关：

| bias_type | C 矩阵加载方式 |
|-----------|--------------|
| 1 (ZeroLoad) | C Scratchpad 填零 |
| 2 (RepeatRowLoad) | 加载一行广播（bias 向量，4 byte 元素） |
| 3 (FullLoad) | 完整加载 C 矩阵（4 byte 元素） |

### 累加器类型

由输入类型自动决定：整数输入（编码 0/4/5/6）→ INT32 累加；浮点输入（编码 1-3/7-12）→ FP32 累加。

## 9. 参考

- 源码：`src/main/scala/FReducePE.scala`
- 参数定义：`src/main/scala/CUTEParameters.scala`（`ElementDataType`、`ScaleVecWidth`）
- 详细说明：[精度格式总览](precision-formats.md)、[量化与 Block-Scale](quantization.md)
