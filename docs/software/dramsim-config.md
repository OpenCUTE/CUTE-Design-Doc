# DRAMSim 配置说明

## 1. 术语说明

| 术语 | 说明 |
|------|------|
| DRAMSim2 | 开源 DRAM 周期精确仿真器，模拟内存系统的时序行为 |
| system.ini | DRAMSim 系统级配置（通道数、队列深度、调度策略等） |
| device.ini | DRAMSim 设备级配置（DRAM 芯片参数：时序、容量等） |
| Open Page Policy | 行缓冲策略：保持打开的行以减少激活开销 |

## 2. 概述

CUTE 使用 DRAMSim2 作为 Verilator 仿真中的内存模型。由于矩阵运算数据量大，内存带宽和延迟直接影响仿真结果的准确性。DRAMSim2 提供周期精确的内存时序仿真，使仿真能够反映真实硬件中的访存行为。

## 3. 可用配置

CUTE 提供 6 种带宽预设配置：

| 配置目录 | 带宽 | 适用场景 |
|---------|------|---------|
| `dramsim2_ini_8GB_per_s/` | 8 GB/s | 低带宽场景，测试带宽受限情况 |
| `dramsim2_ini_16GB_per_s/` | 16 GB/s | 中低带宽 |
| `dramsim2_ini_24GB_per_s/` | 24 GB/s | 中等带宽 |
| `dramsim2_ini_32GB_per_s/` | 32 GB/s | 中高带宽 |
| `dramsim2_ini_48GB_per_s/` | 48 GB/s | 高带宽 |
| `dramsim2_ini_64GB_per_s/` | 64 GB/s | 高带宽场景，接近峰值性能 |

每个配置目录包含两个文件：
- `system.ini` — 系统级配置
- `DDR3_micron_64M_8B_x4_sg15.ini` — DRAM 设备参数

## 4. 系统配置参数（system.ini）

| 参数 | 值 | 说明 |
|------|-----|------|
| `NUM_CHANS` | 1 | 独立内存通道数 |
| `JEDEC_DATA_BUS_BITS` | 64 | 数据总线宽度（bit） |
| `TRANS_QUEUE_DEPTH` | 256 | 事务队列深度（CPU 级命令） |
| `CMD_QUEUE_DEPTH` | 256 | 命令队列深度（DRAM 级命令） |
| `EPOCH_LENGTH` | 100000 | 仿真统计周期长度 |
| `ROW_BUFFER_POLICY` | `open_page` | 行缓冲策略（open_page / close_page） |
| `ADDRESS_MAPPING_SCHEME` | `scheme7` | 地址映射方案（1-7，scheme7 并行度最高） |
| `SCHEDULING_POLICY` | `rank_then_bank_round_robin` | 调度策略 |
| `QUEUING_STRUCTURE` | `per_rank` | 队列组织方式 |
| `TOTAL_ROW_ACCESSES` | 16 | 同一行最大连续访问次数（防饿死） |
| `USE_LOW_POWER` | true | 空闲时进入低功耗模式 |

## 5. 使用方法

### 5.1 选择配置

在运行仿真时通过环境变量或配置文件指定 DRAMSim 配置目录：

```bash
# 使用高带宽配置进行性能评估
export DRAMSIM_CONFIG=dramsim2_ini_64GB_per_s
./scripts/run-simulator-test.sh CUTE2TopsSCP64Config test.riscv

# 使用低带宽配置暴露内存瓶颈
export DRAMSIM_CONFIG=dramsim2_ini_8GB_per_s
./scripts/run-simulator-test.sh CUTE2TopsSCP64Config test.riscv
```

### 5.2 配置选择建议

| 测试目标 | 推荐配置 | 说明 |
|---------|---------|------|
| 功能验证 | 任意 | 带宽不影响功能正确性 |
| 性能评估 | 32/64 GB/s | 接近真实硬件带宽 |
| 带宽瓶颈分析 | 8/16 GB/s | 暴露内存瓶颈 |

## 6. 参考

- 配置目录：`cutetest/dramsim_config/`
- DRAMSim2 项目：https://github.com/dramsim2/dramsim2
