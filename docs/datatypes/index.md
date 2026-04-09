# 数据类型

CUTE 支持 13 种数据类型，4-bit 编码（`DataTypeBitWidth = 4`），覆盖从低精度整数到微缩放浮点（MXFP/NVFP）的广泛范围。所有类型均以 FP32（或 INT32）作为累加精度。

其中编码 7-10 为块缩放（microscaling）数据类型，需要 Scale 子系统配合：Scale Scratchpad 存储缩放因子，Scale Loader 负责搬运，Scale Controller 在计算时将缩放因子传递给 MTE。

## 导航

| 文档 | 说明 |
|------|------|
| [精度格式总览](precision-formats.md) | 所有 13 种数据类型的编码格式与位宽对比 |
| [量化与 Block-Scale](quantization.md) | 整数量化机制与块缩放（MXFP/NVFP）的硬件实现 |
| [数据类型支持矩阵](datatype-support.md) | 各模块对各数据类型的支持情况与兼容性规则 |
