# 历史性能记录与当前验收

本页保留旧设计文档中的参数和论文评估数字，便于回溯。旧页没有绑定论文版本、
页码、原始测量报告及源码/产物哈希，下面的面积、频率和加速比均未在本轮复核，
不能作为当前工作树的性能结论。正式引用时需补齐相应来源，要求见
[来源与证据](../appendix/references.md)。

当前可复核结果是 S1 和 28 项 BERT/LLaMA 阶段正确性验收，见
[验收表](/status/#model-acceptance) 及 [证据位置](/status/#evidence)。这些结果不包含
训练权重精度、完整模型性能或旧 TCM/double-buffer 调度的性能迁移。

## 1. 旧页记录的硬件配置

### 1.1 CUTE 硬件参数

| 参数 | 值 |
|------|-----|
| PE 阵列维度 | 4×4 |
| ReduceWidthByte | 32 |
| Tensor_M/N/K | 64 |
| outsideDataWidth | 512 bit |
| TileLink 位宽 | 512 bit |
| 频率目标 | 2 GHz |
| 工艺节点 | 14 nm |
| 面积 | 0.531 mm² |
| 峰值算力 | 4 TOPS (INT8) |

### 1.2 性能预设

| 配置 | Matrix_M×N | ReduceWidthByte | Tensor_M/N/K | 峰值算力 |
|------|-----------|-----------------|-------------|---------|
| CUTE_05Tops | 2×2 | 32 | 64 | 0.5 TOPS |
| CUTE_1Tops | 2×2 | 64 | 64 | 1 TOPS |
| CUTE_2Tops | 4×4 | 32 | 64 | 2 TOPS |
| CUTE_4Tops | 4×4 | 64 | 64 | 4 TOPS |
| CUTE_8Tops | 8×8 | 32 | 64 | 8 TOPS |
| CUTE_16Tops | 8×8 | 64 | 64 | 16 TOPS |
| CUTE_32Tops | 16×16 | 32 | 64 | 32 TOPS |

## 2. 旧页标注的论文评估（DAC 2026，来源未复核）

### 2.1 vs CPU Baseline 加速比

旧页将以下值标为 CUTE 4 TOPS 配置（4×4 PE、14nm、2GHz）相对
Intel Xeon 8580（AMX、28 核、2.0GHz）的加速比；保留其原始表述供来源核对：

| 工作负载 | 加速比 | 说明 |
|---------|--------|------|
| ResNet-50 推理 | 1.57× | INT8 量化推理 |
| BERT-Large 推理 | 1.57× | FP16 推理 |
| LLaMA3-8B 推理 | 2.31× | FP16 推理 |

### 2.2 面积效率

| 指标 | 值 | 说明 |
|------|-----|------|
| 面积 | 0.531 mm² | 14nm 工艺 |
| 功耗 | — | 论文报告 |
| TOPS/mm² | — | 面积效率 |

### 2.3 可扩展性

旧页列出了 0.5–32 TOPS 的预设名称。预设名称和参数表不能证明面积或实际吞吐量
线性扩展；这需要各配置的综合、时序和工作负载测量报告。

## 3. 测试矩阵

### 3.1 GEMM 测试

**目录：** `cutetest/gemm_test/`

| 测试名称 | M | N | K | 说明 |
|---------|---|---|---|------|
| 小矩阵 | 256 | 256 | 64 | 64×64 输出 tile 配置下仍需多 tile |
| 中等矩阵 | 512 | 512 | 256 | 多 tile 计算 |
| 大 K 矩阵 | 512 | 512 | 1024 | K 维度远大于 tile |
| LLaMA 层模拟 | 512 | 512 | 10496 | 模拟 LLaMA 注意力层 |
| LLaMA 层模拟 | 512 | 512 | 10752 | 模拟 LLaMA FFN 层 |
| LLaMA 层模拟 | 512 | 512 | 11008 | 模拟 LLaMA FFN 层 |

### 3.2 ResNet50 测试

**目录：** `cutetest/resnet50_test/`

保留历史卷积实验；本轮未对其层覆盖率或输出作系统验收，ResNet/X2 迁移已搁置。

### 3.3 BERT 测试

**目录：** `cutetest/transformer_test/bert/`

| 测试变体 | 说明 |
|---------|------|
| ibert_1 | Q/K/V 投影阶段 |
| ibert_2 | QKᵀ / 整数 softmax 阶段 |
| ibert_2_notcm | 不使用 TCM |
| ibert_2_seg | 分段执行 |
| ibert_2_softpipe | 软件流水线 |

### 3.4 LLaMA3 测试

**目录：** `cutetest/transformer_test/llama/`

| 测试 | 说明 |
|------|------|
| llama3_1B_1 ~ llama3_1B_11 | LLaMA3 1B 实验的计算阶段，编号不是模型层号 |
| llama3_1B_*_nofuse | 不使用宏指令融合的对照 |
| llama3_1B_*_notcm | 不使用 TCM 的对照 |

目录中的对应阶段保留默认、nofuse、notcm 变体，用于研究：
- **宏指令融合**的加速效果
- **TCM** 对访存延迟的影响

## 4. 性能分析方法

CUTE 提供 4 级自顶向下性能分析方法论（详见 [测试框架设计](test-framework.md)）：

| 级别 | 分析维度 | 关键指标 |
|------|---------|---------|
| Level 1 | 系统级 | 总周期数、吞吐量 |
| Level 2 | 阶段级 | Load/Compute/Store/Stall 占比 |
| Level 3 | 组件级 | AML/BML/CML 负载平衡、MMU 停顿率 |
| Level 4 | 微操作级 | 计算效率、内存绑定度、并行度 |

当前仓库没有旧页所写的 `scripts/perf_analysis.py`。现有事件的解码与诊断入口见
[trace 文档](/trace/development/)。使用历史性能结果时仍须保留实际分析脚本与输入。

## 5. 参考

- 历史来源标注：CUTE v2 (DAC 2026)，本文未绑定可复核的具体论文版本。
- 当前结果：[能力与验收边界](/status/)。
- 测试目录：`cutetest/gemm_test/`、`cutetest/transformer_test/`
