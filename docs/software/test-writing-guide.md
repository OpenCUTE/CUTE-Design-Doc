# 测试编写指南

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| ygjk.h | 低级指令宏，直接编码 RISC-V `.word` 指令 |
| cuteMarcoinstHelper.h | 高级 C API，封装配置和执行流程 |
| MacroInst FIFO | 宏指令队列，深度 4，TaskController 从中取指令执行 |
| funct | RoCC 指令的功能码字段，base=64 为配置指令，base=0 为查询指令 |

## 2. 快速开始

### 2.1 编写一个矩阵乘法测试

矩阵乘法测试的基本流程：**配置 A/B/C/D 张量 → 配置维度 → 配置数据类型 → 发送宏指令 → 等待完成 → 读取结果**。

#### 完整示例

```c
#include "marchid.h"
#include "cuteMarcoinstHelper.h"
#include "matmul_value_mnk_128_128_128_zeroinit.h"  // 测试数据

int main() {
    // 1. 计算步长
    uint64_t A_Stride = APPLICATION_K;  // K
    uint64_t B_Stride = APPLICATION_N;  // N
    uint64_t D_Stride = APPLICATION_N;  // N
    uint64_t C_Stride = APPLICATION_N;  // N

    // 2. 选择数据类型
    int element_type = CUTEDataTypeF16F16F32;  // FP16
    int bias_type = TaskTypeTensorZeroLoad;     // 零初始化累加器

    // 3. 发送宏指令（一步完成配置+执行）
    issue_cute_matmul_marco_inst(
        a, A_Stride,       // A 矩阵地址和步长
        b, B_Stride,       // B 矩阵地址和步长
        d, D_Stride,       // D 结果地址和步长
        c, C_Stride,       // C bias 地址和步长
        APPLICATION_M, APPLICATION_N, APPLICATION_K,  // 维度
        element_type, bias_type,
        0,                 // 不转置
        0                  // matmul_m_index
    );

    // 4. 验证 FIFO 有有效指令
    if (!cute_marco_inst_fifo_valid_search()) {
        return -1;  // FIFO 为空，指令未入队
    }

    // 5. 等待完成（轮询）
    while (!cute_marco_inst_fifo_finish_search()) {
        // 等待中...
    }

    // 6. 读取性能计数器
    uint64_t acc_time = YGJK_INS_RRR(0, 0, 0, 2);   // 累加器运行时间
    uint64_t read_req = YGJK_INS_RRR(0, 0, 0, 3);   // 内存读请求次数
    uint64_t write_req = YGJK_INS_RRR(0, 0, 0, 4);  // 内存写请求次数
    uint64_t comp_cycles = YGJK_INS_RRR(0, 0, 0, 5); // 计算周期数

    printf("Pass! read=%lu write=%lu compute=%lu\n",
           read_req, write_req, comp_cycles);

    return 0;
}
```

### 2.2 编写一个卷积测试

```c
#include "marchid.h"
#include "cuteMarcoinstHelper.h"
#include "conv_value_mnk_196_256_256_k3_s1_oh14.h"

int main() {
    uint64_t start_cycle = mrdcycle();

    issue_cute_conv_marco_inst(
        input, INPUT_STRIDE,    // 输入特征图
        weight, WEIGHT_STRIDE,  // 卷积核
        bias, BIAS_STRIDE,      // bias
        output, OUTPUT_STRIDE,  // 输出
        APPLICATION_M, APPLICATION_N, APPLICATION_K,
        CUTEDataTypeI8I8I32,    // 数据类型
        TaskTypeTensorRepeatRowLoad,  // bias 类型（行广播）
        0,                      // 不转置
        OH_MAX, OW_MAX,         // 输出尺寸
        KERNEL_SIZE, STRIDE_SIZE // 卷积核和步长
    );

    if (!cute_marco_inst_fifo_valid_search()) return -1;

    while (!cute_marco_inst_fifo_finish_search()) {
        // 等待
    }

    uint64_t end_cycle = mrdcycle();
    printf("Cycles: %lu\n", end_cycle - start_cycle);
    return 0;
}
```

## 3. 编程接口详解

### 3.1 指令编码宏（ygjk.h）

| 宏 | opcode | 说明 |
|----|--------|------|
| `CUSTOM0` | 0x0B | 数据操作指令 |
| `CUSTOM1` | 0x2B | 控制指令 |
| `CUSTOM2` | 0x5B | TLB 操作指令 |
| `CUSTOM3` | 0x7B | 测试指令 |
| `YGJK_INS_RRR(rd, rs1, rs2, fun)` | CUSTOM0 | 主指令宏，通过 t0/t1/t2 传递参数 |
| `YGJK_CTRL_FUNC(fun)` | CUSTOM1 | 无参数控制指令 |

寄存器约定：
- `t0 (x5)`：返回值
- `t1 (x6)`：rs1 参数
- `t2 (x7)`：rs2 参数

### 3.2 高级 API（cuteMarcoinstHelper.h）

#### 张量配置

| 函数 | funct | 说明 |
|------|-------|------|
| `issue_cute_config_ATensor(addr, stride)` | 65 | 配置 A 张量基地址和步长 |
| `issue_cute_config_BTensor(addr, stride)` | 66 | 配置 B 张量 |
| `issue_cute_config_CTensor(addr, stride)` | 67 | 配置 C 张量（bias/累加初值） |
| `issue_cute_config_DTensor(addr, stride)` | 68 | 配置 D 张量（输出） |

#### 维度配置

| 函数 | funct | 参数打包格式 |
|------|-------|-------------|
| `issue_cute_config_MNK_KERNALSTRIDE(M, N, K, ks)` | 69 | M[0:19], N[20:39], K[40:59], kernel_stride[60:63] |

#### 执行控制

| 函数 | funct | 说明 |
|------|-------|------|
| `issue_cute_marco_inst()` | 64 | 将配置好的指令推入 FIFO |
| `issue_cute_matmul_marco_inst(...)` | 64 | 一步完成矩阵乘法的配置和发送 |
| `issue_cute_conv_marco_inst(...)` | 64 | 一步完成卷积的配置和发送 |

#### 状态查询（funct base=0）

| 函数 | funct | 说明 |
|------|-------|------|
| `cute_is_running()` | 1 | 查询加速器是否在运行 |
| `cute_running_cycles()` | 2 | 查询当前运行周期数 |
| `cute_memory_load_request()` | 3 | 查询内存读请求次数 |
| `cute_memory_store_request()` | 4 | 查询内存写请求次数 |
| `cute_compute_cycles()` | 5 | 查询计算阶段周期数 |
| `cute_marco_inst_fifo_finish_search()` | 6 | 查询宏指令是否完成 |
| `cute_marco_inst_fifo_full_search()` | 7 | 查询 FIFO 是否已满 |
| `cute_marco_inst_fifo_valid_search()` | 8 | 查询 FIFO 是否有有效指令 |

### 3.3 数据类型枚举

```c
#define CUTEDataTypeI8I8I32     0    // INT8 × INT8 → INT32
#define CUTEDataTypeF16F16F32   1    // FP16 × FP16 → FP32
#define CUTEDataTypeBF16BF16F32 2    // BF16 × BF16 → FP32
#define CUTEDataTypeTF32TF32F32 3    // TF32 × TF32 → FP32
#define CUTEDataTypeI8U8I32     4    // INT8 × UINT8 → INT32
#define CUTEDataTypeU8I8I32     5    // UINT8 × INT8 → INT32
#define CUTEDataTypeU8U8I32     6    // UINT8 × UINT8 → INT32
#define CUTEDataTypee4m3F32     7    // FP8 E4M3 × FP8 E4M3 → FP32
```

### 3.4 Bias 类型枚举

```c
#define TaskTypeTensorZeroLoad      1    // C 累加器填零
#define TaskTypeTensorRepeatRowLoad 2    // 加载一行广播（bias 向量）
#define TaskTypeTensorLoad          3    // 完整加载 C 矩阵
```

## 4. 测试数据管理

### 4.1 测试数据格式

测试数据以 C 头文件形式组织，包含输入矩阵和参考输出：

```c
// matmul_value_mnk_M_N_K.h
#define APPLICATION_M 128
#define APPLICATION_N 128
#define APPLICATION_K 128

static float a[APPLICATION_M * APPLICATION_K] = { ... };
static float b[APPLICATION_K * APPLICATION_N] = { ... };
static float c[APPLICATION_M * APPLICATION_N] = { ... };  // bias 或累加初值
static float d[APPLICATION_M * APPLICATION_N] = { ... };  // 参考输出
```

### 4.2 Tile 维度

默认 Tile 大小（与硬件 `Tensor_M/N/K` 参数对应）：

```c
#define Tensor_M_Element_Length 64
#define Tensor_N_Element_Length 64
#define Tensor_K_Element_Length 64
```

## 5. 编译和运行

### 5.1 编译测试程序

```bash
# 编译单个测试
riscv64-unknown-elf-gcc -std=gnu99 -g -O3 \
    -march=rv64imafdcv -mabi=lp64d \
    -static -specs=htif_nano.specs \
    -o test.riscv test.c

# 使用构建脚本
./scripts/build-test.sh
```

### 5.2 运行仿真

```bash
# 生成 Verilog
./scripts/build-verilog.sh CUTE2TopsSCP64Config

# 编译仿真器
./scripts/build-simulator.sh CUTE2TopsSCP64Config

# 运行测试
./scripts/run-simulator-test.sh CUTE2TopsSCP64Config test.riscv

# 运行并生成波形（用于调试）
./scripts/run-simulator-test-with-fst.sh CUTE2TopsSCP64Config test.riscv
```

## 6. 调试技巧

| 技巧 | 说明 |
|------|------|
| 性能计数器 | 通过 funct 2-5 读取各阶段周期数和访存次数 |
| FST 波形 | 使用 `run-simulator-test-with-fst.sh` 生成波形，用 GTKWave 查看 |
| UART 输出 | 测试程序中的 `printf` 输出会显示在仿真终端 |
| 三版本对比 | LLaMA 测试提供 fuse/notcm/nofuse 三种变体，可用于隔离问题 |
| AML/BML/CML 计数 | 可理论推导读写请求次数，与实际计数对比验证正确性 |

## 7. 参考

- 指令编码宏：`cutetest/base_test/ygjk.h`
- 高级 API：`cutetest/base_test/cuteMarcoinstHelper.h`
- 测试示例：`cutetest/base_test/cute_Matmul_mnk_128_128_128_zeroinit.c`
- 性能分析：`scripts/PERFORMANCE_ANALYSIS_GUIDE.md`
