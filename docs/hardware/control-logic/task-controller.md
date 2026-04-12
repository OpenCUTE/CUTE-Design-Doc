# 指令译码与调度（TaskController）

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| MacroInst | 宏指令，描述一次完整矩阵乘法任务（M×N×K、地址、数据类型等） |
| MicroInst | 微指令，由宏指令分解得到的单次 Load/Compute/Store 操作 |
| Tiling | 分块，将大矩阵划分为 SCP 可容纳的 tile 逐步计算 |
| SCP Control Info | 双缓冲选择信号，指示当前使用 SCP[0] 还是 SCP[1] |

## 2. 设计规格

| 参数 | 说明 |
|------|------|
| MacroInst FIFO 深度 | 4 |
| MicroInst FIFO 深度 | 4（Load/Compute/Store 各一个） |
| 支持的宏指令类型 | SEND_MACRO_INST、CONFIG_TENSOR_A/B/C/D、CONFIG_TENSOR_DIM、CONFIG_CONV_PARAMS、CONFIG_SCALE_A/B、CLEAR、QUERY |

## 3. 功能描述

TaskController 是 CUTE 的控制中枢，负责从 CPU 接收矩阵运算指令，分解为硬件可执行的微任务序列，并协调各子模块的执行时序。

核心职责：

1. **指令接收与组装**：通过 RoCC 异构接口接收 CPU 发来的配置指令和计算指令，将多次配置（张量地址、维度、卷积参数等）组装为完整的 MacroInst
2. **宏→微指令分解**：将一条 MacroInst 按分块策略分解为多组 Load/Compute/Store 微指令三元组
3. **三阶段调度**：管理 Load → Compute → Store 三阶段的执行流水线
4. **双缓冲管理**：跟踪 SCP 空闲状态，交替选择 SCP 组

## 4. 微架构设计

### 4.1 指令组装

CPU 通过多条 RoCC 指令逐步配置一个矩阵乘法任务：

| RoCC funct | 内部 funct | 说明 |
|------------|-----------|------|
| 64 | 0 | SEND_MACRO_INST（触发计算） |
| 65 | 1 | CONFIG_TENSOR_A（A 基地址 + 步长） |
| 66 | 2 | CONFIG_TENSOR_B |
| 67 | 3 | CONFIG_TENSOR_C |
| 68 | 4 | CONFIG_TENSOR_D |
| 69 | 5 | CONFIG_TENSOR_DIM（M, N, K + kernel_stride） |
| 70 | 6 | CONFIG_CONV_PARAMS（数据类型、bias、转置、卷积参数） |
| 71-72 | 7-8 | CONFIG_SCALE_A/B |
| 80 | 16 | CLEAR_INST |
| 81 | 17 | QUERY_INST |

配置指令逐步填充 `MacroInst_Reg` 的各字段，`SEND_MACRO_INST` 将完整配置推入 `MacroInst_FIFO`。

### 4.2 Tiling 循环分解

MacroInst 按 tile 大小（`Tensor_M × Tensor_N × Tensor_K`）分解为多个微指令。嵌套循环顺序：

```
for M_tile in range(0, M, Tensor_M):
  for N_tile in range(0, N, Tensor_N):
    for KH in range(kernel_height):        # 卷积专用
      for KW in range(kernel_width):       # 卷积专用
        for K_tile in range(0, K, Tensor_K):
          emit LoadMicroInst
          emit ComputeMicroInst
          emit StoreMicroInst (仅当 KH && KW 循环结束时)
```

**卷积与 GEMM 的区别：**
- GEMM：直接按 M→N→K 三层循环分块
- 卷积：增加 KH→KW 两层循环，并计算 im2col 参数

### 4.3 三阶段 FSM

每个阶段独立的 2 状态 FSM：

```
idle ──(MicroInst 可用 && 所有子模块就绪)──→ issue
                                                    │
                        (所有子模块完成信号) ←───────┘
                              │
                              ▼
                            idle (取下一条微指令)
```

**资源依赖追踪**：三个 FIFO（`LoadMicroInst_Resource_Info_FIFO`、`ComputeMicroInst_Resource_Info_FIFO`、`StoreMicroInst_Resource_Info_FIFO`记录阶段间的资源依赖，确保 Compute 等待对应 Load 完成，Store 等待对应 Compute 完成。

### 4.4 双缓冲管理

TaskController 维护 SCP 空闲状态向量：

```
A_SCP_Free  = Vec(2, Bool())  // SCP[0] 和 SCP[1] 的空闲状态
B_SCP_Free  = Vec(2, Bool())
C_SCP_Free  = Vec(2, Bool())
```

每个 tile 开始时选择空闲的 SCP 组，通过 `SCPControlInfo` 信号广播给所有模块。

## 5. 接口信号

| 信号名 | 方向 | 说明 |
|--------|------|------|
| `ygjkctrl` | Input (Flipped) | RoCC 异构控制接口（来自 CPU，源码中命名为 `ygjkctrl`） |
| `ADC/BDC/CDC_MicroTask_Config` | Output | 各 DataController 的微任务配置 |
| `AML/BML/ASL/BSL/CML_MicroTask_Config` | Output | 各 Loader 的微任务配置 |
| `MTE_MicroTask_Config` | Output | MTE 的微任务配置 |
| `AOP_MicroTask_Config` | Output | AfterOps 的微任务配置 |
| `SCP_CtrlInfo` | Output | Scratchpad 双缓冲选择信号 |

## 6. 与其他模块的交互

TaskController 是 CUTE 的控制中心，与所有模块交互：

```
CPU ──RoCC──→ TaskController ──┬──→ Loaders (AML/BML/ASL/BSL/CML)
                                ├──→ DataControllers (ADC/BDC/CDC/ASC/BSC)
                                ├──→ MatrixTE
                                ├──→ AfterOps
                                └──→ Scratchpad Selection
```

## 7. 参考

- 源码：`src/main/scala/TaskController.scala`
- 参数：`src/main/scala/CUTEParameters.scala`
