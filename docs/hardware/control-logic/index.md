# 控制逻辑

CUTE 的控制逻辑负责接收 CPU 指令、分解为微任务、调度执行。

## 模块总览

![ctrl](ctrl.png)

## 导航

- [指令译码与调度](task-controller.md) — MacroInst 组装、微指令分解、三阶段调度、SCP 双缓冲控制
- [RoCC 接口](cute2ygjk.md) — RoCC 协议适配、指令编码、TileLink 客户端
