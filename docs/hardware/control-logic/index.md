# 控制逻辑

CUTE 的控制逻辑负责接收 CPU 指令、分解为微任务、调度执行，并提供可配置的硬件参数体系。

## 模块总览

```
CPU (RoCC 指令)
  ↓
CUTE2YGJK (RoCC 协议适配)
  ↓
TaskController (MacroInst → Load/Compute/Store 微指令三元组)
  ↓
┌───────────────────┬──────────────────┬──────────────────┐
  MemoryLoaders       DataControllers     ScaleControllers
  (AML/BML/CML)       (ADC/BDC/CDC)       (ASC/BSC)
  (Load Phase)        (Compute Phase)     (Compute Phase)
```

## 导航

- [指令译码与调度](task-controller.md) — MacroInst 组装、微指令分解、三阶段调度、SCP 双缓冲控制
- [硬件参数配置](cute-parameters.md) — 核心维度参数、Scale 参数、性能预设、13 种数据类型编码、LocalMMU 任务类型
- [RoCC 接口](cute2ygjk.md) — RoCC 协议适配、指令编码、TileLink 客户端
