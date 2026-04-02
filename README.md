# MATLAB + Zemax 最小可运行原型代码框架

[![MATLAB](https://img.shields.io/badge/MATLAB-R2020b%2B-blue.svg)](https://www.mathworks.com/)
[![Zemax](https://img.shields.io/badge/Zemax-OpticStudio%2021%2B-orange.svg)](https://www.zemax.com/)

一个 **最小可运行的** MATLAB + Zemax OpticStudio ZOS-API 原型代码框架，涵盖连接、建模、光线追迹、分析、优化的完整工作流。

## 📁 项目结构

```
.
├── main_demo.m                    # 🚀 主入口：完整演示流程
├── config/
│   └── zemax_config.m             # ⚙️ 全局配置（路径、参数）
├── src/
│   ├── connect_zemax.m            # 🔌 ZOS-API 连接管理
│   ├── build_singlet_lens.m       # 🔧 单透镜系统构建
│   ├── run_raytrace.m             # 💡 批量光线追迹
│   ├── analyze_system.m           # 📊 系统分析（Spot/MTF/Wavefront）
│   ├── optimize_system.m          # 🎯 DLS / Hammer 优化
│   └── utils/
│       ├── plot_results.m         # 📈 结果可视化
│       ├── save_results.m         # 💾 结果保存（.mat + .txt）
│       └── disconnect_zemax.m     # 🔌 安全断开连接
├── examples/
│   ├── example_quick_start.m      # 快速入门
│   ├── example_custom_lens.m      # 自定义透镜参数
│   └── example_parameter_sweep.m  # 参数扫描
├── tests/
│   ├── run_all_tests.m            # 运行所有测试
│   ├── test_config.m              # 配置模块测试
│   └── test_framework_structure.m # 文件结构完整性测试
└── docs/
    ├── architecture.md            # 架构说明
    └── api_reference.md           # API 参考文档
```

## 🚀 快速开始

### 环境要求

| 软件 | 版本 |
|------|------|
| MATLAB | R2020b 或更高 |
| Zemax OpticStudio | 21.1 或更高（需含 ZOS-API 许可） |
| .NET Framework | 4.x（Windows 自带） |

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/Zhou-1997x/Zhou-1997x-rank-review.git
   cd Zhou-1997x-rank-review
   ```

2. **配置 Zemax 路径**
   
   编辑 `config/zemax_config.m`，修改为你的 OpticStudio 安装路径：
   ```matlab
   cfg.zemax_install_dir = 'C:\Program Files\Zemax OpticStudio';
   ```

3. **运行主演示**
   ```matlab
   >> main_demo
   ```

### 5 行代码快速体验

```matlab
cfg = zemax_config();                          % 加载配置
[app, sys] = connect_zemax(cfg);               % 连接 Zemax
sys = build_singlet_lens(sys, cfg);            % 构建透镜
analysis = analyze_system(sys, cfg);           % 分析系统
disconnect_zemax(app, cfg);                    % 断开连接
```

## 📊 功能模块

| 模块 | 功能 | 对应 ZOS-API |
|------|------|-------------|
| `connect_zemax` | Standalone / Interactive 两种连接模式 | `ZOSAPI_Connection` |
| `build_singlet_lens` | 平凸单透镜快速构建 | `LDE` 表面操作 |
| `run_raytrace` | 批量光线追迹 | `BatchRayTrace` |
| `analyze_system` | 点列图 + FFT MTF + 波前 | `Analyses` |
| `optimize_system` | DLS / Hammer 自动优化 | `Tools.Optimization` |

## 🔧 自定义与扩展

### 修改光学参数

在 `config/zemax_config.m` 中调整：

```matlab
cfg.wavelength_um   = 0.632;    % 改为 He-Ne 激光
cfg.aperture_mm     = 50.0;     % 增大口径
cfg.field_angle_deg = 10.0;     % 增大视场
```

### 添加新的光学系统

参考 `src/build_singlet_lens.m`，创建新文件如 `src/build_doublet.m`。

### 添加新分析功能

在 `src/analyze_system.m` 中添加子函数，并将结果加入返回结构体。

## 📖 文档

- [架构说明](docs/architecture.md) - 模块依赖、数据流、接口一览
- [API 参考](docs/api_reference.md) - 所有函数的详细参数与返回值

## 🧪 测试

运行离线测试（不需要 Zemax）：

```matlab
>> cd tests
>> run_all_tests
```

## ⚠️ 注意事项

1. **ZOS-API 许可**: 需要 OpticStudio Premium 或 Professional 版本的 ZOS-API 许可
2. **Windows 限定**: ZOS-API 依赖 .NET Framework，仅支持 Windows
3. **Interactive 模式**: 需在 OpticStudio 中手动开启 `Programming > Interactive Extension`
4. **路径配置**: 首次使用务必修改 `config/zemax_config.m` 中的安装路径

## 📄 许可证

本项目仅供学术研究和学习使用。
