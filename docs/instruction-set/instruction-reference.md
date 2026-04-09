# 指令速查表

## 1. 完整指令列表

### 查询/控制类（opcode 0x0B, funct[6] == 0）

| funct | 名称 | rs1 (x6) | rs2 (x7) | rd (x5) 返回值 | 功能 |
|-------|------|----------|----------|---------------|------|
| 0 | COMPUTE_START | — | — | — | 启动加速器执行 |
| 1 | IS_RUNNING | — | — | ac_busy | 查询是否忙碌 |
| 2 | RUNNING_CYCLES | — | — | count | 总运行周期 |
| 3 | MEM_READ_COUNT | — | — | memNum_r | 内存读请求数 |
| 4 | MEM_WRITE_COUNT | — | — | memNum_w | 内存写请求数 |
| 5 | COMPUTE_CYCLES | — | — | compute | 纯计算周期 |
| 6 | FIFO_FINISH | — | — | finish_mask | 完成位掩码 |
| 7 | FIFO_FULL | — | — | full_flag | FIFO 是否已满 |
| 8 | FIFO_VALID | — | — | valid_count | FIFO 有效指令数 |

### 配置类（opcode 0x0B, funct[6] == 1）

| funct | sub-funct | 名称 | rs1 (x6) | rs2 (x7) | 功能 |
|-------|-----------|------|----------|----------|------|
| 64 | 0 | ISSUE_MARCO_INST | — | — | 提交 MacroInst |
| 65 | 1 | CONFIG_A_TENSOR | A 基地址 | A 步长 | 配置 A 矩阵 |
| 66 | 2 | CONFIG_B_TENSOR | B 基地址 | B 步长 | 配置 B 矩阵 |
| 67 | 3 | CONFIG_C_TENSOR | C 基地址 | C 步长 | 配置 C (bias) |
| 68 | 4 | CONFIG_D_TENSOR | D 基地址 | D 步长 | 配置 D (输出) |
| 69 | 5 | CONFIG_MNK_KERNEL | M\|N\|K | kernel_stride | 配置维度 |
| 70 | 6 | CONFIG_CONV | 类型/卷积参数 | kernel/索引参数 | 配置数据类型和卷积 |
| 80 | 16 | FIFO_DEQUEUE | — | — | 移除已完成 MacroInst |
| 81 | 17 | FIFO_GET_TAIL_INDEX | — | — | 获取 FIFO 尾部索引 |

### 中断响应（opcode 0x2B）

| funct | 名称 | 功能 |
|-------|------|------|
| 0 | INTERRUPT_ACK | 确认中断，回到空闲状态 |

## 2. bias_type 编码

| 值 | 名称 | 说明 |
|----|------|------|
| 0 | Undef | 未定义 |
| 1 | ZeroLoad | C Scratchpad 填零（无 bias） |
| 2 | RepeatRowLoad | 加载单行并广播（bias 向量） |
| 3 | FullLoad | 完整加载 C 矩阵（D = A×B + C） |

## 3. 数据类型编码

| 值 | 名称 | A/B 类型 | C/D 类型 | 字节宽度 (A/B) | 字节宽度 (C/D) |
|----|------|---------|---------|---------------|---------------|
| 0 | I8I8I32 | INT8 | INT32 | 1 | 4 |
| 1 | F16F16F32 | FP16 | FP32 | 2 | 4 |
| 2 | BF16BF16F32 | BF16 | FP32 | 2 | 4 |
| 3 | TF32TF32F32 | TF32 | FP32 | 4 | 4 |
| 4 | I8U8I32 | INT8/UINT8 | INT32 | 1 | 4 |
| 5 | U8I8I32 | UINT8/INT8 | INT32 | 1 | 4 |
| 6 | U8U8I32 | UINT8 | INT32 | 1 | 4 |
| 7 | e4m3F32 | FP8 E4M3 | FP32 | 1 | 4 |

## 4. CONFIG_CONV 字段速查

### cfgData1 (rs1)

```
[63:48] conv_ow_max     输出宽度维度
[47:32] conv_oh_max     输出高度维度
[31:24] conv_stride     卷积步长
[23:16] transpose_result 结果转置
[15:8]  bias_type       Bias 加载类型
[7:0]   element_type    数据类型编码
```

### cfgData2 (rs2)

```
[63:49] conv_ow_index   当前 OW 索引
[48:34] conv_oh_index   当前 OH 索引
[33:19] conv_ow_per_add OW 预计算递增
[18:4]  conv_oh_per_add OH 预计算递增
[3:0]   kernel_size     卷积核大小
```

## 5. 参考

- 详细编码说明：[CUTE 自定义指令编码](instruction-encoding.md)
- 融合算子说明：[融合算子说明](fusion-operators.md)
