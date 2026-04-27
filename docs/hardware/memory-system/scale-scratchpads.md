# Scale Factor Scratchpad

> **典型配置**：`Tensor_M = Tensor_N = 64`，`Matrix_M = Matrix_N = 4`，`ReduceWidthByte = 64`（ReduceWidth = 512 bit），`Tensor_K = 64`（ReduceGroupSize = 1），`ResultWidthByte = 4`。A/B SCP 各 4 KB，C SCP 16 KB，双缓冲总计 48 KB。

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| ScaleFactor | 块缩放因子，用于 MXFP/NVFP 等微缩放格式的逐块缩放 |
| ScaleWidth | 单个缩放因子的位宽，`ReduceWidthByte × 8 × ScaleElementWidth / MinDataTypeWidth / MinGroupSize` |
| ScaleNSlices | Scale Scratchpad 的 slice 数量，`outsideDataWidth / ScaleWidth / ReduceGroupSize` |

## 2. 设计规格

### 2.1 A Scale Scratchpad

| 参数 | 说明 |
|------|------|
| 源文件 | `AScaleScratchpad.scala` |
| 实例数 | 2（双缓冲） |
| Bank 数 | 1（单 Bank，SyncReadMem） |
| 每个 Bank 条目位宽 | `AScaleNSlices × ScaleWidth × ReduceGroupSize` bit |
| `AScaleNSlices` | `outsideDataWidth / ScaleWidth / ReduceGroupSize` |
| `AScaleBankNEntrys` | `AScaleSize / (AScaleNSlices × ScaleWidth × ReduceGroupSize)` |
| 总容量 | `AScaleSize = Tensor_M × ReduceGroupSize × ScaleWidth` |

### 2.2 B Scale Scratchpad

| 参数 | 说明 |
|------|------|
| 源文件 | `BScaleScratchpad.scala` |
| 实例数 | 2（双缓冲） |
| Bank 数 | 1（单 Bank，SyncReadMem） |
| 每个 Bank 条目位宽 | `BScaleNSlices × ScaleWidth × ReduceGroupSize` bit |
| `BScaleNSlices` | `outsideDataWidth / ScaleWidth / ReduceGroupSize` |
| `BScaleBankNEntrys` | `BScaleSize / (BScaleNSlices × ScaleWidth × ReduceGroupSize)` |
| 总容量 | `BScaleSize = Tensor_N × ReduceGroupSize × ScaleWidth` |

## 3. 功能描述

Scale Scratchpad 存储块缩放数据类型（MXFP8、MXFP4、NVFP4）的缩放因子。对于这些格式，每 `MinGroupSize` 个元素共享一个缩放因子。

### 3.1 与数据 Scratchpad 的对应关系

- A Scale SCP 的缩放因子与 A SCP 中的数据一一对应
- B Scale SCP 的缩放因子与 B SCP 中的数据一一对应
- ScaleController 根据当前计算的 K 迭代位置，从 Scale SCP 中读取对应块的缩放因子
- 缩放因子与数据一起传递给 MTE 的 PE 进行缩放计算

### 3.2 端口设计

Scale Scratchpad 与数据 Scratchpad 类似，采用写优先策略：

| 端口 | 方向 | 连接模块 | 说明 |
|------|------|---------|------|
| `FromScaleController.BankAddr` | 读请求 | AScaleController / BScaleController | 读地址 |
| `FromScaleController.Data` | 读响应 | AScaleController / BScaleController | 读数据（1 周期延迟） |
| `FromScaleLoader.BankAddr` | 写请求 | AScaleLoader / BScaleLoader | 写地址 |
| `FromScaleLoader.Data` | 写数据 | AScaleLoader / BScaleLoader | 写数据 |

### 3.3 不同数据类型的 Scale 宽度

| 数据类型 | Scale 宽度参数 | GroupSize | 说明 |
|---------|---------------|-----------|------|
| MXFP8 (E4M3/E5M2) | `mxfp8ScaleWidth` | 32 | 每 32 个 FP8 元素共享 1 个 8-bit 缩放因子 |
| MXFP4 | `mxfp4ScaleWidth` | 32 | 每 32 个 FP4 元素共享 1 个 8-bit 缩放因子 |
| NVFP4 | `nvfp4ScaleWidth` | 16 | 每 16 个 FP4 元素共享 1 个 8-bit 缩放因子 |

## 4. 与其他模块的交互

```
AScaleLoader ──写入──→ AScale SCP[i] ──读取──→ AScaleController ──ScaleA──→ MatrixTE
BScaleLoader ──写入──→ BS Scale SCP[i] ──读取──→ BSController ──ScaleB──→ MatrixTE

TaskController ──配置──→ AScaleController / BScaleController
TaskController ──加载任务──→ AScaleLoader / BScaleLoader
```

## 5. 参考

- 源码：`src/main/scala/AScaleScratchpad.scala`、`src/main/scala/BScaleScratchpad.scala`
- 参数定义：`src/main/scala/CUTEParameters.scala`（`ScaleWidth`、`AScaleNSlices`、`BScaleNSlices`）
