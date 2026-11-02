# 基准测试结果

## 1. 硬件配置

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

## 2. 论文评估结果（DAC 2026）

### 2.1 vs CPU Baseline 加速比

CUTE 4 TOPS 配置（4×4 PE, 14nm, 2GHz）与 Intel Xeon 8580（AMX，28 核，2.0GHz）的加速比：

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

CUTE 的可配置参数允许从 0.5 TOPS 到 32 TOPS 的线性扩展，面积与算力近似线性关系。

## 3. 测试矩阵

### 3.1 GEMM 测试

**目录：** `cutetest/gemm_test/`

| 测试名称 | M | N | K | 说明 |
|---------|---|---|---|------|
| 小矩阵 | 256 | 256 | 64 | 单 tile 内计算 |
| 中等矩阵 | 512 | 512 | 256 | 多 tile 计算 |
| 大 K 矩阵 | 512 | 512 | 1024 | K 维度远大于 tile |
| LLaMA 层模拟 | 512 | 512 | 10496 | 模拟 LLaMA 注意力层 |
| LLaMA 层模拟 | 512 | 512 | 10752 | 模拟 LLaMA FFN 层 |
| LLaMA 层模拟 | 512 | 512 | 11008 | 模拟 LLaMA FFN 层 |

### 3.2 ResNet50 测试

**目录：** `cutetest/resnet50_test/`

覆盖 ResNet50 全部 50+ 卷积层，包含 3×3 卷积、1×1 卷积、pooling 层等。

### 3.3 BERT 测试

**目录：** `cutetest/transformer_test/bert/`

| 测试变体 | 说明 |
|---------|------|
| ibert_1 | BERT 推理基本版本 |
| ibert_2 | 优化版本（宏指令融合） |
| ibert_2_notcm | 不使用 TCM |
| ibert_2_seg | 分段执行 |
| ibert_2_softpipe | 软件流水线 |

### 3.4 LLaMA3 测试

**目录：** `cutetest/transformer_test/llama/`

| 测试 | 说明 |
|------|------|
| llama3_1B_10 ~ 70+ | LLaMA3 1B 模型各层推理 |
| llama3_1B_*_nofuse | 不使用宏指令融合的对照 |
| llama3_1B_*_notcm | 不使用 TCM 的对照 |

每层测试提供 fuse/nofuse/notcm 三种变体，用于评估：
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

分析工具：`scripts/perf_analysis.py`

## 5. 参考

- 论文：CUTE v2 (DAC 2026)
- 性能分析指南：`scripts/PERFORMANCE_ANALYSIS_GUIDE.md`
- 测试目录：`cutetest/gemm_test/`、`cutetest/transformer_test/`
