# 指令集

CUTE 通过自定义 RoCC 指令扩展 RISC-V ISA，提供矩阵运算加速。指令分为查询/控制类、配置类和中断响应类三类，通过 `funct` 字段区分。

## 导航

- [控制寄存器和ROCC指令编码](instruction-encoding.md)
- [张量融合操作](fusion-operators.md)
- [指令速查表](instruction-reference.md)
