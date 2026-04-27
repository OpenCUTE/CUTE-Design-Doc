# 数据流控制器

> **典型配置**：`Tensor_M = Tensor_N = 64`，`Matrix_M = Matrix_N = 4`，`ReduceWidthByte = 64`（ReduceWidth = 512 bit），`Tensor_K = 64`（ReduceGroupSize = 1），`ResultWidthByte = 4`。A/B SCP 各 4 KB，C SCP 16 KB，双缓冲总计 48 KB。

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| ADC | A Data Controller，为 MTE 提供 A 矩阵数据 |
| BDC | B Data Controller，为 MTE 提供 B 矩阵数据 |
| CDC | C Data Controller，管理 C 矩阵读取和 D 结果写回 |
| ASC | A Scale Controller，为 MTE 提供 A 矩阵的缩放因子 |
| BSC | B Scale Controller，为 MTE 提供 B 矩阵的缩放因子 |

## 2. A/B Data Controller

### 2.1 设计规格

| 参数 | ADC | BDC |
|------|-----|-----|
| 数据来源 | A Scratchpad | B Scratchpad |
| 输出目标 | MTE VectorA | MTE VectorB |
| 输出位宽 | `ReduceWidth × Matrix_M` | `ReduceWidth × Matrix_N` |

### 2.2 功能描述

ADC 和 BDC 负责从 Scratchpad 中按正确顺序读取数据，供给 MTE 计算阵列。


**地址生成：**
- ADC：`next_addr = M_Iterator × K_IteratorMax + K_Iterator`
- BDC：`next_addr = N_Iterator × K_IteratorMax + K_Iterator`

**Hold Register 模式**：当下游 MTE 未就绪（NACK）时，DataController 使用保持寄存器缓存 SCP 读出数据，避免数据丢失。MTE 就绪后直接从保持寄存器输出。

### 2.3 与其他模块的交互

```
A Scratchpad[i] ──读取──→ ADC ──VectorA──→ MatrixTE
B Scratchpad[i] ──读取──→ BDC ──VectorB──→ MatrixTE
TaskController ──配置──→ ADC/BDC
```

## 3. A/B Scale Controller

### 3.1 设计规格

| 参数 | ASC | BSC |
|------|-----|-----|
| 源文件 | `AScaleController.scala` | `BScaleController.scala` |
| 数据来源 | A Scale Scratchpad | B Scale Scratchpad |
| 输出目标 | MTE ScaleA | MTE ScaleB |
| 输出位宽 | `ScaleWidth × Matrix_M` | `ScaleWidth × Matrix_N` |

### 3.2 功能描述

ASC 和 BSC 负责从 Scale Scratchpad 中按正确顺序读取缩放因子，供给 MTE 计算阵列。用于 MXFP8、MXFP4、NVFP4 等块缩放数据类型。

**状态机**：与 ADC/BDC 相同的 `idle → mm_task` 结构。

**缩放因子提取**：
- 根据 `dataType` 和当前 K 迭代位置计算 slice 偏移和缩放因子索引
- 支持三种缩放因子宽度：
  - `mxfp8ScaleWidth`（MXFP8 E4M3/E5M2）
  - `mxfp4ScaleWidth`（MXFP4）
  - `nvfp4ScaleWidth`（NVFP4）
- 根据数据类型选择对应宽度的缩放因子输出，并 pad 到 `ScaleWidth`

**地址生成**：
- ASC：`next_addr = (M_Iterator × Matrix_M × K_IteratorMax) × ScaleVecWidth(dataType) × 8 / outsideDataWidth`
- BSC：`next_addr = (N_Iterator × Matrix_N × K_IteratorMax) × ScaleVecWidth(dataType) × 8 / outsideDataWidth`

### 3.3 与其他模块的交互

```
A Scale Scratchpad[i] ──读取──→ ASC ──ScaleA──→ MatrixTE
B Scale Scratchpad[i] ──读取──→ BSC ──ScaleB──→ MatrixTE
TaskController ──配置──→ ASC/BSC
```

## 4. C Data Controller

### 4.1 功能描述

CDC 是最复杂的 DataController，同时负责：
1. **读取 C 矩阵**：从 C Scratchpad 读取累加初值传递给 MTE
2. **接收 D 结果**：接收 MTE 的计算结果
3. **写回 C Scratchpad**：将结果写回（经过 AfterOps 后处理）
4. **转置支持**：在写回时可对结果进行转置


## 5. 参考

- 源码：`src/main/scala/ADataController.scala`、`src/main/scala/BDataController.scala`、`src/main/scala/CDataController.scala`
- Scale 源码：`src/main/scala/AScaleController.scala`、`src/main/scala/BScaleController.scala`
