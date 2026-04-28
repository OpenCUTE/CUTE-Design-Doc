# 指令速查表

## 1. 指令分类总览

| 类别 | funct 范围 | 处理方 |
|------|-----------|--------|
| 查询/控制 | 0-63 | CUTE2YGJK 直接处理 |
| 配置 | 64-127 | 转发 TaskController |
| 中断响应 | opcode=0x2B, funct=0 | CUTE2YGJK 处理 |

## 2. 查询/控制类（funct 0-63）

| funct | 名称 | 说明 | rd 返回值 |
|-------|------|------|-----------|
| 1 | QUERY_ACCELERATOR_BUSY | 加速器是否忙碌 | 1=忙碌, 0=空闲 |
| 2 | QUERY_RUNTIME | 运行时钟周期数 | 周期计数 |
| 3 | QUERY_MEM_READ_COUNT | 访存读次数 | 读请求计数 |
| 4 | QUERY_MEM_WRITE_COUNT | 访存写次数 | 写请求计数 |
| 5 | QUERY_COMPUTE_TIME | 纯计算周期数 | 计算周期计数 |
| 6 | QUERY_MACRO_INST_FINISH | 宏指令完成情况 | 位掩码 |
| 7 | QUERY_MACRO_INST_FIFO_FULL | FIFO 是否已满 | 1=满, 0=未满 |
| 8 | QUERY_MACRO_INST_FIFO_INFO | FIFO 指令状态 | 位掩码 |

## 3. 配置类（funct 64-127）

| funct | 名称 | cfgData1 | cfgData2 | 说明 |
|-------|------|----------|----------|------|
| 64 | SEND_MACRO_INST | — | — | 提交 MacroInst 到 FIFO |
| 65 | CONFIG_TENSOR_A | A 基地址 | A 步长 | 配置 A 张量 |
| 66 | CONFIG_TENSOR_B | B 基地址 | B 步长 | 配置 B 张量 |
| 67 | CONFIG_TENSOR_C | C 基地址 | C 步长 | 配置 C (bias) |
| 68 | CONFIG_TENSOR_D | D 基地址 | D 步长 | 配置 D (输出) |
| 69 | CONFIG_TENSOR_DIM | M\|N\|K | kernel_stride | 配置维度 |
| 70 | CONFIG_CONV_PARAMS | 类型/卷积参数 | 卷积参数 | 配置数据类型和卷积 |
| 71 | CONFIG_SCALE_A | Scale A 基地址 | — | 配置 A 缩放因子 |
| 72 | CONFIG_SCALE_B | Scale B 基地址 | — | 配置 B 缩放因子 |
| 80 | CLEAR_INST | — | — | 清除队尾宏指令 |
| 81 | QUERY_INST | — | — | 查询已完成宏指令的尾编号 |

## 4. 中断响应（opcode 0x2B）

| funct | 名称 | 说明 |
|-------|------|------|
| 0 | INTERRUPT_ACK | 确认中断，回到空闲状态 |

## 5. bias_type 编码

| 值 | 名称 | 说明 |
|----|------|------|
| 0 | Undef | 未定义 |
| 1 | ZeroLoad | C Scratchpad 填零（无 bias） |
| 2 | RepeatRowLoad | 加载单行并广播（bias 向量） |
| 3 | FullLoad | 完整加载 C 矩阵（D = A×B + C） |

## 6. 数据类型编码

| 值 | 名称 | A 类型 | B 类型 | 累加类型 | A/B 位宽 | 需要 Scale |
|----|------|--------|--------|---------|---------|-----------|
| 0 | I8I8I32 | INT8 | INT8 | INT32 | 8 bit | 否 |
| 1 | F16F16F32 | FP16 | FP16 | FP32 | 16 bit | 否 |
| 2 | BF16BF16F32 | BF16 | BF16 | FP32 | 16 bit | 否 |
| 3 | TF32TF32F32 | TF32 | TF32 | FP32 | 32 bit | 否 |
| 4 | I8U8I32 | INT8 | UINT8 | INT32 | 8 bit | 否 |
| 5 | U8I8I32 | UINT8 | INT8 | INT32 | 8 bit | 否 |
| 6 | U8U8I32 | UINT8 | UINT8 | INT32 | 8 bit | 否 |
| 7 | Mxfp8e4m3F32 | MXFP8 E4M3 | MXFP8 E4M3 | FP32 | 8 bit | 是 (GroupSize=32) |
| 8 | Mxfp8e5m2F32 | MXFP8 E5M2 | MXFP8 E5M2 | FP32 | 8 bit | 是 (GroupSize=32) |
| 9 | nvfp4F32 | NVFP4 | NVFP4 | FP32 | 4 bit | 是 (GroupSize=16) |
| 10 | mxfp4F32 | MXFP4 | MXFP4 | FP32 | 4 bit | 是 (GroupSize=32) |
| 11 | fp8e4m3F32 | FP8 E4M3 | FP8 E4M3 | FP32 | 8 bit | 否 |
| 12 | fp8e5m2F32 | FP8 E5M2 | FP8 E5M2 | FP32 | 8 bit | 否 |

## 7. CONFIG_TENSOR_DIM 字段速查

### cfgData1

```
[59:40] Application_K     归约维度
[39:20] Application_N     列维度
[19:0]  Application_M     行维度
```

### cfgData2

```
[63:0]  kernel_stride     卷积核步长（矩阵乘时为 0）
```

## 8. CONFIG_CONV_PARAMS 字段速查

### cfgData1

```
[63:48] conv_ow_max       输出宽度维度
[47:32] conv_oh_max       输出高度维度
[31:24] conv_stride       卷积步长
[23:16] transpose_result  结果转置
[15:8]  bias_type         Bias 加载类型
[7:0]   element_type      数据类型编码
```

### cfgData2

```
[55:46] conv_ow_index     输出宽度起始值
[45:36] conv_oh_index     输出高度起始值
[35:26] conv_ow_per_add   OW 预计算递增
[25:16] conv_oh_per_add   OH 预计算递增
[7:0]   kernel_size       卷积核大小
```

## 9. 参考

- 详细编码说明：[控制寄存器和ROCC指令编码](instruction-encoding.md)
- 指令定义源码：`src/main/scala/CUTEParameters.scala`
- 张量操作融合说明：[张量操作融合说明](fusion-operators.md)
