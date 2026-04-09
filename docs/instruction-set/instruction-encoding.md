# CUTE 自定义指令编码

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| RoCC | Rocket Custom Coprocessor，Rocket 的协处理器接口协议 |
| funct | RoCC 指令中的功能码字段（7 bit），决定具体操作 |
| MacroInst | 宏指令，描述一次完整矩阵乘法/卷积任务 |
| MicroInst | 微指令，由宏指令分解得到的 Load/Compute/Store 操作 |

## 2. 设计规格

| 参数 | 说明 |
|------|------|
| opcode | `0x0B`（CUSTOM0）用于配置/查询/计算；`0x2B`（CUSTOM1）用于中断响应 |
| 指令格式 | R-type（32 bit） |
| 寄存器约定 | rs1=x6(t1)=cfgData1, rs2=x7(t2)=cfgData2, rd=x5(t0)=返回值 |
| funct 编码空间 | 0-63 为查询/控制类；64-127 为配置类 |
| MacroInst FIFO 深度 | 4 |

## 3. 功能描述

### 3.1 指令编码格式

```
 31        25 24    20 19    15 14 13 12 11    7 6      0
┌───────────┬────────┬────────┬──┬──┬──┬────────┬────────┐
│  funct7   │  rs2   │  rs1   │xs2│xs1│xd│  rd   │ opcode│
└───────────┴────────┴────────┴──┴──┴──┴────────┴────────┘
```

| 字段 | 位范围 | 说明 |
|------|--------|------|
| `opcode` | [6:0] | `0x0B`（CUSTOM0）或 `0x2B`（CUSTOM1） |
| `rd` | [11:7] | 目标寄存器，固定为 x5(t0) |
| `xd` | [12] | 目标寄存器有效位 |
| `xs1` | [13] | 源寄存器 1 有效位，固定为 1 |
| `xs2` | [14] | 源寄存器 2 有效位，固定为 1 |
| `rs1` | [19:15] | 源寄存器 1，固定为 x6(t1)，映射为 `cfgData1` |
| `rs2` | [24:20] | 源寄存器 2，固定为 x7(t2)，映射为 `cfgData2` |
| `funct7` | [31:25] | 功能选择字段 |

### 3.2 查询/控制类指令（funct 0-63）

| funct | 名称 | 功能 | 返回值 (rd) |
|-------|------|------|-------------|
| 0 | COMPUTE_START | 启动加速器执行 FIFO 中的 MacroInst | 无 |
| 1 | IS_RUNNING | 查询加速器是否忙碌 | `ac_busy` |
| 2 | RUNNING_CYCLES | 查询总运行周期数 | 总 cycle 计数 |
| 3 | MEM_READ_COUNT | 查询外部内存读请求数 | `memNum_r` |
| 4 | MEM_WRITE_COUNT | 查询外部内存写请求数 | `memNum_w` |
| 5 | COMPUTE_CYCLES | 查询纯计算周期数 | compute cycle 计数 |
| 6 | FIFO_FINISH | 查询已完成的 MacroInst 位掩码 | `InstFIFO_Finish` |
| 7 | FIFO_FULL | 查询 MacroInst FIFO 是否已满 | `InstFIFO_Full` |
| 8 | FIFO_VALID | 查询 FIFO 中有效指令数 | `InstFIFO_Info` |

### 3.3 配置类指令（funct 64-127）

配置类指令通过连续的多条指令组装一个 MacroInst，最后通过 `ISSUE_MARCO_INST` 提交到 FIFO。

**配置顺序：**

```
CONFIG_A_TENSOR → CONFIG_B_TENSOR → CONFIG_C_TENSOR → CONFIG_D_TENSOR
       ↓                ↓                ↓                ↓
CONFIG_MNK_KERNEL → CONFIG_CONV → ISSUE_MARCO_INST → COMPUTE_START
```

| funct | sub-funct | 名称 | cfgData1 (rs1) | cfgData2 (rs2) |
|-------|-----------|------|----------------|----------------|
| 64 | 0 | ISSUE_MARCO_INST | — | — |
| 65 | 1 | CONFIG_A_TENSOR | A 基地址 | A 步长 |
| 66 | 2 | CONFIG_B_TENSOR | B 基地址 | B 步长 |
| 67 | 3 | CONFIG_C_TENSOR | C 基地址 | C 步长 |
| 68 | 4 | CONFIG_D_TENSOR | D 基地址 | D 步长 |
| 69 | 5 | CONFIG_MNK_KERNEL | M[19:0] \| N[39:20] \| K[59:40] | kernel_stride |
| 70 | 6 | CONFIG_CONV | 见下方位段 | 见下方位段 |
| 80 | 16 | FIFO_DEQUEUE | — | — |
| 81 | 17 | FIFO_GET_TAIL_INDEX | — | — |

**CONFIG_CONV 指令的 cfgData1 位段：**

| 位段 | 字段 | 说明 |
|------|------|------|
| [7:0] | `element_type` | 数据类型编码（3 bit） |
| [15:8] | `bias_type` | Bias 加载类型（4 bit） |
| [23:16] | `transpose_result` | 结果转置标志 |
| [31:24] | `conv_stride` | 卷积步长 |
| [47:32] | `conv_oh_max` | 卷积输出高度 OH 维度 |
| [63:48] | `conv_ow_max` | 卷积输出宽度 OW 维度 |

**CONFIG_CONV 指令的 cfgData2 位段：**

| 位段 | 字段 | 说明 |
|------|------|------|
| [3:0] | `kernel_size` | 卷积核大小 |
| [18:4] | `conv_oh_per_add` | 预计算的 OH 递增量 |
| [33:19] | `conv_ow_per_add` | 预计算的 OW 递增量 |
| [48:34] | `conv_oh_index` | 当前 OH 索引 |
| [63:49] | `conv_ow_index` | 当前 OW 索引 |

### 3.4 中断响应指令（opcode 0x2B）

| funct | 名称 | 功能 |
|-------|------|------|
| 0 | INTERRUPT_ACK | 确认中断，加速器从 `jk_resp` 返回 `jk_idle` 状态 |

## 4. 微架构设计

### 4.1 MacroInst 结构

MacroInst 是 CUTE 的核心任务描述单元：

| 字段 | 位宽 | 说明 |
|------|------|------|
| `A/B/C/D_BaseVaddr` | 64 bit ×4 | 各矩阵基地址 |
| `A/B/C/D_Stride` | 64 bit ×4 | 各矩阵步长 |
| `M/N/K` | 17 bit ×3 | 矩阵维度 |
| `element_type` | 3 bit | 数据类型编码 |
| `bias_type` | 4 bit | Bias 加载类型 |
| `transpose_result` | 1 bit | 结果转置标志 |
| `kernel_size` / `kernel_stride` | 4+64 bit | 卷积核参数 |

### 4.2 Macro-to-Micro 分解

TaskController 将每条 MacroInst 按以下循环分解为微指令序列：

```
for OH/OW (or M position):
  for N_tile (step = Tensor_N):
    for KH × KW (conv only):
      for K_tile (step = Tensor_K / element_bytes):
        → LoadMicroInst
        → ComputeMicroInst
    → StoreMicroInst
```

相邻 tile 的 Load 和 Compute 通过双缓冲 Scratchpad 重叠执行。

### 4.3 状态机

```
         COMPUTE_START          acc_running=false
jk_idle ──────────────→ jk_compute ─────────────→ jk_resp
  ↑                                                  │
  └──────────── INTERRUPT_ACK (opcode=0x2B) ←─────────┘
```

| 状态 | 说明 |
|------|------|
| `jk_idle` | 空闲，等待 COMPUTE_START |
| `jk_compute` | 执行中，处理 FIFO 中的 MacroInst |
| `jk_resp` | 全部完成，等待中断确认 |

## 5. 与其他模块的交互

```
CPU ──RoCC──→ CUTE2YGJK ──RoCCControl──→ TaskController
                │
                └──Cute2TL──→ TileLink Bus ──→ LLC/DRAM
```

## 6. 参考

- 源码：`src/main/scala/CUTE2YGJK.scala`
- 参数定义：`src/main/scala/CUTEParameters.scala`
- 任务控制器：`src/main/scala/TaskController.scala`
- 软件头文件：`cutetest/base_test/ygjk.h`
- 软件辅助宏：`cutetest/base_test/cuteMarcoinstHelper.h`
