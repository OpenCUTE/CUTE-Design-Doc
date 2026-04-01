# Shuttle 核集成

## 1. 概述

Shuttle 是一个顺序 3 发射 RISC-V 处理器核心。CUTE 在 Shuttle 上的集成是论文中主要的评估平台，因为 Shuttle 支持搭配 Saturn 向量单元，可以完整实现矩阵-向量交叠执行。

## 2. 集成方式

### 2.1 基础配置

```scala
class CUTE4TopsSCP64Config extends Config(
  new cute.WithCuteCoustomParams(
    CoustomCuteParam = CuteParams.CUTE_4Tops_64SCP) ++
  new cute.WithCUTE(Seq(0)) ++
  new freechips.rocketchip.subsystem.WithNBitMemoryBus(512) ++
  new freechips.rocketchip.subsystem.WithInclusiveCache(
    capacityKB=512, outerLatencyCycles=40) ++
  new shuttle.common.WithShuttleTileBeatBytes(64) ++
  new shuttle.common.WithNShuttleCores(1) ++
  new chipyard.config.AbstractConfig)
```

### 2.2 完整配置（含向量单元 + TCM）

论文评估使用的主配置：

```scala
class CUTE4TopsShuttle512D512V512M512Sysbus512Membus1CoreConfig extends Config(
  new cute.WithCuteCoustomParams(
    CoustomCuteParam = CuteParams.CUTE_4Tops_64SCP) ++
  new cute.WithCUTE(Seq(0)) ++
  new saturn.shuttle.WithShuttleVectorUnit(
    vLen = 512, dLen = 512,
    VectorParams.CUTErefParams,
    mLen = Option(512)) ++                     // 512-bit Saturn 向量单元
  new shuttle.common.WithTCM(                  // 紧耦合存储器
    address = 0x70000000L, size = 2L << 20, banks = 2) ++
  new shuttle.common.WithShuttleTileBeatBytes(64) ++
  new shuttle.common.WithNShuttleCores(1) ++
  new chipyard.config.AbstractConfig)
```

## 3. 系统拓扑

```
Shuttle Core (顺序 3 发射)
    ├── Saturn 向量单元 (512-bit RVV)
    ├── RoCC Interface
    │     ├── CUTE (矩阵加速器, 4 TOPS@2GHz)
    │     └── TileLink → System Bus (512-bit)
    │                      → LLC (512KB)
    │                      → DRAM (48 GB/s)
    └── TCM (2MB, 紧耦合存储器)
```

## 4. 与 Rocket/BOOM 的差异

| 维度 | Rocket | BOOM | Shuttle |
|------|--------|------|---------|
| 微架构 | 顺序 1 发射 | 乱序 4 发射 | 顺序 3 发射 |
| 向量单元 | 无 | 可选 | Saturn (512-bit RVV) |
| TCM | 无 | 无 | 2 MB |
| 矩阵-向量交叠 | 不支持 | 部分 | 完整支持 |
| 集成代码量 | 254 行 | 301 行 | 512 行 |
| 集成时间 | 3 天 | 3 天 | 5 天 |

## 5. 多核配置

```scala
// 4 核 Shuttle + 4 个 CUTE 实例
class CUTEShuttle512D512V256M4CoreConfig extends Config(
  new cute.WithCUTE(Seq(0,1,2,3)) ++
  new saturn.shuttle.WithShuttleVectorUnit(512, 512, VectorParams.refParams) ++
  new shuttle.common.WithTCM ++
  new shuttle.common.WithNShuttleCores(4))
```

## 6. Debug 配置

```scala
// 启用 debug printf 和 ROB 追踪
new shuttle.common.WithShuttleDebugROB ++
new shuttle.common.WithShuttleDebugPrintf ++
```

## 7. 性能评估结果（Shuttle 平台）

论文在 Shuttle + 512-bit Saturn + 4 TOPS CUTE 配置下的评估结果：

| 负载 | 对比基线 | 加速比 |
|------|---------|--------|
| ResNet-50 INT8 | Intel Xeon 8580 AMX | 1.57x |
| BERT INT8 | Intel Xeon 8580 AMX | 1.57x |
| Llama3 INT8 | Intel Xeon 8580 AMX | 2.31x |

矩阵-向量交叠执行贡献超过 30% 的性能增益。

## 8. 参考

- 配置源码：`build/chipyard/config/CuteConfig.scala`
- Shuttle：`CPU/shuttle/`
- Saturn 向量单元：Chipyard 子模块
