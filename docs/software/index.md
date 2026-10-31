# 软件与测试

CUTE 软件通过 RoCC 自定义指令控制加速器。当前 SDK 提供 runtime、数值核、
测试描述和数值参考；历史 `cutetest` 提供实验来源及调度变体。系统验证依据成功
写 ack 重建内存，在软件任务完成时比较全部声明输出。

## 代码与入口

| 路径 | 内容 | 阅读入口 |
|---|---|---|
| `cute-sdk/cutelib/` | runtime、tensor、primitive、fusion、layer | [SDK 实现](/sdk/cutelib/primitive-and-fusion/) |
| `cute-sdk/tests/system/` | DDR / TCM 基线、checkpoint 与 QEMU 契约 | [系统级验证](/system-verification/) |
| `cute-sdk/tests/models/` | BERT B1–B6、LLaMA L1–L4 阶段、输入和 reference | [模型迁移](/sdk/testing/workload-migration/) |
| `tools/runner/`、`tools/verify/` | 构建、运行、C++ 检查器和独立回放 | [运行结果](/running/) |
| `cutetest/` | base/GEMM/卷积/Transformer 历史实验 | [测试框架](test-framework.md) |
| `configs/memconfigs/dramsim2/` | 当前 runner 使用的内存模型配置 | [DRAMSim 配置](dramsim-config.md) |

## 阅读顺序

新增 SDK 测试按 [case 与 checkpoint 接入](/sdk/testing/model-case/) 操作。
[测试编写指南](test-writing-guide.md) 保留旧 helper 的使用说明；其中示例需要
匹配历史配置，不自动具备系统验证的事务完整性保证。

[历史性能记录](benchmark-results.md) 与 [当前验收](/status/) 分别说明旧评估数据
和本机已验证范围。当前 28 项模型阶段用例没有覆盖训练权重精度、完整模型推理
或所有旧 TCM / double-buffer 调度。
