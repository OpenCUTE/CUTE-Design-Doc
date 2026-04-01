# 数据流控制器

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| ADC | A Data Controller，为 MTE 提供 A 矩阵数据 |
| BDC | B Data Controller，为 MTE 提供 B 矩阵数据 |
| CDC | C Data Controller，管理 C 矩阵读取和 D 结果写回 |
| ASC | A Scale Controller，提供 A 缩放因子 |
| BSC | B Scale Controller，提供 B 缩放因子 |

## 2. A/B Data Controller

### 2.1 设计规格

| 参数 | ADC | BDC |
|------|-----|-----|
| 数据来源 | A Scratchpad | B Scratchpad |
| 输出目标 | MTE VectorA | MTE VectorB |
| 输出位宽 | `ReduceWidth × Matrix_M` | `ReduceWidth × Matrix_N` |

### 2.2 功能描述

ADC 和 BDC 负责从 Scratchpad 中按正确顺序读取数据，供给 MTE 计算阵列。

**状态机：**
```
idle → mm_task → idle
         │
         └→ cal_init → cal_working → cal_end → (循环或结束)
```

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

## 3. C Data Controller

### 3.1 功能描述

CDC 是最复杂的 DataController，同时负责：
1. **读取 C 矩阵**：从 C Scratchpad 读取累加初值传递给 MTE
2. **接收 D 结果**：接收 MTE 的计算结果
3. **写回 C Scratchpad**：将结果写回（经过 AfterOps 后处理）
4. **转置支持**：在写回时可对结果进行转置

### 3.2 与其他模块的交互

```
C Scratchpad[i] ←─读取──── CDC ←─MatrixC──── MatrixTE
                              │
C Scratchpad[i] ←─写回── AfterOps ←─MatrixD──┘
                              │
                    VectorStreamInterface (预留)
```

## 4. A/B Scale Controller

### 4.1 功能描述

ASC 和 BSC 负责从 Scale Scratchpad 中读取块缩放因子，传递给 MTE。

**地址计算：**
- ASC：`bit_index(i) = (i × ReduceGroupSize + K_Iterator) × ScaleVecWidth(dataType) × 8`
- BSC：类似，按 N 维度计算

**数据类型适配**：根据当前 `dataType` 选择不同的缩放因子提取方式：
- MXFP8：每 32 个元素一个缩放因子
- MXFP4：每 16 个元素一个缩放因子
- NVFP4：特定的分组大小

### 4.2 与其他模块的交互

```
A Scale SCP[i] ──读取──→ ASC ──ScaleA──→ MatrixTE
B Scale SCP[i] ──读取──→ BSC ──ScaleB──→ MatrixTE
TaskController ──配置──→ ASC/BSC
```

## 5. 参考

- 源码：`src/main/scala/ADataController.scala`、`src/main/scala/BDataController.scala`、`src/main/scala/CDataController.scala`
- Scale 源码：`src/main/scala/AScaleController.scala`、`src/main/scala/BScaleController.scala`
