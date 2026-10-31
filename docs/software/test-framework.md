# 测试框架与实验来源

当前维护流程包括 SDK suite 和系统级验证。`cutetest` 保留历史实验来源，
文件名、二进制或日志的存在不代表当前源码已通过对应测试。

## 当前验证入口

| 流程 | 输入与执行 | 结果保证 |
|---|---|---|
| SDK suite / memverify | `tests/*.yaml`、case、已有 golden、Verilator trace | 按 case 选择位级或容差比较；用于已有测试开发 |
| S1 系统基线 | 同源双裸机 ELF、独立数值参考、QEMU 与 RTL | DDR / TCM、同步、全部输出及 trace 完整性 |
| 模型阶段 | `tests/models` 生成 profile、非零输入和逐任务输出 | BERT B1–B6 / LLaMA L1–L4，逐阶段 QEMU 校准与 RTL 字节比较 |

构建与运行命令见 [主指南](/build-system/) 和 [SDK 入门](/sdk/getting-started/)。
系统 runner 逐项核对构建清单，保留在线及离线报告。通过条件见
[系统级验证](/system-verification/)，已验收用例见 [状态页](/status/)。

## 历史 cutetest 的层次

| 目录 | 内容 | 使用时需核对 |
|---|---|---|
| `cutetest/base_test/` | 通信、FIFO、基础矩阵乘法和卷积 | 数据类型、输入、等待语义和输出比较方式 |
| `cutetest/gemm_test/` | 不同 M/N/K 的 GEMM 实验 | tile 分解、矩阵布局、配置和产物版本 |
| `cutetest/transformer_test/bert/` | BERT 各计算阶段及调度变体 | 整数近似、量化、残差顺序和原始形状 |
| `cutetest/transformer_test/llama/` | LLaMA 计算阶段及 CPU / nofuse / notcm 对照 | 实际 FP16 格式、scale、RoPE、归约顺序 |
| `cutetest/resnet50_test/` | 历史卷积负载与数据 | 不属于本次 SDK 迁移与验收范围 |

### BERT 阶段编号

| 原入口 | 计算阶段 | 新 case |
|---|---|---|
| `ibert_1.c` / `ibert-base-1.c` | Q/K/V 投影、量化与 V 转置 | `bert_1` |
| `ibert_2.c` / `ibert-base-2.c` | 各 head 的 QKᵀ 与整数 softmax | `bert_2` |
| `ibert_3.c` / `ibert-base-3.c` | 概率乘 V 与 head 拼接 | `bert_3` |
| `ibert_4.c` / `ibert-base-4.c` | 输出投影、LayerNorm、残差 | `bert_4` |
| `ibert_5.c` / `ibert-base-5.c` | FF1、bias、整数 GELU | `bert_5` |
| `ibert_6.c` / `ibert-base-6.c` | FF2、bias、LayerNorm、残差 | `bert_6` |

`ibert_1` 和 `ibert_2` 是不同计算阶段，不能作为“基本版/优化版”互相替代。
`notcm`、`seg`、`softpipe` 等后缀描述对应阶段的实验变体。

### LLaMA 阶段编号

| 原入口 `llama3_1B_*.c` | 计算阶段 | 新 case / 状态 |
|---|---|---|
| `1`、`8` | attention / FFN RMSNorm 与 token 量化 | `llama_1` |
| `2`、`3`、`4` | Q/K/V 投影、反量化、Q/K RoPE、V 转置 | `llama_2` |
| `5`、`6` | 浮点矩阵 attention 相关阶段 | L5 后续范围 |
| `7` | context 量化、输出投影、残差 | `llama_3` |
| `9`、`10`、`11` | gate + SiLU、up + Hadamard、down + 残差 | `llama_4` |

`llama3_1B_10.c` 是 FFN up/Hadamard 阶段，不是模型第 10 层。当前目录包含
1–11 阶段及相应变体，没有旧文档所写的 `llama3_1B_70+` 阶段序列。
`nofuse`、`notcm` 的历史调度及性能不能从新 DDR 串行 tile 实现的通过结果外推。
迁移数值规则详见 [SDK 模型迁移](/sdk/testing/workload-migration/)。

## 构建与诊断

当前入口位于 `tools/runner/`；旧实验还保留 `scripts/build-test.sh`、
`build-verilog.sh`、`build-simulator.sh` 和 `run-simulator-test.sh`。
两条路径需分别记录输入、配置、编译器和二进制身份，不能混用历史 `.riscv` 与新报告。

性能分析可按总周期、Load/Compute/Store/Stall、组件访存和 tile 利用率逐层定位。
当前仓库没有旧文档曾引用的 `scripts/perf_analysis.py` 或
`scripts/PERFORMANCE_ANALYSIS_GUIDE.md`。分析现有事件从
[trace 开发与诊断](/trace/development/) 开始；性能结论还需完整指标和重复实验记录。
