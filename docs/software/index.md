# 软件与测试

CUTE 的软件生态包含驱动程序、测试框架和基准测试。驱动层通过 RISC-V 自定义指令（RoCC 接口）控制加速器；测试层从基础矩阵乘法到端到端 ML 模型推理覆盖多层级验证。

## 目录结构

```
CUTE/
├── cutetest/                          # 软件测试程序
│   ├── base_test/                     # 基础测试（hello world、矩阵乘法、卷积）
│   │   ├── ygjk.h                     # 自定义指令宏定义
│   │   └── cuteMarcoinstHelper.h      # 高级 C API 接口
│   ├── gemm_test/                     # GEMM 基准测试（多种矩阵尺寸）
│   ├── resnet50_test/                 # ResNet50 卷积层测试
│   └── transformer_test/              # Transformer 模型测试
│       ├── bert/                      # BERT 推理测试
│       └── llama/                     # LLaMA3 推理测试（1B/2B/4B）
├── tests/cute_benchmarks/             # 综合基准测试程序
├── scripts/                           # 构建和运行脚本
│   ├── build-verilog.sh               # Chisel → Verilog 生成
│   ├── build-simulator.sh             # Verilator 仿真器构建
│   ├── run-simulator-test.sh          # 仿真运行
│   └── perf_analysis.py               # 性能分析脚本
└── cutetest/dramsim_config/           # DRAMSim 内存仿真配置
    ├── dramsim2_ini_8GB_per_s/
    ├── dramsim2_ini_16GB_per_s/
    └── ...                            # 共 6 种带宽配置（8-64 GB/s）
```

## 导航

| 文档 | 说明 |
|------|------|
| [测试框架设计](test-framework.md) | 多层级测试架构和测试基础设施 |
| [测试编写指南](test-writing-guide.md) | 测试编写方法和代码模板 |
| [DRAMSim 配置说明](dramsim-config.md) | 内存仿真器配置参数 |
| [基准测试结果](benchmark-results.md) | 性能数据和测试矩阵 |
