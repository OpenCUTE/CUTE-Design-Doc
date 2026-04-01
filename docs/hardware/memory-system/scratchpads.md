# A/B/C Scratchpad

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| Scratchpad (SCP) | 片上暂存存储器，用于缓存矩阵 tile 数据 |
| Bank | 存储分体，支持并行读写 |
| 双缓冲 | 所有 SCP 实例化 ×2，Load 和 Compute 阶段交替使用不同 SCP 组 |

## 2. 设计规格

### 2.1 A Scratchpad

| 参数 | 说明 |
|------|------|
| 实例数 | 2（双缓冲：SCP[0] 和 SCP[1]） |
| Bank 数 | `Matrix_M`（默认 4） |
| 每个 Bank 位宽 | `ReduceWidth × 8` bit |
| 每个 Bank 深度 | `Tensor_M × ReduceGroupSize / Matrix_M` |
| 总容量 | `Tensor_M × ReduceGroupSize × ReduceWidthByte` 字节 |
| 零填充 | 支持（卷积 im2col 的越界部分） |

### 2.2 B Scratchpad

| 参数 | 说明 |
|------|------|
| 实例数 | 2（双缓冲） |
| Bank 数 | `Matrix_N`（默认 4） |
| 每个 Bank 位宽 | `ReduceWidth × 8` bit |
| 总容量 | 类似 A SCP |
| 零填充 | 不支持 |

### 2.3 C Scratchpad

| 参数 | 说明 |
|------|------|
| 实例数 | 2（双缓冲） |
| Bank 数 | `Matrix_N`（默认 4） |
| 每个 Bank 位宽 | `Matrix_M × ResultWidth × 8` bit |
| 总容量 | 存储 M×N tile 的累加结果 |
| 端口 | 独立读写端口（CDC 读写 + CML 读写） |

## 3. 功能描述

Scratchpad 是 CUTE 存储系统的核心，暂存当前正在计算的矩阵 tile。设计要点：

**双缓冲机制**：每个 SCP 类型（A/B/C）各有两套实例。TaskController 通过 `SCPControlInfo` 信号选择当前活跃的一组。当 Compute 阶段使用 SCP[0] 的数据进行计算时，Load 阶段可以同时向 SCP[1] 写入下一个 tile 的数据，实现 Load-Compute 流水重叠。

**多 Bank 并行**：
- A SCP 按 `Matrix_M` 分 Bank，每个 Bank 对应一个 PE 行
- B/C SCP 按 `Matrix_N` 分 Bank，每个 Bank 对应一个 PE 列
- 多 Bank 支持同一周期内并行读取不同 PE 所需的数据

**写优先仲裁**：所有 SCP 使用单端口 `SyncReadMem`，写操作（来自 MemoryLoader）优先于读操作（来自 DataController）。这确保数据加载不被阻塞。

**零填充（仅 A SCP）**：卷积计算中，当 im2col 窗口越出输入边界时，A SCP 的 `ZeroFill` 端口写入零值，替代从主存加载数据。

## 4. 微架构设计

```
                    MemoryLoader (写端)         DataController (读端)
                         │                           │
                         ▼                           ▼
                ┌─────────────────┐
                │  仲裁器(写优先)   │
                └────┬────────┬───┘
                     │        │
              ┌──────┴──┐  ┌──┴──────┐
              │ Bank 0  │  │ Bank 1  │ ...
              │SyncReadMem│ │SyncReadMem│
              └─────────┘  └─────────┘
```

**SCP Fill Table**：当外部总线宽度（`outsideDataWidth`，如 512 bit）大于 SCP Bank 宽度（`ReduceWidthByte×8`，如 256 bit）时，一次内存响应需要跨多个周期写入 SCP。`SCP_Fill_Table` 负责将宽响应拆分并顺序填充到对应 Bank 条目中。

## 5. 与其他模块的交互

| SCP 类型 | 写入方 | 读取方 |
|---------|--------|--------|
| A SCP[i] | AMemoryLoader | ADataController |
| B SCP[i] | BMemoryLoader | BDataController |
| C SCP[i] | CMemoryLoader (加载) / CDataController (写回) | CDataController (读取) / CMemoryLoader (存储) |

## 6. 参考

- 源码：`src/main/scala/AScratchpad.scala`、`src/main/scala/BScratchpad.scala`、`src/main/scala/CScratchpad.scala`
