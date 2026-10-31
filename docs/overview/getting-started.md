# 快速上手指南

从 CUTE 仓库根目录选择下面的入口。硬件设计站解释模块和接口，跨模块命令集中
维护在主指南，避免两套构建说明随代码变化而分歧。

## 选择工作流

| 目标 | 使用入口 | 下一步 |
|---|---|---|
| 理解仓库、依赖和当前状态 | [主指南](/repository/) | 检查顶层及相关子模块版本 |
| 从 YAML 生成配置和 simulator | [构建系统](/build-system/) | 使用 `cute-build.py` 和 HWConfig |
| 修改参数、ISA 或生成文件 | [配置与代码生成](/configuration/) | 改来源文件，再运行对应生成器 |
| 编译 SDK 并运行已有测试 | [SDK 入门](/sdk/getting-started/) | 选择 suite 或 system 流程 |
| 验证 CUTE/RVV 输出和同步 | [系统级验证](/system-verification/) | 同源双 ELF、QEMU 校准、RTL 全输出比较 |
| 运行 BERT / LLaMA 阶段 | [模型构建](/build-system/#model-builds) | 使用独立 profile 和运行目录 |

## 环境与配置

已有环境激活 `chipyard/env.sh` 或本机工具环境。全新 checkout 才按
[环境准备](/build-system/) 初始化子模块并安装工具；`scripts/setup-env.sh`
会下载和构建依赖，不能作为工具找不到时的通用修复操作。

硬件配置引用关系为 `HWConfig → ChipyardConfig → CuteConfig + ISA + VectorVersion`。
生成的 Chipyard Scala 配置位于
`chipyard/generators/chipyard/src/main/scala/config/CuteConfig.scala`。
修改参数时先找到对应 YAML；不要直接改生成类来绕过配置检查。

## 历史 cutetest

`scripts/build-verilog.sh`、`build-simulator.sh`、`build-test.sh` 和
`run-simulator-test.sh` 保留旧 Chipyard / cutetest 流程。旧 `CUTE2TopsSCP64Config`
等配置名称仍用于这些实验，但不能代替当前 system profile 的配置与构建清单。

`cutetest/transformer_test/bert` 和 `llama` 提供阶段程序及调度变体；数字后缀的
计算含义见 [测试框架](../software/test-framework.md)，不能按完整模型层号理解。
新迁移使用 `cute-sdk/tests/models` 中的确定非零输入和独立 reference。

## 判断是否通过

编译成功、模拟器正常退出、日志打印 `Pass` 和全部输出验证通过是不同的结果。
验收需保留输入、ELF、simulator、配置及报告身份，按
[运行程序与结果](/running/) 判定。当前已覆盖的配置和用例见
[能力与验收边界](/status/)。
