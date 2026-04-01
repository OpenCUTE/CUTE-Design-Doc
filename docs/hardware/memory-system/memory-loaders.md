# 内存加载器

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| AML | A Memory Loader，加载 A 矩阵 tile |
| BML | B Memory Loader，加载 B 矩阵 tile |
| CML | C Memory Loader，加载 C 矩阵（累加初值）并存储 D 结果 |
| ASL | A Scale Loader，加载 A 缩放因子 |
| BSL | B Scale Loader，加载 B 缩放因子 |
| SCP Fill Table | 用于将宽内存响应拆分写入窄 SCP Bank |

## 2. 设计规格

### 2.1 A Memory Loader

| 参数 | 说明 |
|------|------|
| 数据源 | 主存（通过 LocalMMU → TileLink） |
| 数据目标 | A Scratchpad |
| 地址生成 | 线性地址：`BaseAddr + K_Iter × ReduceWidthByte × ReduceGroupSize + M_progression` |
| im2col 支持 | 是（卷积场景下计算 IH/IW 索引） |
| 零填充 | 是（卷积越界时写入零值） |

### 2.2 B Memory Loader

| 参数 | 说明 |
|------|------|
| 数据源 | 主存 |
| 数据目标 | B Scratchpad |
| 特殊处理 | B 地址偏移包含 kernel 位置：`base + K_Iter × dataBitWidth/8 + N_Iter × stride + (KH × kernel_size + KW) × kernel_stride` |

### 2.3 C Memory Loader（双功能）

| 模式 | 功能 |
|------|------|
| **Load 模式** | 从主存加载 C 矩阵到 C Scratchpad |
| **ZeroLoad** | 将 C Scratchpad 填零（不访问主存） |
| **RepeatRowLoad** | 重复加载单行（广播 bias） |
| **FullLoad** | 完整张量加载 |
| **Store 模式** | 从 C Scratchpad 读取 D 结果写回主存 |

### 2.4 Scale Loader (ASL/BSL)

| 参数 | 说明 |
|------|------|
| 数据源 | 主存 |
| 数据目标 | Scale Scratchpad |
| 请求迭代数 | `SCP_Tensor_K × SCP_Tensor_M(or N) × ScaleVecWidth(dataType) / outsideDataWidthByte` |

## 3. 功能描述

Memory Loader 是 CUTE 与主存之间的桥梁，负责将矩阵 tile 数据从 DRAM 搬运到 Scratchpad。

**核心工作流程：**

1. 接收 TaskController 的微任务配置（基地址、步长、维度等）
2. **Request Generator** 将张量描述转换为内存地址序列
3. 通过 LocalMMU 发出 TileLink 读/写请求
4. 接收响应数据
5. **Data Reorder** 将响应数据写入对应的 Scratchpad 位置

**Source ID CAM（寄存器阵列）：**
每个 Loader 维护一个 CAM（Content Addressable Memory）结构，将 in-flight 请求的 source ID 映射到 SCP 地址。当响应返回时，通过 source ID 查找对应的 SCP 写入位置。

**SCP Fill Table：**
当外部总线宽度（512 bit）大于 SCP Bank 宽度（256 bit）时，一次内存响应包含多个 SCP 条目。Fill Table 负责将宽响应拆分，在多个周期内顺序写入对应 Bank。

## 4. AML 的 im2col 变换

卷积计算需要将输入特征图通过 im2col 变换展开为矩阵。AML 在硬件中直接执行 im2col：

- 从输出位置 (OH, OW) 和卷积核位置 (KH, KW) 计算输入位置 (IH, IW)
- 检测越界条件：`IH < 0 || IH >= H || IW < 0 || IW >= W`
- 越界时触发零填充，不发出内存请求

## 5. 与其他模块的交互

```
主存 ←→ LocalMMU ←→ TileLink
                      │
        ┌─────────────┼─────────────┐
        │             │             │
   AML/ASL       BML/BSL         CML
        │             │             │
   A SCP[i]      B SCP[i]     C SCP[i]
   A Scale[i]    B Scale[i]
```

## 6. 参考

- 源码：`src/main/scala/AMemoryLoader.scala`、`src/main/scala/BMemoryLoader.scala`、`src/main/scala/CMemoryLoader.scala`
- Scale 源码：`src/main/scala/AScaleLoader.scala`、`src/main/scala/BScaleLoader.scala`
