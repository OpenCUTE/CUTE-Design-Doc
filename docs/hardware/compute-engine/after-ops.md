# 后处理操作（AfterOps）

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| AfterOps | 后处理操作模块，对矩阵乘法结果进行后续变换 |
| FakeVPU | 当前版本的占位 VPU（Vector Processing Unit），提供简单队列透传 |
| VectorStreamInterface | 向量流接口，用于 CUTE 与 CPU 向量单元之间的数据交互 |

## 2. 设计规格

| 参数 | 当前状态 |
|------|---------|
| 支持的操作 | 透传（Passthrough） |
| 计划支持的操作 | 转置（Transpose）、重排（Reorder）、缩放（Scale）、向量后处理 |
| 流水级数 | — |

## 3. 功能描述

AfterOps 模块位于矩阵乘法结果（D）写回 C Scratchpad 的路径上，设计用于对计算结果进行后处理操作。

**当前状态**：大部分后处理逻辑已被注释，模块以透传模式运行。计算结果 `D = A×B+C` 直接写回 C Scratchpad，不经过额外变换。

**计划功能：**

| 功能 | 说明 |
|------|------|
| **Transpose** | 对输出矩阵进行转置 |
| **Reorder** | 对输出数据重新排列 |
| **Scale** | 对结果进行缩放（量化/反量化） |
| **向量后处理** | 激活函数、归一化等 element-wise 操作 |

## 4. 微架构设计

当前实现包含一个 `FakeVPU` 占位模块，通过简单队列将 CDataController 的数据透传到 VectorStreamInterface。

```
CDataController ──D result──→ AfterOpsModule ──passthrough──→ CScratchpad (写回)
                                    │
                                    └──→ VectorStreamInterface (预留)
```

## 5. 接口信号

| 信号名 | 方向 | 说明 |
|--------|------|------|
| `ConfigInfo` | Input | 后处理任务配置 |
| `AfterOpsInterface` | Inout | 与 CDataController 的数据接口 |
| `VectorInterfaceIO` | Output | 向量流接口 |

## 6. 与其他模块的交互

```
CDataController ──计算结果──→ AfterOpsModule ──写回数据──→ CScratchpad
                                         │
                                         └──→ VectorStreamInterface (预留)
```

## 7. 参考

- 源码：`src/main/scala/AfterOps.scala`
