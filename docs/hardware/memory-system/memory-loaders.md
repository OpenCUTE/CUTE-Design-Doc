# 内存加载器

> **典型配置**：`Tensor_M = Tensor_N = 64`，`Matrix_M = Matrix_N = 4`，`ReduceWidthByte = 64`（ReduceWidth = 512 bit），`Tensor_K = 64`（ReduceGroupSize = 1），`ResultWidthByte = 4`。A/B SCP 各 4 KB，C SCP 16 KB，双缓冲总计 48 KB。

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| AML | A Memory Loader，加载 A 矩阵 tile |
| BML | B Memory Loader，加载 B 矩阵 tile |
| CML | C Memory Loader，加载 C 矩阵（累加初值）并存储 D 结果 |
| ASL | A Scale Loader，加载 A 矩阵的缩放因子 |
| BSL | B Scale Loader，加载 B 矩阵的缩放因子 |
| Source ID CAM | 以 LLC SourceID 为索引的寄存器阵列，记录每个 in-flight 请求对应的 SCP 写入位置 |

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

AML 将 A 矩阵 tile 写入 A Scratchpad，地址计算公式：

```
ScratchpadBankId = CurrentM % Matrix_M
ScratchpadAddr   = (CurrentM / Matrix_M) × ReduceGroupSize + CurrentK
```

详细的 Bank 结构和 K 维度数据排布见 [A/B/C Scratchpad](scratchpads.md)。

**迭代顺序**：M 维度递增最快，K 维度递增最慢。每个请求取 `ReduceWidthByte` 字节（64B）的连续数据。

### 3.2 内存地址生成

**矩阵乘模式**（`isconv=0`）：
```
VA = BlockBaseAddr + CurrentM × Stride_M + CurrentK × ReduceWidthByte
```
- `Stride_M` 由 TaskController 提供，是原始矩阵中相邻 M 行的字节偏移
- K 维度连续排列在内存中

**卷积模式**（`isconv=1`）：
```
VA = Current_M_BaseAddr + CurrentK × ReduceWidthByte
Current_M_BaseAddr = Tensor_BaseVaddr + IH × IH_Stride + IW × IW_Stride
```
- `IH`、`IW` 由输出位置 (OH, OW) 和卷积核位置 (KH, KW) 计算得到
- `IH_Stride = Stride_W × OW × Stride_M`，`IW_Stride = Stride_M`
- M 维度的每次递进对应 (OH, OW) 空间中的一步移动

### 3.3 im2col 变换

卷积计算需要将输入特征图通过 im2col 变换展开为矩阵。AML 在硬件中直接执行 im2col：

**输入坐标计算**：
```
IH = OH × stride_H + KH - (kernel_size / 2)
IW = OW × stride_W + KW - (kernel_size / 2)
```

**越界检测与零填充**：当 `IH < 0 || IH >= IH_MAX || IW < 0 || IW >= IW_MAX` 时，AML 不发出内存请求，通过 SCP 的 ZeroFill 端口写入零值。当零填充目标 Bank 与正在回填的响应 Bank 冲突时，零填充被延迟（NACK），存入暂存寄存器等待 Bank 空闲后补写。

**OW/OH 扫描**：M 维度的递进映射到 (OW, OH) 空间的扫描，当 OW 达到上限时 OH+1，OW 归零。每次切换 K 维度时，OW/OH 回到初始位置。

**M 方向上取整**：卷积模式下 `Tensor_M` 可能不是 `Matrix_M` 的整数倍，AML 将 M 维度向上取整到 `Matrix_M` 的倍数，多出的 M 行通过零填充处理。

## 4. B Memory Loader（BML）

### 4.1 SCP 数据排布

BML 将 B 矩阵 tile 写入 B Scratchpad，地址计算公式：

```
ScratchpadBankId = CurrentN % Matrix_N
ScratchpadAddr   = (CurrentN / Matrix_N) × ReduceGroupSize + CurrentK
```

详细的 Bank 结构和 K 维度数据排布见 [A/B/C Scratchpad](scratchpads.md)。

**迭代顺序**：K 维度递增最快，N 维度递增最慢。内存中 B 矩阵的排布为 `[N][K]`，每次请求取 `ReduceWidthByte` 字节。

### 4.2 内存地址生成

```
VA = BlockBaseAddr + CurrentN × ApplicationTensor_B_Stride_N + CurrentK × ReduceWidthByte
```
- `ApplicationTensor_B_Stride_N` 是 B 矩阵中相邻 N 列之间的字节偏移

## 5. C Memory Loader（CML）

### 5.1 SCP 数据排布

C SCP 的 Bank 结构与 A/B SCP 有本质区别，详见 [A/B/C Scratchpad - C SCP](scratchpads.md)。

核心特征：
- Bank 数 = `Matrix_N`，Bank[i] 存储 N%Matrix_N=i 的所有列结果
- Entry 宽度 = `Matrix_M × ResultWidthByte`（16B），每个 entry 存一个 M-group 的 `Matrix_M = 4` 个 FP32 结果
- C SCP 具有独立读写端口，CDC 和 CML 可同时操作不同 Bank

### 5.2 Load 模式

CML 从主存加载 C 矩阵（累加初值）到 C SCP：

| 子模式 | 说明 |
|--------|------|
| **NormalLoad** | 正常加载：从主存读取 C 矩阵按 (M_group, N) 遍历写入 SCP |
| **ZeroLoad** | 填零模式：不访问主存，直接将 SCP 对应区域填零（C=0 的常见场景） |
| **RepeatRowLoad** | 行广播：加载单行数据，重复写入 SCP 所有 M 行（用于 bias 加法） |
| **FullLoad** | 完整张量加载（不受 tile 维度限制） |

### 5.3 Store 模式

MTE 完成计算后，CDC 将 D 结果写回 C SCP（覆盖原 C 数据），CML 随后从 C SCP 逐 entry 读出并写回主存。

**Store 地址生成**：CML 按 M-group 递增、N 递增的顺序遍历 C SCP，每个 entry 包含一个 M-group 的 `Matrix_M` 个 FP32 结果，CML 将其拆分并按内存排布写回。

### 5.4 Reorder

C SCP 的 Bank 按 N%Matrix_N 组织（Bank[i] 存储 N%4=i 的列），使得不同 N 列的数据分散在 4 个 Bank 中。CML 读出时可通过调整 Bank 遍历顺序实现对输出矩阵的列重排，无需额外缓冲区。

### 5.5 转置输出

当 `Is_Transpose` 有效时，CML 写回主存时将 M/N 维度互换：原始 (M, N) 位置的结果写入内存的 (N, M) 位置。CML 在 Store 状态机中交换 M/N 的步长和迭代范围即可实现转置，无需数据搬运。

### 5.6 与 CDC 的协作

```
主存 ──Load──→ CML ──写入──→ C SCP[i] ──读取──→ CDC ──MatrixC──→ MTE
                                    ↑
              MTE ──MatrixD──→ CDC ──写回──→ C SCP[i] ──读取──→ CML ──Store──→ 主存
```

CDC 负责 C SCP 与 MTE 之间的数据搬运（读 C、写 D），CML 负责 C SCP 与主存之间的数据搬运（加载 C、存储 D）。两者通过 C SCP 的独立读写端口并行工作，互不阻塞。

## 6. Source ID CAM

每个 Loader 维护一个 Source ID CAM，以 LLC SourceID 为索引，记录每个 in-flight 请求对应的 SCP 写入目标：

```scala
class ASourceIdSearch {
    val ScratchpadBankId: UInt  // 写入哪个 Bank
    val ScratchpadAddr: UInt    // 写入 Bank 内的哪个地址
}
```

**工作流程**：

1. **请求发射时**：`SourceIdSearchTable[sourceId] := {BankId, Addr}`
2. **响应到达时**：通过 `ResponseSourceID` 查表得到 `{BankId, Addr}`，据此将响应数据写入 SCP

由于 LocalMMU 的 round-robin 仲裁，同一 Loader 的请求可能穿插在来自其他 Loader 的响应之间返回。Source ID CAM 使得每个响应都能准确路由到正确的 SCP 位置。

## 7. A/B Scale Loader

ASL 和 BSL 的结构与 AML/BML 高度一致，区别在于：

- 数据源是对应的 Scale Scratchpad
- 加载的是块缩放因子（MXFP8/MXFP4/NVFP4 的 E 值）
- 地址计算中考虑 `ScaleVecWidth(dataType)` 对齐

Scale Loader 的 Source ID CAM 与数据 Loader 结构完全相同。

## 8. 与其他模块的交互

```
memory ←→ LLC ←→ LocalMMU ←→ TileLink
                      │
        ┌─────┬───────┼───────┬─────┐
        │     │       │       │     │
       AML   BML     CML     ASL   BSL
        │     │       │       │     │
   A SCP  B SCP   C SCP  A SSCP  B SSCP
```

数据 Loader 通过 `LocalMMUIO` 接口与 LocalMMU 交互，每个 Loader 占用 LocalMMU 的一个请求端口。LocalMMU 内部的 `sourceid2port` 表确保响应被路由回正确的 Loader。

## 9. 参考

- 源码：`src/main/scala/AMemoryLoader.scala`、`src/main/scala/BMemoryLoader.scala`、`src/main/scala/CMemoryLoader.scala`
- Scale 源码：`src/main/scala/AScaleLoader.scala`、`src/main/scala/BScaleLoader.scala`
- 参数定义：`src/main/scala/CUTEParameters.scala`
- SCP 数据排布：[A/B/C Scratchpad](scratchpads.md)
