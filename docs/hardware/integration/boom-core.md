# BOOM 核集成

## 1. 概述

BOOM（Berkeley Out-of-Order Machine）是 UC Berkeley 开发的乱序超标量 RISC-V 处理器。CUTE 同样通过 RoCC 接口集成到 BOOM 核。

## 2. 集成方式

```scala
class CUTE2TopsSmallBoomConfig extends Config(
  new cute.WithCuteCoustomParams(
    CoustomCuteParam = CuteParams.CUTE_2Tops_64SCP) ++
  new cute.WithCUTE(Seq(0)) ++
  new freechips.rocketchip.subsystem.WithNBitMemoryBus(512) ++
  new freechips.rocketchip.subsystem.WithInclusiveCache(
    capacityKB=512, outerLatencyCycles=40) ++
  new boom.v3.common.WithNSmallBooms(1) ++        // 1 个 Small BOOM 核
  new chipyard.config.AbstractConfig)
```

**支持多核配置：**

```scala
// 4 核 BOOM + 4 个 CUTE 实例
new cute.WithCUTE(Seq(0,1,2,3)) ++
new boom.v3.common.WithNSmallBooms(4)
```

## 3. 与 Rocket 集成的差异

| 维度 | Rocket | BOOM |
|------|--------|------|
| 微架构 | 顺序单发射 | 乱序 4 发射 |
| 指令发射窗口 | 窄（1 条/周期） | 宽（可同时发射多条指令） |
| RoCC 行为 | 同步等待响应 | 可乱序发射，但 RoCC 仍阻塞流水线 |
| 矩阵-向量交叠 | 受限于单发射 | 乱序窗口有更多交叠机会 |
| 集成代码量 | 254 行 | 301 行 |
| 集成时间 | 3 天 | 3 天 |

## 4. 系统拓扑

```
BOOM Core (乱序 4 发射)
    ├── Fetch / Decode / Rename / Issue
    ├── RoCC Interface
    │     ├── CUTE (加速器)
    │     └── TileLink → System Bus → LLC → DRAM
    └── Load-Store Unit / Branch Predictor
```

## 5. 性能测试配置

CUTE 在 BOOM 上有多种性能测试配置，用于评估不同内存带宽下的表现：

```scala
// 测试不同内存总线宽度对 CUTE 性能的影响
new freechips.rocketchip.subsystem.WithNBitMemoryBus(64)   // 64 bit
new freechips.rocketchip.subsystem.WithNBitMemoryBus(128)  // 128 bit
new freechips.rocketchip.subsystem.WithNBitMemoryBus(256)  // 256 bit
```

## 6. FPGA 配置

```scala
// FPGA 部署配置（带 MMIO 加速）
class YJPFPGACUTESmallBoomConfig extends Config(
  new cute.WithCUTE(Seq(0)) ++
  new boom.v3.common.WithNSmallBoomsMMIOSpeedUp(1) ++
  new chipyard.config.YJPAbstractConfig)
```

## 7. 参考

- 配置源码：`build/chipyard/config/CuteConfig.scala`
- BOOM：`CPU/boom/`
