# CUTE 设计文档

## 什么是 CUTE

CUTE（**C**PU-centric and **U**ltra-utilized **T**ensor **E**ngine）是一个统一且可配置的 CPU 矩阵扩展架构，以 RoCC 协处理器形式集成在 RISC-V CPU 核内部，通过 TileLink 总线访问主存。

CUTE 旨在以最小的设计开销实现跨 CPU 平台的敏捷集成与高效执行，支持从 0.5 TOPS 到 32 TOPS 的可配置算力范围，覆盖从低精度整数到微缩放浮点（MXFP/NVFP）的广泛数据类型。

## 本文档是什么

本文档是 CUTE 硬件加速器的**微架构设计文档**，面向芯片设计工程师、验证工程师和系统集成工程师，提供以下内容：

- **硬件模块的详细设计规格**：每个模块的设计参数、功能描述、微架构设计和接口信号
- **模块间的交互关系**：数据流路径、握手协议、时序约束
- **系统集成方案**：与不同 RISC-V CPU 核（Rocket、BOOM、Shuttle、香山）的集成方式
- **软件编程接口**：自定义指令编码、异步编程模型

本文档与 CUTE 源代码仓库保持同步，所有设计描述均基于源码实现，并通过论文（DAC 2026）进行交叉验证。

## 文档阅读指南

本文档按照 CUTE 的硬件模块层次组织，目录结构与源码模块一一对应：

```
CUTE 加速器
├── 计算引擎          →  hardware/compute-engine/
│   ├── MatrixTE          矩阵张量引擎（PE 阵列）
│   ├── FReducePE         归约处理单元（6 级流水线）
│   └── AfterOps          后处理模块
├── 存储系统          →  hardware/memory-system/
│   ├── Scratchpads       数据暂存（A/B/C，双缓冲）
│   ├── Scale Scratchpads 缩放因子暂存（A/B，双缓冲）
│   ├── Data Controllers  数据控制器（A/B/C）
│   ├── Scale Controllers 缩放因子控制器（A/B）
│   ├── Memory Loaders    内存加载器（A/B/C + Scale A/B）
│   └── LocalMMU          本地内存管理单元（5 路 TLB 仲裁）
├── 控制逻辑          →  hardware/control-logic/
│   ├── TaskController    指令译码与调度
│   ├── CUTE2YGJK         RoCC 接口适配
│   └── CUTEParameters    参数化配置
└── 集成方案          →  hardware/integration/
    ├── Rocket            顺序核集成
    ├── BOOM              乱序核集成
    └── Shuttle           多发射核集成
```

**建议阅读顺序：**

1. [项目概述](overview/index.md) — 了解 CUTE 的设计目标和整体架构
2. [整体架构总览](overview/architecture-overview.md) — 理解四大子系统和三阶段流水线
3. 根据需要查阅具体模块的设计文档

## 快速导航

| 章节 | 说明 |
|------|------|
| [项目概述](overview/index.md) | 背景、架构总览、快速上手 |
| [硬件设计](hardware/index.md) | 计算引擎、存储系统、控制逻辑、集成方案 |
| [指令集](instruction-set/index.md) | 自定义指令编码与融合算子 |
| [数据类型](datatypes/index.md) | 支持的精度格式与缩放方案 |
| [软件与测试](software/index.md) | 测试框架与基准测试 |
| [附录](appendix/index.md) | 术语表、参考文献、变更记录 |
