# 项目概述

CUTE（**C**PU-centric and **U**ltra-utilized **T**ensor **E**ngine）是一个统一且可配置的 CPU 矩阵扩展架构，以协处理器形式集成在 CPU 核内部，通过 TileLink 总线访问主存。CUTE 支持 RoCC 和 CSR 两种接口方式，已在 Rocket、BOOM、Shuttle（RoCC）和香山（CSR）等多个 RISC-V 处理器平台上完成集成。

CUTE 旨在以最小的设计开销实现跨 CPU 平台的敏捷集成与高效执行，支持从 0.5 TOPS 到 32 TOPS 的可配置算力范围，覆盖从低精度整数到微缩放浮点（MXFP/NVFP）的广泛数据类型。

## 导航

- [项目背景与目标](introduction.md) — 设计动机、核心设计原则、已集成平台、相关论文
- [整体架构总览](architecture-overview.md) — 四大子系统、三阶段流水线、数据流路径、关键参数、13 种数据类型
- [快速上手指南](getting-started.md) — 环境搭建、编译运行、基本使用
