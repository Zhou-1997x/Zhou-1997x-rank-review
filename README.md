# MATLAB + Zemax 最小可运行原型代码框架

[![MATLAB](https://img.shields.io/badge/MATLAB-R2020b%2B-blue.svg)](https://www.mathworks.com/)
[![Zemax](https://img.shields.io/badge/Zemax-OpticStudio%2021%2B-orange.svg)](https://www.zemax.com/)

一个 **最小可运行的** MATLAB + Zemax OpticStudio ZOS-API 原型代码框架，涵盖连接、建模、光线追迹、分析、优化的完整工作流。

## 📁 项目结构

```
.
├── main_demo.m                    # 🚀 主入口：完整演示流程
├── startup.m                      # 🔧 自动路径设置（cd 到项目目录后运行）
├── config/
│   └── zemax_config.m             # ⚙️ 全局配置（路径、参数、透镜规格）
├── src/
│   ├── connect_zemax.m            # 🔌 ZOS-API 连接（自动检测 + 重试）
│   ├── build_singlet_lens.m       # 🔧 单透镜构建（参数可配置）
│   ├── run_raytrace.m             # 💡 批量光线追迹
│   ├── analyze_system.m           # 📊 分析（Spot/MTF/Wavefront/Seidel）
│   ├── optimize_system.m          # 🎯 DLS / Hammer 优化
│   └── utils/
│       ├── plot_results.m         # 📈 结果可视化（点列图/MTF/光线）
│       ├── plot_layout.m          # 📐 2D 光学系统布局图
│       ├── save_results.m         # 💾 结果保存（.mat + .txt）
│       ├── validate_config.m      # ✅ 配置校验
│       └── disconnect_zemax.m     # 🔌 安全断开连接
├── examples/
│   ├── example_interactive_session.m  # ★ 交互式实操（同时开 MATLAB+Zemax）
│   ├── example_quick_start.m          # 快速入门（5 行代码）
│   ├── example_custom_lens.m          # 自定义透镜参数
│   └── example_parameter_sweep.m      # 参数扫描（高效版）
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

2. **配置 Zemax 路径**（框架会自动检测常见路径，通常可跳过此步）
   
   如果自动检测失败，编辑 `config/zemax_config.m`：
   ```matlab
   cfg.zemax_install_dir = 'C:\Program Files\Zemax OpticStudio';
   ```

3. **初始化路径**
   ```matlab
   >> cd('path/to/Zhou-1997x-rank-review')
   >> startup    % 自动添加所有子目录到 MATLAB 路径
   ```

4. **运行主演示**
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

---

## ★ 交互式实操指南（同时打开 MATLAB + Zemax）

> **这是最推荐的使用方式** —— 在 MATLAB 中写代码控制 Zemax，同时在 Zemax 窗口中实时观察变化。

### 操作步骤

```
┌──────────────────────────────────────────────────────────┐
│  步骤 1: 打开 Zemax OpticStudio                          │
│  步骤 2: 点击菜单 Programming → Interactive Extension    │
│  步骤 3: 等待状态栏显示 "Interactive Extension Running"   │
│  步骤 4: 切换到 MATLAB，运行交互示例                      │
└──────────────────────────────────────────────────────────┘
```

```matlab
>> startup                              % 初始化路径
>> example_interactive_session          % 运行交互式实操示例
```

### 交互示例中你会学到

| 步骤 | 操作 | 你能看到的效果 |
|------|------|---------------|
| 1 | MATLAB 连接 Zemax | Zemax 状态栏变化 |
| 2 | 构建透镜系统 | Zemax Lens Data Editor 出现数据 |
| 3 | 分析系统 | MATLAB 输出 EFL、RMS、波前等指标 |
| 4 | **逐步修改曲率** | **Zemax 2D Layout 实时变化** |
| 5 | 运行优化 | Zemax 表面参数自动调整 |
| 6 | 对比前后结果 | 两端同时显示改善效果 |
| 7 | **在 Zemax 手动修改** | **MATLAB 读取你的手动修改** |
| 8 | 保存结果 | PNG 图 + .mat 数据 + 文本报告 |

### 自定义透镜参数

```matlab
cfg = zemax_config();
cfg.connection_mode = 'interactive';   % 交互模式

% 修改透镜规格
cfg.lens.R1        = 80;              % 前表面曲率半径 (mm)
cfg.lens.R2        = -200;            % 后表面曲率半径 (mm)
cfg.lens.thickness = 8;               % 中心厚度 (mm)
cfg.lens.material  = 'N-SF11';        % 换一种玻璃

% 修改系统参数
cfg.wavelength_um   = 0.632;          % He-Ne 激光
cfg.aperture_mm     = 50;             % 50 mm 口径

[app, sys] = connect_zemax(cfg);
sys = build_singlet_lens(sys, cfg);   % → Zemax 实时显示变化!
```

---

## 📊 功能模块

| 模块 | 功能 | 对应 ZOS-API |
|------|------|-------------|
| `connect_zemax` | Standalone / Interactive 模式 + 自动检测 + 重试 | `ZOSAPI_Connection` |
| `build_singlet_lens` | 可配置参数的单透镜构建 | `LDE` 表面操作 |
| `run_raytrace` | 批量光线追迹 | `BatchRayTrace` |
| `analyze_system` | 点列图 + FFT MTF + 波前 + **Seidel 像差** | `Analyses` |
| `optimize_system` | DLS / Hammer + 曲率/厚度变量 | `Tools.Optimization` |
| `validate_config` | 配置完整性 & 合理性校验 | — |
| `plot_layout` | 2D 光学系统截面布局图 | `LDE` 数据提取 |

## 🔧 自定义与扩展

### 修改透镜规格

```matlab
cfg = zemax_config();
cfg.lens.R1        = 80;         % 前表面曲率
cfg.lens.R2        = -150;       % 后表面曲率（负 = 弯向像方）
cfg.lens.thickness = 8;          % 厚度
cfg.lens.material  = 'N-SF11';   % 高折射率玻璃
cfg.lens.stop_dist = 15;         % 光阑距离
```

### 修改系统参数

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
4. **路径配置**: 框架会自动检测常见安装路径；如果失败，请修改 `config/zemax_config.m`
5. **并发限制**: 同一时间只能有一个 MATLAB 实例连接到 Zemax

## 📄 许可证

本项目仅供学术研究和学习使用。
