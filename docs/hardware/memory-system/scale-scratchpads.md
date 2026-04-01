# Scale Factor Scratchpad

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| ScaleFactor | 块缩放因子，用于 MXFP/NVFP 等格式的逐块缩放 |
| ScaleWidth | 单个缩放因子的位宽，与数据类型和归约分组相关 |

## 2. 设计规格

### 2.1 A Scale Scratchpad

| 参数 | 说明 |
|------|------|
| 实例数 | 2（双缓冲） |
| Bank 数 | 1（单 Bank） |
| 每个 Bank 条目位宽 | `AScaleNSlices × ScaleWidth × ReduceGroupSize` bit |
| `AScaleNSlices` | `outsideDataWidth / ScaleWidth / ReduceGroupSize` |
| 总条目数 | `AScaleBankNEntrys` |

### 2.2 B Scale Scratchpad

| 参数 | 说明 |
|------|------|
| 实例数 | 2（双缓冲） |
| 结构 | 与 A Scale SCP 镜像，按 N 维度组织 |

## 3. 功能描述

Scale Factor Scratchpad 存储块缩放数据类型（MXFP8、MXFP4、NVFP4）的缩放因子。对于这些格式，每 `MinGroupSize` 个元素共享一个缩放因子。

**与数据 SCP 的对应关系：**
- A Scale SCP 的缩放因子与 A SCP 中的数据一一对应
- ScaleController 根据当前计算的 K 迭代位置，从 Scale SCP 中读取对应块的缩放因子
- 缩放因子与数据一起传递给 MTE 的 PE 进行计算

**容量需求与数据类型相关：**
- 不同数据类型的 `MinGroupSize` 不同（如 MXFP8 为 32，MXFP4 为 16）
- `ScaleElementWidth` 也因类型而异
- Scale SCP 的容量在参数推导时自动适配

## 4. 与其他模块的交互

| Scale SCP | 写入方 | 读取方 |
|-----------|--------|--------|
| A Scale SCP[i] | AScaleLoader | AScaleController → MTE ScaleA |
| B Scale SCP[i] | BScaleLoader | BScaleController → MTE ScaleB |

## 5. 参考

- 源码：`src/main/scala/AScaleScratchpad.scala`、`src/main/scala/BScaleScratchpad.scala`
