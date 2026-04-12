# 内存加载器

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| AML | A Memory Loader，加载 A 矩阵 tile |
| BML | B Memory Loader，加载 B 矩阵 tile |
| CML | C Memory Loader，加载 C 矩阵（累加初值）并存储 D 结果 |
| ASL | A Scale Loader，加载 A 矩阵的缩放因子 |
| BSL | B Scale Loader，加载 B 矩阵的缩放因子 |
| SCP Fill Table | 用于将宽内存响应拆分写入窄 SCP Bank 的缓冲结构 |
| Bank Fill FIFO | 每个 SCP Bank 独立的回填队列，管理 Fill Table 条目到特定 Bank 的写入顺序 |
| Source ID CAM | 以 LLC SourceID 为索引的寄存器阵列，记录每个 in-flight 请求对应的 SCP 写入位置 |
| MAX_Fill_Times | `outsideDataWidthByte / SCPEntryByteSize`，一次内存响应需要拆成多少次 SCP 写入 |

## 2. 状态机

所有 Loader 共享相同的状态机结构：

```
任务级：idle → mm_task → idle
                │
访存级：         └→ s_load_init → s_load_working → s_load_end
```

- **任务级状态机**：等待 TaskController 配置（`MicroTaskReady/MicroTaskValid` 握手），接收基地址、步长、维度等参数
- **访存级状态机**（AML/BML/CML Load）：负责地址生成、请求发射、响应接收、SCP 写回
- CML 额外有 **Store 状态机**（`s_store_init → s_store_working → s_store_end`）：从 SCP 读出 D 结果写回主存

## 3. A Memory Loader（AML）

### 3.1 SCP 数据排布

AML 将内存中的 A 矩阵 tile 按如下规则写入 A Scratchpad：

**地址计算公式**（`AMemoryLoader.scala` 第 321-322 行）：
```
ScratchpadBankId = CurrentM % AScratchpadNBanks        (即 M % Matrix_M)
ScratchpadAddr   = (CurrentM / AScratchpadNBanks) × ReduceGroupSize + CurrentK
```

**迭代顺序**：M 维度递增最快，K 维度递增最慢。每个请求取 `ReduceWidthByte` 字节（默认 64B = 512bit）的连续数据。当 `outsideDataWidthByte > ReduceWidthByte` 时，一次内存响应包含 `MAX_Fill_Times` 个 SCP entry，K 维度每次步进 `MAX_Fill_Times`。

**以默认参数为例**（`Tensor_M=128, Matrix_M=4, Tensor_K=64, ReduceWidthByte=64`）：

`ReduceGroupSize = Tensor_K / ReduceWidthByte = 64 / 64 = 1`

SCP 有 4 个 Bank，每个 Bank 的深度为 `Tensor_M/Matrix_M × ReduceGroupSize = 32 × 1 = 32` 个 entry。

```
                    Bank[0]   Bank[1]   Bank[2]   Bank[3]
                ┌─────────┬─────────┬─────────┬─────────┐
SCP addr 0     │ M=0,K=0 │ M=1,K=0 │ M=2,K=0 │ M=3,K=0 │ ← ADC addr = 0*1+0
SCP addr 1     │ M=4,K=0 │ M=5,K=0 │ M=6,K=0 │ M=7,K=0 │ ← ADC addr = 1*1+0
  ...          │   ...   │   ...   │   ...   │   ...   │
SCP addr 31    │ M=124,K=0│ M=125,K=0│ M=126,K=0│ M=127,K=0│
```

**为什么 Bank 数 = Matrix_M？**

ADC 读取 SCP 时，**所有 Bank 使用相同地址同时读出**，拼接后恰好得到 `Matrix_M` 个 entry、每个 `ReduceWidthByte` 字节的数据，即 `ReduceWidth × Matrix_M` bit——这正好是 MTE 的 VectorA 位宽。因此 Bank 数必须等于 Matrix_M，才能在一个周期内供给 MTE 所需的完整 A 向量。

### 3.2 内存地址生成

**矩阵乘模式**（`isconv=0`，第 799-802 行）：
```
VA = BlockBaseAddr + CurrentM × Stride_M + CurrentK × ReduceWidthByte
```
- `Stride_M` 由 TaskController 提供，是原始矩阵中相邻 M 行的字节偏移
- K 维度连续排列在内存中

**卷积模式**（`isconv=1`，第 283 行）：
```
VA = Current_M_BaseAddr + CurrentK × ReduceWidthByte
Current_M_BaseAddr = Tensor_BaseVaddr + IH × IH_Stride + IW × IW_Stride
```
- `IH`、`IW` 由输出位置 (OH, OW) 和卷积核位置 (KH, KW) 计算得到
- `IH_Stride = Stride_W × OW × Stride_M`，`IW_Stride = Stride_M`
- M 维度的每次递进对应 (OH, OW) 空间中的一步移动

### 3.3 零填充机制（仅卷积模式）

当 im2col 窗口越出输入边界时（`IH < 0 || IH >= IH_MAX || IW < 0 || IW >= IW_MAX`），AML 不发出内存请求，而是通过 SCP 的 ZeroFill 端口写入零值。

**NACK 冲突处理**：当零填充目标 Bank 与正在回填的响应 Bank 相同时，零填充被延迟（NACK），存入 `NACK_ZeroFill_Hloding_Reg`（每 Bank 一个），等待 Bank 空闲后补写。每个 Bank 最多允许 1 个 NACK，确保不会阻塞请求译码。

### 3.4 M 方向上取整

卷积模式下，`ScaratchpadTensor_M` 可能不是 `Matrix_M` 的整数倍。AML 将 `MaxBlockTensor_M_Index` 向上取整到 `Matrix_M` 的倍数（第 233 行）：
```
MaxBlockTensor_M_Index = (Tensor_M / Matrix_M) × Matrix_M + (Tensor_M % Matrix_M ≠ 0) × Matrix_M
```
多出的 M 行通过 `Is_invalid_IH_IW`（`CurrentLoaded_BlockTensor_M >= ScaratchpadTensor_M`）触发零填充。

## 4. B Memory Loader（BML）

### 4.1 SCP 数据排布

BML 将内存中的 B 矩阵 tile 按如下规则写入 B Scratchpad：

**地址计算公式**（`BMemoryLoader.scala` 第 208-209 行）：
```
ScratchpadBankId = CurrentN % BScratchpadNBanks        (即 N % Matrix_N)
ScratchpadAddr   = (CurrentN / BScratchpadNBanks) × ReduceGroupSize + CurrentK
```

**迭代顺序**：K 维度递增最快，N 维度递增最慢。内存中 B 矩阵的排布为 `[N][K]`，每次请求取 `ReduceWidthByte` 字节。

**内存地址生成**（第 174 行）：
```
VA = BlockBaseAddr + CurrentN × ApplicationTensor_B_Stride_N + CurrentK × ReduceWidthByte
```
- `ApplicationTensor_B_Stride_N` 是 B 矩阵中相邻 N 列之间的字节偏移

**以默认参数为例**（`Tensor_N=128, Matrix_N=4`）：
```
                    Bank[0]   Bank[1]   Bank[2]   Bank[3]
                ┌─────────┬─────────┬─────────┬─────────┐
SCP addr 0     │ N=0,K=0 │ N=1,K=0 │ N=2,K=0 │ N=3,K=0 │
SCP addr 1     │ N=4,K=0 │ N=5,K=0 │ N=6,K=0 │ N=7,K=0 │
  ...          │   ...   │   ...   │   ...   │   ...   │
```

BDC 读取时所有 Bank 同地址读出，拼接得到 `ReduceWidth × Matrix_N` bit，正好是 MTE 的 VectorB 位宽。

## 5. C Memory Loader（CML）

### 5.1 C SCP 数据排布

C SCP 的排布与 A/B SCP 有本质区别：

- **Bank 数** = `Matrix_N`（方便 reorder）
- **Entry 宽度** = `Matrix_M × ResultWidthByte`（默认 4×4=16 字节），即一个 entry 存储一整行 M 维度的结果
- 每个 Bank 存储若干 N 列的全部 M 行结果

```
                    Bank[0]       Bank[1]
                ┌─────────────┬─────────────┐
SCP addr 0     │ M0..3,N=0..3 │ M0..3,N=4..7 │   ← 一个 entry = 4个M行 × 4字节
SCP addr 1     │ M4..7,N=0..3 │ M4..7,N=4..7 │
  ...          │     ...     │     ...     │
```

### 5.2 Load 模式

CML 从主存加载 C 矩阵（累加初值）到 C SCP：

| 子模式 | 说明 |
|--------|------|
| **NormalLoad** | 正常加载：从主存读取 C 矩阵写入 SCP |
| **ZeroLoad** | 填零模式：不访问主存，直接将 SCP 对应区域填零 |
| **RepeatRowLoad** | 行广播：加载单行数据，重复写入 SCP 所有 M 行（用于 bias 加法） |
| **FullLoad** | 完整张量加载（不受 tile 维度限制） |

### 5.3 Store 模式

CML 从 C SCP 读出 D 结果写回主存。支持转置输出（`Is_Transpose`），写回时对 M/N 维度进行转置。

## 6. SCP Fill Table 机制

当外部总线宽度（`outsideDataWidthByte`）大于 SCP Bank entry 宽度（`SCPEntryByteSize`）时，一次内存响应携带多个 SCP entry 的数据，需要跨多个周期拆分写入 SCP。

### 6.1 触发条件

```scala
ABMLNeedSCPFillTable = ReduceWidthByte < outsideDataWidthByte
MAX_Fill_Times = outsideDataWidthByte / SCPEntryByteSize
```

例如 `outsideDataWidth=512bit(64B)`, `ReduceWidthByte=32B` 时，`MAX_Fill_Times=2`，每次响应需要 2 个周期写入 SCP。

### 6.2 数据结构

**SCP Fill Table**（全局缓冲，深度 = `AMemoryLoaderReadFromMemoryFIFODepth`，默认 4）：

| 字段 | 宽度 | 说明 |
|------|------|------|
| `SCP_Fill_Table` | `outsideDataWidth` bit | 存储完整的内存响应数据 |
| `SCP_Fill_Table_SCP_Addr` | `log2(BankNEntrys)` bit | 该响应写入 SCP 的起始地址 |
| `SCP_Fill_Table_Time` | `log2(MAX_Fill_Times)+1` bit | 剩余回填次数，递减到 0 释放条目 |

**Bank Fill FIFO**（每 Bank 一个，深度 = `AMemoryLoaderReadFromMemoryFIFODepth`）：

| 字段 | 说明 |
|------|------|
| `Head` | 该 Bank 下一次插入的 FIFO 位置 |
| `Tail` | 该 Bank 当前正在回填的 FIFO 位置 |
| `Full` | `Tail == WrapInc(Head, depth)` |
| `Empty` | `Head == Tail` |
| `Valid(i)` | 该 Bank 有待回填数据 |

### 6.3 回填流程

1. **响应接收**：内存响应到达时，将完整数据存入 `SCP_Fill_Table[InsertIndex]`，记录 `SCP_Addr` 和 `Time = MAX_Fill_Times`。将该条目的 Index 追加到对应 Bank 的 `Bank_Fill_Search_FIFO`。

2. **逐 Bank 回填**（最高优先级）：每个 Bank 检查自己的 FIFO 是否为空，非空时：
   - 从 FIFO Tail 取出 Fill Table Index
   - 将 `SCP_Fill_Table[Index]` 中的数据按 `SCPEntryByteSize` 宽度切片
   - 写入地址 = `SCP_Addr + (MAX_Fill_Times - Time)`（从高地址向低地址填充）
   - `Time` 递减，到 1 时弹出 FIFO Tail

3. **背压控制**：
   - `Response.ready = SCP_Fill_Table_Not_Full && !Bank_Fill_FIFO_Full[target_bank]`
   - 保证 Fill Table 有空位且目标 Bank 的 FIFO 不溢出

### 6.4 不需要 Fill Table 的情况

当 `outsideDataWidthByte == ReduceWidthByte` 时（例如均为 64B），一次内存响应恰好等于一个 SCP entry，响应到达后直接写入 SCP，无需 Fill Table 中转。

## 7. Source ID CAM

每个 Loader 维护一个以 LLC SourceID 为索引的寄存器阵列（大小 = `SoureceMaxNum = max(LLCSourceMaxNum, MemorysourceMaxNum)`，默认 64），记录每个 in-flight 请求对应的 SCP 写入目标：

```scala
class ASourceIdSearch {
    val ScratchpadBankId: UInt  // 写入哪个 Bank
    val ScratchpadAddr: UInt    // 写入 Bank 内的哪个地址
}
```

**工作流程**：

1. **请求发射时**：`SoureceIdSearchTable[sourceId] := {BankId, Addr}`
2. **响应到达时**：通过 `ResponseSourceID` 查表得到 `{BankId, Addr}`，据此将响应数据写入 SCP

由于 LocalMMU 的 round-robin 仲裁，同一 Loader 的请求可能穿插在来自其他 Loader 的响应之间返回。Source ID CAM 使得每个响应都能准确路由到正确的 SCP 位置。

## 8. A/B Scale Loader

ASL 和 BSL 的结构与 AML/BML 高度一致，区别在于：

- 数据源是对应的 Scale Scratchpad
- 加载的是块缩放因子（MXFP8/MXFP4/NVFP4 的 E 值）
- 地址计算中考虑 `ScaleVecWidth(dataType)` 对齐

Scale Loader 的 Source ID CAM、SCP Fill Table、Bank Fill FIFO 与数据 Loader 结构完全相同。

## 9. AML 的 im2col 变换

卷积计算需要将输入特征图通过 im2col 变换展开为矩阵。AML 在硬件中直接执行 im2col：

**输入坐标计算**：
```
IH = OH × stride_H + KH - (kernel_size / 2)
IW = OW × stride_W + KW - (kernel_size / 2)
```

**越界检测与零填充**：
```
Is_invalid = IH < 0 || IH >= IH_MAX || IW < 0 || IW >= IW_MAX || M >= Tensor_M
```

**OW/OH 扫描**：M 维度的递进映射到 (OW, OH) 空间的扫描，当 OW 达到上限时 OH+1，OW 归零。每次切换 K 维度时，OW/OH 回到初始位置。

## 10. 与其他模块的交互

```
主存 ←→ LLC ←→ LocalMMU ←→ TileLink
                      │
        ┌─────┬───────┼───────┬─────┐
        │     │       │       │     │
       AML   BML     CML     ASL   BSL
        │     │       │       │     │
   A SCP  B SCP   C SCP  A SSCP  B SSCP
```

数据 Loader 通过 `LocalMMUIO` 接口与 LocalMMU 交互，每个 Loader 占用 LocalMMU 的一个请求端口。LocalMMU 内部的 `sourceid2port` 表确保响应被路由回正确的 Loader。

## 11. 参考

- 源码：`src/main/scala/AMemoryLoader.scala`、`src/main/scala/BMemoryLoader.scala`、`src/main/scala/CMemoryLoader.scala`
- Scale 源码：`src/main/scala/AScaleLoader.scala`、`src/main/scala/BScaleLoader.scala`
- 参数定义：`src/main/scala/CUTEParameters.scala` 第 878-1007 行
