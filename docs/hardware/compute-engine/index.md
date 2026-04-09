# 计算引擎

CUTE 的计算引擎由 MatrixTE（矩阵张量引擎）和 FReducePE（归约处理单元）组成，采用外积数据流和 6 级流水线架构，支持从 INT8 到 FP32 以及 MXFP/NVFP 等 13 种数据类型。

## 模块总览

```
VectorA ──→ ┌────────────────────────────┐
            │  MatrixTE (M×N PE Array)   │
VectorB ──→ │  每个 PE = FReducePE (6级)  │ ──→ MatrixD
ScaleA  ──→ │  D = A×B + C              │
ScaleB  ──→ └────────────────────────────┘
MatrixC ──→
```

## 导航

- [Matrix Tensor Engine (MTE)](mte.md) — PE 阵列结构、外积数据流、ScaleA/ScaleB 接口、6 级流水线总览
- [ReducePE 运算单元](reduce-pe.md) — 单个 PE 的 6 级流水线详解、13 种数据类型解码、归约树设计
- [后处理操作](after-ops.md) — ReLU、激活函数等计算后处理
