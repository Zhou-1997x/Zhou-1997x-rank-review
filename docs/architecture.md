# 架构说明 (Architecture)

## 模块依赖图

```
main_demo.m
│
├── config/zemax_config.m          ← 全局配置
│
├── src/connect_zemax.m            ← ZOS-API 连接
│       ↓
├── src/build_singlet_lens.m       ← 透镜构建
│       ↓
├── src/run_raytrace.m             ← 光线追迹
│       ↓
├── src/analyze_system.m           ← 系统分析 (Spot/MTF/Wavefront)
│       ↓
├── src/optimize_system.m          ← 优化 (DLS/Hammer)
│       ↓
├── src/utils/plot_results.m       ← 可视化
├── src/utils/save_results.m       ← 结果保存
└── src/utils/disconnect_zemax.m   ← 断开连接
```

## 数据流

```
[配置 cfg] → [连接 Zemax] → [构建透镜] → [光线追迹]
                                │              ↓
                                ↓         [ray_results]
                           [分析系统]
                                │
                                ↓
                          [analysis struct]
                                │
                    ┌───────────┴───────────┐
                    ↓                       ↓
              [优化系统]              [可视化/保存]
                    │
                    ↓
            [opt_results]
                    │
                    ↓
              [再次分析] → [最终可视化/保存]
```

## 核心接口

| 函数 | 输入 | 输出 |
|------|------|------|
| `zemax_config()` | 无 | `cfg` 结构体 |
| `connect_zemax(cfg)` | 配置 | `[TheApplication, TheSystem]` |
| `build_singlet_lens(sys, cfg)` | 系统+配置 | 修改后的 `TheSystem` |
| `run_raytrace(sys, cfg)` | 系统+配置 | `results` (光线数据) |
| `analyze_system(sys, cfg)` | 系统+配置 | `analysis` (点列图/MTF/波前) |
| `optimize_system(sys, cfg, ...)` | 系统+配置+选项 | `opt_results` |
| `plot_results(analysis, results, cfg)` | 分析+光线+配置 | 图形输出 |
| `save_results(analysis, opt, results, cfg)` | 全部数据 | 文件 (.mat/.txt) |
| `disconnect_zemax(app, cfg)` | Application+配置 | 无 |

## 扩展指南

1. **添加新光学系统**: 参考 `build_singlet_lens.m`，创建新的 `build_xxx.m`
2. **添加新分析**: 在 `analyze_system.m` 中添加子函数
3. **添加新优化方法**: 在 `optimize_system.m` 的 switch 块中扩展
4. **自定义可视化**: 在 `src/utils/` 中添加绘图函数
