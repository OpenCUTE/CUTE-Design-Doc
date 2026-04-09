# 术语表

## 1. 项目与架构

| 术语 | 英文 | 说明 |
|------|------|------|
| CUTE | CPU-centric and Ultra-utilized Tensor Engine | 本项目的加速器名称 |
| UCME | Unified and Configurable Matrix Extension | CUTE 的学术论文名称 |
| RoCC | Rocket Custom Coprocessor | RISC-V 自定义协处理器接口协议，CUTE 通过此接口与 CPU 通信 |
| TileLink | — | RISC-V 芯片内互连总线协议，CUTE 通过 TileLink 访问主存 |
| CSR | Control and Status Register | 控制状态寄存器，香山核通过 CSR 接口与 CUTE 通信（论文规划） |
| TCM | Tightly Coupled Memory | 紧耦合内存，Shuttle 核集成的低延迟片上存储 |

## 2. 硬件模块

| 术语 | 英文 | 说明 |
|------|------|------|
| MTE | Matrix Tensor Engine | 矩阵张量引擎，CUTE 的核心计算模块，包含 M×N 个 PE |
| PE | Processing Element | 处理单元，执行乘加运算的基本单元 |
| FReducePE | Float Reduce Processing Element | 支持多精度浮点的归约 PE，CUTE 当前使用的 PE 实现 |
| TaskController | — | 指令译码与调度模块，接收 CPU 指令并分解为微任务 |
| LocalMMU | Local Memory Management Unit | 本地内存管理单元，负责地址翻译和多路访存仲裁 |
| TLB | Translation Lookaside Buffer | 地址翻译缓存，LocalMMU 内部维护 32 项 CAM 结构 |
| AfterOps | — | 后处理模块，执行转置、重排等操作 |

## 3. 存储系统

| 术语 | 英文 | 说明 |
|------|------|------|
| Scratchpad | — | 便笺式存储器，片上 SRAM，用于暂存矩阵 tile 数据 |
| SCP | Scratchpad | Scratchpad 的缩写 |
| 双缓冲 | Double Buffering | 每种 Scratchpad 实例化 ×2，交替使用以实现 Load/Compute 流水线重叠 |
| Scale Scratchpad | — | 缩放因子存储器，存储块缩放数据类型的共享缩放因子 |
| Bank | — | 存储体的分库，支持并行读写以提供足够带宽 |
| Slice | — | Scratchpad 的读出分片，每个 Slice 对应一部分 ReduceGroup 数据 |
| SCP Fill Table | — | 用于将宽内存响应拆分写入窄 SCP Bank 的映射表 |

| 模块缩写 | 全称 | 说明 |
|---------|------|------|
| ASP / BSP / CSP | A/B/C Scratchpad | 数据暂存 |
| ASSP / BSSP | A/B Scale Scratchpad | 缩放因子暂存 |
| ADC / BDC / CDC | A/B/C DataController | 数据控制器，从 SCP 向 MTE 供数 |
| ASC / BSC | A/B ScaleController | 缩放因子控制器，从 Scale SCP 向 MTE 供数 |
| AML / BML / CML | A/B/C MemoryLoader | 内存加载器，搬运数据矩阵 |
| ASL / BSL | A/B ScaleLoader | 内存加载器，搬运缩放因子 |

## 4. 数据类型与量化

| 术语 | 英文 | 说明 |
|------|------|------|
| ElementDataType | — | CUTE 的数据类型枚举，4-bit 编码，定义 13 种类型 |
| DataTypeBitWidth | — | 数据类型编码位宽，当前为 4 |
| MXFP | Microscaling Floating Point | OCP 定义的微缩放浮点格式，每 N 个元素共享一个缩放因子 |
| NVFP | NVIDIA Microscaling Floating Point | NVIDIA 定义的微缩放 FP4 格式 |
| Block-Scale | — | 块缩放，每 N 个连续元素共享一个缩放因子的量化机制 |
| ScaleFactor | — | 缩放因子，用于块缩放数据类型的逐块缩放 |
| ScaleWidth | — | 每个 ReduceGroup 对应的缩放因子位宽 |
| ScaleVecWidth | — | 每个 PE 每周期接受的缩放因子宽度，由数据类型决定 |
| ReduceWidthByte | — | 每个 PE 的归约通道字节宽度（默认 32） |
| ReduceGroupSize | — | 归约分组数，`Tensor_K / ReduceWidthByte` |
| E4M3 | Exponent-4 Mantissa-3 | 8-bit 浮点格式（4-bit 指数，3-bit 尾数），无 NaN/Inf |
| E5M2 | Exponent-5 Mantissa-2 | 8-bit 浮点格式（5-bit 指数，2-bit 尾数），支持 NaN/Inf |

## 5. 指令与编程

| 术语 | 英文 | 说明 |
|------|------|------|
| MacroInst | Macro Instruction | 宏指令，描述一次完整矩阵乘法或卷积任务 |
| MicroInst | Micro Instruction | 微指令，由宏指令分解得到的单次 Load/Compute/Store 操作 |
| asyncMatMul | Asynchronous Matrix Multiplication | 异步矩阵乘法接口，发起计算后立即返回 |
| checkMatmul | Check Matrix Multiplication | 同步等待矩阵乘法完成的接口 |
| funct | Function Code | RoCC 指令的功能码字段 |
| Source ID | — | TileLink 事务标识符，用于匹配请求和响应 |
| CAM | Content Addressable Memory | 内容可寻址存储器，用于 Source ID 映射和 TLB |

### 指令 funct 编码

| funct | 名称 | 说明 |
|-------|------|------|
| 0 | `SEND_MACRO_INST` | 将配置好的指令推入 MacroInst FIFO |
| 1-4 | `CONFIG_TENSOR_A/B/C/D` | 配置张量基地址和步长 |
| 5 | `CONFIG_MNK` | 配置矩阵维度 M/N/K |
| 6 | `CONFIG_CONV` | 配置数据类型、bias 类型、转置、卷积参数 |
| 7-8 | `CONFIG_SCALE_A/B` | 配置缩放因子地址 |
| 1-8 (查询) | Status Query | 查询运行状态、周期数、访存计数等 |

## 6. Tile 与分块

| 术语 | 英文 | 说明 |
|------|------|------|
| Tile | — | 将大矩阵划分为 SCP 可容纳的子矩阵，逐步计算 |
| Tensor_M | — | 输出矩阵行方向的 tile 大小 |
| Tensor_N | — | 输出矩阵列方向的 tile 大小 |
| Tensor_K | — | 归约维度的 tile 大小 |
| im2col | Image to Column | 将卷积的输入特征图展开为矩阵乘法格式 |
| Tiling Loop | — | 遍历所有 tile 的外层循环，由 TaskController 管理 |

## 7. 性能与配置

| 术语 | 英文 | 说明 |
|------|------|------|
| TOPS | Tera Operations Per Second | 每秒万亿次运算 |
| FReduce | Float Reduce | 浮点归约，将多个乘积累加为一个浮点结果 |
| Outer Product | — | 外积数据流，A 按行广播、B 按列广播 |
| Output-Stationary | — | 输出驻留，累加结果驻留在 C Scratchpad 中直到 K 维度完成 |
| CLZ | Count Leading Zeros | 前导零计数，用于浮点归一化 |
| ComputeBound | — | 计算受限，计算阶段占比 > 40% |
| MemoryBound | — | 内存受限，Load/Store 阶段占比 > 60% |

## 8. 集成平台

| 术语 | 英文 | 说明 |
|------|------|------|
| Rocket | — | 顺序执行 RISC-V 核，CUTE 的基准集成平台 |
| BOOM | Berkeley Out-of-Order Machine | 乱序执行 RISC-V 核 |
| Shuttle | — | 3 发射 RISC-V 核，支持 Saturn VPU 向量扩展 |
| XiangShan-Kunminghu | — | 香山处理器乱序核，通过 CSR 接口集成（论文规划） |
| Saturn | — | Shuttle 核的向量处理单元 |
| Chipyard | — | RISC-V SoC敏捷开发框架 |
| Verilator | — | 开源 Verilog 仿真器 |
| DRAMSim2 | — | DRAM 周期精确仿真器 |
