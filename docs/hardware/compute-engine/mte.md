# Matrix Tensor Engine (MTE)

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| MTE | Matrix Tensor Engine，矩阵张量引擎 |
| PE | Processing Element，处理单元 |
| FReducePE | Float Reduce PE，支持多精度浮点的归约处理单元 |
| MAC | Multiply-Accumulate，乘加运算 |
| Outer Product | 外积数据流，A 广播行方向、B 广播列方向 |
| ScaleA/ScaleB | 块缩放因子，用于 MXFP/NVFP 等微缩放数据类型 |

## 2. 设计规格

| 参数 | 含义 | 默认值 |
|------|------|--------|
| `Matrix_M` | PE 阵列行数 | 4 |
| `Matrix_N` | PE 阵列列数 | 4 |
| `ReduceWidth` | 每个 PE 的归约位宽 (bit) | `ReduceWidthByte × 8`（默认 256） |
| `ScaleWidth` | 每个 PE 的缩放因子位宽 (bit) | 自动推导 |
| `ResultWidth` | 输出结果位宽 (bit) | 32 |
| PE 流水级数 | FReducePE 内部 | 6 级 |

**吞吐量计算公式（n-bit 数据格式）：**

```
Throughput(n-bit) = Freq × Matrix_M × Matrix_N × (ReduceWidth / n) × 2
```

例：4×4 阵列、256-bit 归约宽度、INT8、2GHz：
`2GHz × 4 × 4 × (256/8) × 2 = 2 TOPS`

## 3. 功能描述

MatrixTE 是 CUTE 的核心计算模块，执行矩阵乘法的乘加运算。它接收来自 DataController 的 A/B 矩阵数据、来自 ScaleController 的缩放因子以及 C 矩阵累加值，计算 `D = A × B + C`。

**核心特征：**

- **外积数据流**：A 向量按行广播到所有 PE 行，B 向量按列广播到所有 PE 列。每个 PE 计算一个输出元素的外积累加
- **Output-Stationary**：累加结果驻留在 C Scratchpad 中，整个 K 维度遍历完毕后才写回
- **锁步执行**：所有 `Matrix_M × Matrix_N` 个 PE 同步运行，由 `ComputeGo` 信号驱动
- **块缩放支持**：ScaleA/ScaleB 输入端口接收缩放因子，用于 MXFP/NVFP 等数据类型的计算

**支持的操作：**
- 矩阵乘法：`D[M×N] = A[M×K] × B[K×N] + C[M×N]`
- 块缩放矩阵乘法：`D[M×N] = scale_A × A[M×K] × scale_B × B[K×N] + C[M×N]`（MXFP/NVFP）

## 4. 微架构设计

### 4.1 总体结构

```
VectorA ──→ ┌─────┐ ┌─────┐ ┌─────┐    ┌─────┐
(M 行广播)  │PE00 │ │PE01 │ │PE02 │... │PE0N │
            │ A×B │ │ A×B │ │ A×B │    │ A×B │
VectorB ──→ ├─────┤ ├─────┤ ├─────┤    ├─────┤
(N 列广播)  │PE10 │ │PE11 │ │PE12 │... │PE1N │
            │ A×B │ │ A×B │ │ A×B │    │ A×B │
            ├─────┤ ├─────┤ ├─────┤    ├─────┤
ScaleA ──→ │ ... │ │ ... │ │ ... │    │ ... │   (块缩放因子)
ScaleB ──→ ├─────┤ ├─────┤ ├─────┤    ├─────┤
            │PE-M0 │ │PE-M1│ │PE-M2│... │PE-MN│
            └──┬──┘ └──┬──┘ └──┬──┘    └──┬──┘
               │       │       │          │
MatrixC ──────→┴───────┴───────┴──────────┴─────→ MatrixD
```

- **PE 网格**：`Matrix_M × Matrix_N` 个 FReducePE 实例
- **广播机制**：同一行的 PE 接收相同的 A 向量数据和 ScaleA 缩放因子，同一列的 PE 接收相同的 B 向量数据和 ScaleB 缩放因子

### 4.2 FReducePE 6 级流水线

```
Pipe0         Pipe1          Pipe2          Pipe3         Pipe4         Pipe5
Decode  →  Exponent Cmp  →  Align+Reduce → Accumulate → Normalize → WriteBack
```

| 流水级 | 功能 |
|--------|------|
| **Pipe0 (Decode)** | `FVecDecoder` 将输入数据解码为内部 TF32 表示；计算尾数积；启动最大指数比较树 `CmpTreeP0` |
| **Pipe1 (Exponent Compare)** | 完成最大指数查找；计算尾数对齐的右移量 |
| **Pipe2 (Align + Reduce)** | 根据指数差对齐尾数；部分和归约树 |
| **Pipe3 (Accumulate)** | 最终累加；加入 C 矩阵的尾数值 |
| **Pipe4 (Normalize)** | CLZ 前导零归一化；指数调整；异常处理 |
| **Pipe5 (WriteBack)** | 打包为 FP32 结果输出；写入 C 矩阵 |

### 4.3 数据类型解码

`FVecDecoder` 根据输入的 `dataType` 字段选择解码路径：

| 类型 | 解码方式 |
|------|---------|
| I8 / U8 | 零扩展为内部表示 |
| FP16 | 拆分为 S/E/M，映射到 TF32 尾数 |
| BF16 | 直接扩展尾数为 TF32 |
| TF32 | 直接使用 |
| FP8 E4M3/E5M2 | 扩展指数和尾数 |
| MXFP8 E4M3/E5M2 | 扩展指数和尾数，配合 Scale 缩放因子 |
| MXFP4 | 扩展指数和尾数，配合 Scale 缩放因子 |
| NVFP4 | 扩展指数和尾数，配合 Scale 缩放因子 |

## 5. 接口信号

| 信号名 | 方向 | 位宽 | 说明 |
|--------|------|------|------|
| `VectorA` | Input | `ReduceWidth × Matrix_M` | A 矩阵输入向量 |
| `VectorB` | Input | `ReduceWidth × Matrix_N` | B 矩阵输入向量 |
| `ScaleA` | Input | `ScaleWidth × Matrix_M` | A 矩阵块缩放因子（MXFP/NVFP 等） |
| `ScaleB` | Input | `ScaleWidth × Matrix_N` | B 矩阵块缩放因子（MXFP/NVFP 等） |
| `MatrixC` | Input | `ResultWidth × Matrix_M × Matrix_N` | C 累加值输入 |
| `MatrixD` | Output | `ResultWidth × Matrix_M × Matrix_N` | D 结果输出 |
| `dataType` | Input | 4 | 数据类型选择（`DataTypeBitWidth = 4`） |
| `ComputeGo` | Output | 1 | 计算完成握手信号 |

## 6. 与其他模块的交互

```
ADataController ──VectorA──→ MatrixTE
BDataController ──VectorB──→ MatrixTE
AScaleController ──ScaleA──→ MatrixTE
BScaleController ──ScaleB──→ MatrixTE
CDataController ──MatrixC──→ MatrixTE ──MatrixD──→ CDataController
TaskController ──ConfigInfo──→ MatrixTE (dataType 配置)
```

## 7. 参考

- 源码：`src/main/scala/MatrixTE.scala`
- PE 源码：`src/main/scala/FReducePE.scala`
- 参数定义：`src/main/scala/CUTEParameters.scala`
