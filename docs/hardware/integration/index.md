# 集成方案

CUTE 作为协处理器可集成到多种 RISC-V CPU 核中，支持不同的 CPU 微架构和接口方式。

## 集成方式总览

| CPU 核 | 微架构 | 接口方式 | 特点 |
|--------|--------|---------|------|
| Rocket | 顺序执行 | RoCC | 基准集成方案，支持 TileLink |
| Shuttle | 3 发射 | RoCC + Saturn VPU | 多发射支持，与向量扩展协同 |
| BOOM | 乱序执行 | RoCC | 乱序核集成 |
| XiangShan-Kunminghu | 乱序执行 | CSR | 自定义 CSR 接口 |

## 导航

- [Rocket 核集成](rocket-core.md) — RoCC 接口连接、TileLink 配置、异步 matmul 抽象
- [BOOM 核集成](boom-core.md) — 乱序核适配、内存序处理
- [Shuttle 核集成](shuttle-core.md) — 多发射支持、Saturn VPU 协同、矩阵-向量混合运算
