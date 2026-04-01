# YGJK / RoCC 接口

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| YGJK | CUTE 的自定义指令扩展名称 |
| RoCC | Rocket Custom Coprocessor，Rocket 的协处理器接口协议 |
| TileLink | RISC-V 芯片内互连总线协议 |
| funct | RoCC 指令中的功能码字段 |

## 2. 设计规格

| 参数 | 说明 |
|------|------|
| 指令接口 | RoCC（Rocket Custom Coprocessor） |
| 备选接口 | CSR（用于非 RoCC 平台如香山） |
| 数据宽度 | 64 bit（RoCC 寄存器宽度） |
| 地址宽度 | 64 bit |
| TileLink 位宽 | 可配置（`outsideDataWidth`，默认 512 bit） |

## 3. 功能描述

CUTE2YGJK 是 CUTE 与 CPU 之间的协议适配层，将 CPU 发出的 RoCC 指令转换为 CUTE 内部控制信号。

### 3.1 指令分发

RoCC 指令的 `funct` 字段决定指令类型：

| funct 范围 | 目标 | 说明 |
|-----------|------|------|
| 0-63 | YGJK 查询处理器 | 状态查询指令（直接 RoCC 响应） |
| ≥64 | CUTE 内部命令 | 取低 6 位作为内部 funct（0-18） |

### 3.2 YGJK 查询指令

| funct | 名称 | 说明 |
|-------|------|------|
| 1 | QueryAcceleratorBusy | 查询加速器是否忙碌 |
| 2 | QueryRuntime | 查询运行时间 |
| 3 | QueryMemReadCount | 查询内存读次数 |
| 4 | QueryMemWriteCount | 查询内存写次数 |
| 5 | QueryComputeTime | 查询计算时间 |
| 6 | QueryMacroInstFinish | 查询宏指令完成数 |
| 7 | QueryMacroInstFIFOFull | 查询宏指令 FIFO 是否已满 |
| 8 | QueryMacroInstFIFOInfo | 查询 FIFO 详细信息 |

### 3.3 CUTE 内部命令

| 内部 funct | 名称 | 说明 |
|-----------|------|------|
| 0 | SEND_MACRO_INST | 发送宏指令（触发计算） |
| 1-4 | CONFIG_TENSOR_A/B/C/D | 配置张量地址和步长 |
| 5 | CONFIG_TENSOR_DIM | 配置张量维度 |
| 6 | CONFIG_CONV_PARAMS | 配置卷积参数（数据类型、bias、转置等） |
| 7-8 | CONFIG_SCALE_A/B | 配置缩放因子地址 |
| 16 | CLEAR_INST | 清除指令 |
| 17 | QUERY_INST | 内部查询 |

## 4. 微架构设计

### 4.1 协议栈

```
CPU (RISC-V)
    │ RoCC 指令 (funct + rs1 + rs2 + rd)
    ▼
RoCC2CUTE ─── 指令分发
    ├── funct 0-63 ──→ YGJK 查询响应 (直接返回)
    └── funct ≥64  ──→ CUTE 内部控制 ──→ TaskController
                                                    │
                                                    ▼
                                            Cute2TL ──→ TileLink Bus ──→ LLC/DRAM
```

### 4.2 关键组件

| 组件 | 功能 |
|------|------|
| `RoCC2CUTE` | RoCC 命令解码，分发到查询/计算路径 |
| `Cute2TL` | TileLink Master 适配器，处理内存访问 |
| `CUTE2TLImp` | LazyModule 实现，连接到 TileLink 总线 |
| `CUTETile` | 包装 CUTEV2Top + RoCC 接口的顶层模块 |

### 4.3 Source ID 管理

- 维护 in-flight TileLink 事务的 Source ID 映射
- 一致性请求和非一致性请求使用不同的 ID 范围
- 响应通过 Source ID 匹配路由回正确的请求方

## 5. 接口寄存器（论文定义）

| 字段 | 类型 | 说明 |
|------|------|------|
| {M, N, K} | uint32 | 矩阵维度 |
| Base{A, B, Bias, C} | uint64 | 内存基地址 |
| Stride{A, B, Bias, C} | uint32 | 内存步长 |
| DataType | enum | 数据精度 |
| BiasType | enum | Bias 类型（Zero/Row-Repeat/Full） |
| Transpose | bool | 结果转置标志 |
| Status | uint32 | 异步操作状态 |

## 6. 编程模型

CUTE 的异步编程模型仅需两类指令：

```c
// 异步发起矩阵乘法
asyncMatMul(M, N, K, BaseA, BaseB, BaseC, BaseD, ...);

// 同步等待完成
checkMatmul();

// 查询状态
status = queryAcceleratorBusy();
```

**矩阵-向量交叠执行模式：**

```c
asyncMatMul(TILE_M, TILE_N, K, ...);     // tile 0
for (i=1; i<num_tiles; i++) {
    asyncMatMul(TILE_M, TILE_N, K, ...); // tile i
    checkMatmul();                        // 等待 tile i-1 完成
    // 向量单元处理 tile i-1 的 epilogue
}
checkMatmul();                            // 等待最后一个 tile
```

## 7. 与其他模块的交互

```
CPU ──RoCC──→ CUTE2YGJK ──YGJKControl──→ TaskController
                  │
                  └──Cute2TL──→ TileLink Bus ──→ LLC/DRAM
```

## 8. 参考

- 源码：`src/main/scala/CUTE2YGJK.scala`、`src/main/scala/config_ygjk.scala`
- 论文：CUTE v2 (DAC 2025) — Section 3 Architecture Overview
