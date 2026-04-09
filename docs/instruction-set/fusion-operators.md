# 融合算子说明

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| asyncMatMul | 异步矩阵乘法抽象，CPU 提交任务后可继续执行其他工作 |
| AfterOps | 后处理模块，在 Compute 阶段后对结果执行转置、重排等操作 |
| VectorStreamInterface | 预留的向量流水线接口，用于将结果送入外部 VPU |

## 2. 设计规格

| 特性 | 说明 |
|------|------|
| MacroInst FIFO 深度 | 4（支持最多 4 条异步任务的软件流水线） |
| Bias 加载方式 | ZeroLoad / RepeatRowLoad / FullLoad |
| 数据重排模式 | NoReorder / Reorder_DIM_N_First / Reorder_DIM_M_First |

## 3. 功能描述

### 3.1 异步任务提交

CUTE 采用异步任务模型：软件通过配置指令组装 MacroInst 并提交到 FIFO，硬件自动执行。软件在等待期间可继续执行其他工作（如向量运算、下一个 tile 的配置），实现矩阵-向量交叠执行。

**硬件映射：**

| 抽象 | 硬件实现 |
|------|---------|
| 异步提交任务 | 配置指令序列 + ISSUE_MARCO_INST |
| 查询完成状态 | FIFO_FINISH 查询（返回完成位掩码） |
| 启动执行 | COMPUTE_START |

### 3.2 AfterOps 后处理

AfterOps 模块在 Compute 阶段结束后、Store 阶段之前执行：

| 操作 | 说明 | 状态 |
|------|------|------|
| 转置（Transpose） | 对 MTE 输出进行 M/N 维度转置 | 已实现 |
| 数据重排（Reorder） | 按行优先或列优先重排输出 | 已实现 |
| 缩放（Scale） | 对结果乘以缩放因子 | 规划中 |
| 向量流水线（VecFIFO） | 将结果送入外部 VPU 进行逐元素操作 | 规划中 |

**数据路径：**

```
MatrixTE (D = A×B + C) → AfterOps → [可选: VectorStreamInterface → VPU] → C Scratchpad → Store
```

### 3.3 Bias 加载融合

Bias 加载通过 `bias_type` 参数控制 C 矩阵的加载方式，由 CMemoryLoader 在 Load 阶段完成，无需额外指令开销：

| bias_type | 名称 | 说明 |
|-----------|------|------|
| 0 | Undef | 未定义 |
| 1 | ZeroLoad | C Scratchpad 填零 |
| 2 | RepeatRowLoad | 加载一行并广播到所有行 |
| 3 | FullLoad | 完整加载 C 矩阵 |

### 3.4 卷积 im2col 融合

CUTE 在硬件层面支持卷积运算的 im2col 变换，由 AML（A Memory Loader）根据 (OH, OW, KH, KW) 计算输入特征图物理地址，自动处理零填充。卷积参数通过 CONFIG_CONV 指令一次配置。

## 4. 与其他模块的交互

| 模块 | 方向 | 说明 |
|------|------|------|
| TaskController | ← | 接收 ComputeMicroInst 中的 AfterOps 配置 |
| CDataController | ←→ | 读取/写回 C Scratchpad 数据 |
| VectorStreamInterface | →（预留） | 将结果送入外部 VPU |

## 5. 参考

- 源码：`src/main/scala/AfterOps.scala`
- 任务控制器：`src/main/scala/TaskController.scala`
- 参数定义：`src/main/scala/CUTEParameters.scala`
