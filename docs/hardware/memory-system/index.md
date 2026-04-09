# 存储系统

CUTE 的存储系统负责数据在主存与计算引擎之间的搬运，包含 Scratchpad 缓冲、Scale Scratchpad 缓冲、数据流控制、缩放因子控制、内存加载和地址翻译五个层次。所有 Scratchpad 采用双缓冲设计，支持 Load/Compute/Store 流水线重叠执行。

## 模块总览

```
主存 (DRAM/LLC)
  ↕ TileLink
LocalMMU (5路仲裁 + TLB翻译)
  ↕
┌──────────┬──────────┬──────────┬──────────┬──────────┐
  AML        BML        CML        ASL        BSL       ← MemoryLoader
  ↓          ↓          ↓          ↓          ↓
A SCP×2    B SCP×2    C SCP×2  A SSCP×2  B SSCP×2     ← Scratchpad (双缓冲)
  ↓          ↓          ↓          ↓          ↓
  ADC        BDC        CDC        ASC        BSC       ← DataController
  ↓          ↓          ↓          ↓          ↓
         MatrixTE (VectorA/B + ScaleA/B)             ← 计算引擎
```

## 导航

- [A/B/C Scratchpad](scratchpads.md) — 双缓冲片上存储、Bank 结构、读写端口
- [Scale Factor Scratchpad](scale-scratchpads.md) — A/B Scale Scratchpad、块缩放因子存储
- [数据流控制器](data-controllers.md) — ADC/BDC/CDC + ASC/BSC 的状态机、地址生成、Hold Register
- [内存加载器](memory-loaders.md) — AML/BML/CML + ASL/BSL 的请求生成、im2col 变换、SCP Fill Table
- [本地内存管理单元](local-mmu.md) — 5 路轮转仲裁、32 项 TLB、Source ID 管理
