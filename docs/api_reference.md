# API 参考文档

## 配置模块

### `zemax_config()`

返回全局配置结构体。

**字段说明：**

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `zemax_install_dir` | string | `'C:\Program Files\Zemax OpticStudio'` | OpticStudio 安装路径 |
| `zosapi_dll` | string | (自动拼接) | ZOSAPI.dll 完整路径 |
| `connection_mode` | string | `'standalone'` | 连接模式: `'standalone'` / `'interactive'` |
| `wavelength_um` | double | 0.550 | 工作波长 (µm) |
| `field_angle_deg` | double | 5.0 | 视场半角 (°) |
| `aperture_mm` | double | 25.0 | 入瞳直径 (mm) |
| `num_rings` | int | 6 | 光线追迹环数 |
| `num_arms` | int | 8 | 光线追迹臂数 |
| `output_dir` | string | `'./results'` | 输出目录 |
| `save_figures` | logical | true | 是否保存图片 |
| `verbose` | logical | true | 是否显示详细日志 |

---

## 连接模块

### `connect_zemax(cfg)`

建立与 Zemax OpticStudio 的 ZOS-API 连接。

**参数：**
- `cfg` - 配置结构体

**返回：**
- `TheApplication` - IZOSAPI_Application 对象
- `TheSystem` - IOpticalSystem 主系统对象

---

## 构建模块

### `build_singlet_lens(TheSystem, cfg)`

在已连接的系统上构建平凸单透镜。

**默认参数：**
- 前表面曲率: R = 100 mm
- 后表面: 平面
- 中心厚度: 5 mm
- 材料: N-BK7
- 像距: 自动求解 (Marginal Ray Height Solve)

---

## 光线追迹模块

### `run_raytrace(TheSystem, cfg)`

执行批量光线追迹。

**返回结构体字段：**
- `ray_data` - N×7 矩阵 `[field_idx, px, py, x, y, z, intensity]`
- `n_success` - 成功光线数
- `n_fail` - 失败光线数

---

## 分析模块

### `analyze_system(TheSystem, cfg)`

综合分析（点列图 + MTF + 波前）。

**返回结构体字段：**
- `efl` - 有效焦距 (mm)
- `spot.rms_radius` - 各视场 RMS 点列图半径 (mm)
- `spot.geo_radius` - 各视场几何半径 (mm)
- `spot.x`, `spot.y` - 光线坐标 (cell array)
- `mtf.frequency` - 空间频率 (cycles/mm)
- `mtf.tangential`, `mtf.sagittal` - MTF 值 (cell array)
- `wavefront.pv` - 波前 PV (waves)
- `wavefront.rms` - 波前 RMS (waves)

---

## 优化模块

### `optimize_system(TheSystem, cfg, Name, Value)`

**可选参数：**

| 名称 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `'Method'` | string | `'DLS'` | `'DLS'` (阻尼最小二乘) 或 `'HAMMER'` (全局优化) |
| `'Cycles'` | int | 50 | 优化循环数 |
| `'Criterion'` | string | `'RMS'` | `'RMS'` (RMS 点列图) 或 `'PTV'` (PV 波前) |
| `'Variables'` | function_handle | [] | 自定义变量设置函数 |

**返回结构体字段：**
- `merit_initial` - 初始评价函数值
- `merit_final` - 最终评价函数值
- `improvement` - 改善百分比
- `n_cycles` - 循环数
- `method` - 优化方法名称

---

## 工具模块

### `plot_results(analysis, results, cfg)`

生成点列图、MTF、光线分布三张图表。

### `save_results(analysis, opt_results, results, cfg)`

保存 `data.mat` 和 `summary.txt` 到输出目录。

### `disconnect_zemax(TheApplication, cfg)`

安全关闭 Zemax 连接。
