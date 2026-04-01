# Rocket 核集成

## 1. 概述

Rocket 是 UC Berkeley 开发的顺序单发射 RISC-V 处理器核心。CUTE 通过 Rocket 的 RoCC（Rocket Custom Coprocessor）接口集成到 Rocket Chip SoC 中。

## 2. 集成方式

CUTE 使用 Chipyard 的 Config 系统声明式集成。一个典型的 Rocket+CUTE 配置：

```scala
class CUTE2TopsSmallRocketConfig extends Config(
  new cute.WithCuteCoustomParams(
    CoustomCuteParam = CuteParams.CUTE_2Tops_64SCP) ++
  new cute.WithCUTE(Seq(0)) ++                    // 在 hart 0 上实例化 CUTE
  new freechips.rocketchip.subsystem.WithNBitMemoryBus(512) ++
  new freechips.rocketchip.subsystem.WithInclusiveCache(
    capacityKB=512, outerLatencyCycles=40) ++
  new freechips.rocketchip.rocket.WithNSmallCores(1) ++
  new chipyard.config.AbstractConfig)
```

**关键配置项：**

| 配置 | 说明 |
|------|------|
| `WithCUTE(Seq(0))` | 在 hart 0 上挂载 CUTE 加速器 |
| `WithCuteCoustomParams` | 指定 CUTE 的硬件参数预设 |
| `WithNBitMemoryBus(512)` | 内存总线宽度 512 bit |
| `WithInclusiveCache` | 配置 LLC（512KB，40 周期延迟） |

## 3. 系统拓扑

```
Rocket Core (hart 0)
    ├── RoCC Interface
    │     ├── CUTE (加速器)
    │     └── TileLink → System Bus → LLC → DRAM
    └── Scalar/Vector Pipeline
```

## 4. 已知限制

| 限制 | 说明 |
|------|------|
| 单发射 | Rocket 为顺序单发射，CUTE 异步指令的发射吞吐受限于 Rocket 的指令发射带宽 |
| RoCC 64-bit | RoCC 接口的数据宽度为 64 bit，配置指令需要多次传递 |
| 无向量单元 | 标准 Rocket 不含向量单元，无法实现矩阵-向量交叠执行（需搭配 Saturn 等向量扩展） |

## 5. 集成成本

| 指标 | 数据 |
|------|------|
| 新增 RTL 代码量 | 254 行 |
| 集成时间 | 3 天 |

## 6. 参考

- 配置源码：`build/chipyard/config/CuteConfig.scala`
- Rocket Chip：`CPU/rocket/`
