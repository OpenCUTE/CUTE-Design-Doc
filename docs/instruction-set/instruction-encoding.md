# CUTE 自定义指令编码

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| RoCC | Rocket Custom Coprocessor，Rocket 的协处理器接口协议 |
| funct | RoCC 指令中的功能码字段（7 bit），决定具体操作 |
| cfgData1 / cfgData2 | 指令的两个 64 位立即数操作数，分别通过 rs1 (x6) 和 rs2 (x7) 传递 |
| MacroInst | 宏指令，描述一次完整矩阵乘法/卷积任务 |

## 2. 指令编码格式

所有 CUTE 自定义指令均为 R-type 32 位格式：

| 字段 | 位范围 | 说明 |
|------|--------|------|
| `opcode` | [6:0] | `0x0B`（CUSTOM0） |
| `rd` | [11:7] | 目标寄存器，固定为 x5(t0) |
| `xd` | [12] | 目标寄存器有效位 |
| `xs1` | [13] | 源寄存器 1 有效位，固定为 1 |
| `xs2` | [14] | 源寄存器 2 有效位，固定为 1 |
| `rs1` | [19:15] | 源寄存器 1，固定为 x6(t1)，传递 cfgData1 |
| `rs2` | [24:20] | 源寄存器 2，固定为 x7(t2)，传递 cfgData2 |
| `funct7` | [31:25] | 功能选择字段 |

**funct7 编码空间划分：**

| funct7 范围 | 类别 | 处理方式 |
|-------------|------|---------|
| 0-63 | 查询/控制类 | CUTE2YGJK 直接处理 |
| 64-127 | 配置类 | 转发到 TaskController（去掉 bit6 后为内部 funct 0-63） |

## 3. 查询/控制类指令（funct 0-63）

| funct | 名称 | 功能 | 返回值 (rd) |
|-------|------|------|-------------|
| 1 | QUERY_ACCELERATOR_BUSY | 查询加速器是否正在运行 | 1=忙碌, 0=空闲 |
| 2 | QUERY_RUNTIME | 查询加速器运行时钟周期数 | 周期计数 |
| 3 | QUERY_MEM_READ_COUNT | 查询对外访存读次数 | 读请求计数 |
| 4 | QUERY_MEM_WRITE_COUNT | 查询对外访存写次数 | 写请求计数 |
| 5 | QUERY_COMPUTE_TIME | 查询纯计算时钟周期数 | 计算周期计数 |
| 6 | QUERY_MACRO_INST_FINISH | 查询宏指令完成情况 | 位掩码（如 0010 表示 id=1 已完成） |
| 7 | QUERY_MACRO_INST_FIFO_FULL | 查询宏指令队列是否已满 | 1=满, 0=未满 |
| 8 | QUERY_MACRO_INST_FIFO_INFO | 查询宏指令队列当前指令数 | 位掩码（如 0010 表示 id=1 位置已有指令） |

## 4. 配置类指令（funct 64-127）

配置类指令通过连续的多条指令组装一个 MacroInst，最后通过 `SEND_MACRO_INST` 提交到 FIFO。

**配置流程：**

```
CONFIG_TENSOR_A → CONFIG_TENSOR_B → CONFIG_TENSOR_C → CONFIG_TENSOR_D
       ↓                ↓                ↓                ↓
CONFIG_TENSOR_DIM → CONFIG_CONV_PARAMS → CONFIG_SCALE_A/B (可选)
       ↓
SEND_MACRO_INST → (循环配置下一条 MacroInst)
```

### 4.1 指令总表

| funct | 内部 funct | 名称 | 说明 |
|-------|-----------|------|------|
| 64 | 0 | SEND_MACRO_INST | 发送已配置的宏指令到 FIFO |
| 65 | 1 | CONFIG_TENSOR_A | 配置 A 张量的基地址和步长 |
| 66 | 2 | CONFIG_TENSOR_B | 配置 B 张量的基地址和步长 |
| 67 | 3 | CONFIG_TENSOR_C | 配置 C 张量的基地址和步长 |
| 68 | 4 | CONFIG_TENSOR_D | 配置 D 张量的基地址和步长 |
| 69 | 5 | CONFIG_TENSOR_DIM | 配置张量维度 (M, N, K) |
| 70 | 6 | CONFIG_CONV_PARAMS | 配置数据类型、卷积参数 |
| 71 | 7 | CONFIG_SCALE_A | 配置 A Scale 的基地址 |
| 72 | 8 | CONFIG_SCALE_B | 配置 B Scale 的基地址 |
| 80 | 16 | CLEAR_INST | 清除队尾的宏指令 |
| 81 | 17 | QUERY_INST | 查询已完成宏指令的尾编号位置 |

### 4.2 张量配置指令字段

CONFIG_TENSOR_A/B/C/D 共享相同的字段格式：

**cfgData1：**

| 位段 | 字段 | 说明 |
|------|------|------|
| [63:0] | BaseVaddr | 张量基地址 |

**cfgData2：**

| 位段 | 字段 | 说明 |
|------|------|------|
| [63:0] | Stride | 张量步长 |

### 4.3 CONFIG_TENSOR_DIM 字段

**cfgData1：**

| 位段 | 字段 | 说明 |
|------|------|------|
| [19:0] | Application_M | 张量 M 维度（矩阵乘时为行数） |
| [39:20] | Application_N | 张量 N 维度（矩阵乘时为列数） |
| [59:40] | Application_K | 张量 K 维度（归约维度） |

**cfgData2：**

| 位段 | 字段 | 说明 |
|------|------|------|
| [63:0] | kernel_stride | 卷积核步长（矩阵乘时填 0） |

### 4.4 CONFIG_CONV_PARAMS 字段

**cfgData1：**

| 位段 | 字段 | 说明 |
|------|------|------|
| [7:0] | element_type | 数据类型编码（见数据类型章节） |
| [15:8] | bias_type | 偏置加载类型（0=未定义, 1=填零, 2=行广播, 3=完整加载） |
| [23:16] | transpose_result | 结果转置标志（0=不转置, 1=转置） |
| [31:24] | conv_stride | 卷积步长 |
| [47:32] | conv_oh_max | 卷积输出高度最大值 |
| [63:48] | conv_ow_max | 卷积输出宽度最大值 |

**cfgData2：**

| 位段 | 字段 | 说明 |
|------|------|------|
| [7:0] | kernel_size | 卷积核大小 |
| [25:16] | conv_oh_per_add | 输出高度每次增加量 |
| [35:26] | conv_ow_per_add | 输出宽度每次增加量 |
| [45:36] | conv_oh_index | 输出高度起始值 |
| [55:46] | conv_ow_index | 输出宽度起始值 |

### 4.5 CONFIG_SCALE_A / CONFIG_SCALE_B 字段

**cfgData1：**

| 位段 | 字段 | 说明 |
|------|------|------|
| [63:0] | Scale_BaseVaddr | 缩放因子基地址 |

cfgData2 未使用。

## 5. 中断响应指令（opcode 0x2B）

| funct | 名称 | 功能 |
|-------|------|------|
| 0 | INTERRUPT_ACK | 确认中断，加速器回到空闲状态 |

## 6. 头文件自动生成

CUTE 提供头文件自动生成工具，从 `CUTEParameters.scala` 中的指令定义自动生成 C 语言头文件：

- **`datatype.h.generated`**：13 种数据类型枚举和位宽查询宏
- **`validation.h.generated`**：硬件参数常量（Tensor 维度、SCP 配置、MMU 参数等）
- **`instruction.h.generated`**：指令 funct 常量、字段位段定义、提取/组装宏、包装函数

**使用方法：**

```bash
cd chipyard && source env.sh
./scripts/generate-headers.sh [CONFIG_NAME] [OUTPUT_DIR]
# 默认：chipyard.CUTE2TopsSCP64Config → cutetest/include/
```

## 7. 参考

- 指令定义：`src/main/scala/CUTEParameters.scala`（`CuteInstConfigs`、`YGJKInstConfigs`）
- 头文件生成：`src/main/scala/util/HeaderGenerator.scala`
- 生成脚本：`scripts/generate-headers.sh`
