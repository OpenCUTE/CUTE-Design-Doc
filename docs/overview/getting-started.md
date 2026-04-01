# 快速上手指南

## 1. 环境准备

### 1.1 系统依赖

- **Java**: JDK 17+（SBT 运行时）
- **SBT**: Scala 构建工具
- **Verilator**: 用于 C++ 级仿真
- **GCC RISC-V 工具链**: 用于编译测试程序
- **DRAMSim3**: 内存仿真（可选）

### 1.2 初始化环境

```bash
cd CUTE
./scripts/setup-env.sh
```

该脚本将：
1. 初始化 git 子模块（chipyard 等）
2. 配置 chipyard 环境
3. 下载必要的依赖

### 1.3 安装 RISC-V 工具链

```bash
./scripts/setup-get-rvv-toolchain.sh
```

下载预编译的 RISC-V Vector (RVV) 工具链，用于编译测试 C 代码。

## 2. 编译与构建

### 2.1 生成 Verilog

```bash
./scripts/build-verilog.sh CUTE2TopsSCP64Config
```

可用配置参见 `build/chipyard/config/CuteConfig.scala`，常用配置：

| 配置名 | 说明 |
|--------|------|
| `CUTE2TopsSCP64Config` | 2 TOPS，64-bit SCP |
| `CUTE4TopsSCP64Config` | 4 TOPS，64-bit SCP |

### 2.2 构建仿真器

```bash
./scripts/build-simulator.sh CUTE2TopsSCP64Config
```

使用 Verilator 编译生成 C++ 仿真器。

## 3. 编译测试程序

```bash
./scripts/build_cute_test.sh
```

将编译以下测试：

- **base_test**: 基础 GEMM/Conv 测试和辅助工具
- **gemm_test**: 不同维度的矩阵乘法测试
- **resnet50_test**: ResNet50 卷积-向量融合核测试
- **transformer_test**: BERT 和 LLaMA 的 GEMM-向量融合核测试

## 4. 运行仿真

```bash
./scripts/run-simulator-test.sh \
    CUTE2TopsSCP64Config \
    /path/to/cutetest/base_test/cute_Matmul_mnk_128_128_128_zeroinit.riscv
```

输出：
- **Debug Info**: 仿真调试信息
- **UART log**: 程序串口输出

## 5. 目录结构

```
CUTE/
├── src/main/scala/       # Chisel 硬件设计源码
├── cutetest/             # C 测试代码
│   ├── base_test/        # 基础测试
│   ├── gemm_test/        # GEMM 测试
│   ├── resnet50_test/    # ResNet50 测试
│   └── transformer_test/ # Transformer 测试
├── CPU/                  # CPU 核集成方案
│   ├── rocket/           # Rocket Chip
│   ├── boom/             # BOOM
│   └── shuttle/          # Shuttle
├── cute-fpe/             # 混合精度 PE 项目
├── scripts/              # 构建和部署脚本
├── chipyard/             # Chipyard 框架（子模块）
└── doc/                  # 文档
```

## 6. 常见问题

### Q: Verilator 编译失败？
确保 Verilator 版本 ≥ 5.0，且 chipyard 子模块已正确初始化。

### Q: 测试程序无法运行？
确认已执行 `setup-get-rvv-toolchain.sh` 安装工具链，且 `.riscv` 文件路径正确。

### Q: 如何修改硬件参数？
修改 `src/main/scala/CUTEParameters.scala` 中的参数，或创建新的 Config 类。

## 7. 相关链接

- [CUTE 论文](https://www.sciencedirect.com/science/article/pii/S1383762124000432)
- [Chipyard 框架](https://github.com/ucb-bar/chipyard)
- [Chisel 语言](https://www.chisel-lang.org/)
