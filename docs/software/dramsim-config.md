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

当前 config-first / system runner 使用 `configs/memconfigs/dramsim2/` 下的配置。
`cutetest/dramsim_config/` 保留旧实验副本。目录中的带宽名称是实验预设标签，
实际时序还取决于设备参数、通道、总线和时钟配置。

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

当前 `cute-run.py` 读取 HWConfig 的 `memory.model` 和 `memory.config`，生成
`+dramsim` 与 `+dramsim_ini_dir=...` 参数。例如，按主文档的 [系统构建](/build-system/)
生成 ELF 后，从 OpenCUTE 仓库根目录执行：

```bash
python3 tools/runner/cute-run.py \
  --hwconfig cute4tops_shuttle512_d512_v512_m512_sysbus512_membus1_core_dramsim48 \
  --test ../opencute-out/system/build/sdk/system/system_int8_verilator.riscv
```

该 HWConfig 引用 `dramsim2_ini_48GB_per_s`。需要其他带宽时，在自己的 HWConfig
中选择相应 `memory.config`，按 [配置检查](/configuration/) 验证引用。
系统和模型 runner 从构建清单读取 HWConfig 对应的 DRAM 配置，无需另填目录，完整
命令见 [运行程序与结果](/running/)。显式指定 `--dram-config` 时，也必须与清单一致。

旧 `scripts/run-simulator-test.sh` 本身不读取 `DRAMSIM_CONFIG` 环境变量；仅设置
该变量不能作为带宽已切换的证据。以运行包中的实际命令和配置为准。

### 5.2 配置选择建议

| 测试目标 | 推荐配置 | 说明 |
|---------|---------|------|
| 功能验证 | 已验收配置起步，再覆盖其他延迟 | 时序变化可能暴露同步或 buffer 复用问题 |
| 性能评估 | 与目标系统匹配的配置 | 记录带宽、延迟、通道和时钟，不能只看目录名称 |
| 带宽瓶颈分析 | 8/16 GB/s | 暴露内存瓶颈 |

## 6. 参考

- 当前配置目录：`configs/memconfigs/dramsim2/`
- 历史配置目录：`cutetest/dramsim_config/`
- DRAMSim2 项目：https://github.com/dramsim2/dramsim2
