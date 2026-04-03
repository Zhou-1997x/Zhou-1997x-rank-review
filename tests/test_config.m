%% test_config.m  —— 测试配置模块
%
%  验证 zemax_config() 返回正确的结构体字段。
%  本测试不需要 Zemax 安装即可运行。

fprintf('=== 测试: zemax_config ===\n');

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'src', 'utils'));

cfg = zemax_config();

% 检查必需字段
assert(isfield(cfg, 'zemax_install_dir'),  '缺少 zemax_install_dir');
assert(isfield(cfg, 'zosapi_dll'),         '缺少 zosapi_dll');
assert(isfield(cfg, 'connection_mode'),     '缺少 connection_mode');
assert(isfield(cfg, 'wavelength_um'),       '缺少 wavelength_um');
assert(isfield(cfg, 'field_angle_deg'),     '缺少 field_angle_deg');
assert(isfield(cfg, 'aperture_mm'),         '缺少 aperture_mm');
assert(isfield(cfg, 'num_rings'),           '缺少 num_rings');
assert(isfield(cfg, 'num_arms'),            '缺少 num_arms');
assert(isfield(cfg, 'output_dir'),          '缺少 output_dir');
assert(isfield(cfg, 'save_figures'),        '缺少 save_figures');
assert(isfield(cfg, 'verbose'),             '缺少 verbose');

% 新增：检查 lens 子结构
assert(isfield(cfg, 'lens'),               '缺少 lens 子结构');
assert(isfield(cfg.lens, 'R1'),            '缺少 lens.R1');
assert(isfield(cfg.lens, 'R2'),            '缺少 lens.R2');
assert(isfield(cfg.lens, 'thickness'),     '缺少 lens.thickness');
assert(isfield(cfg.lens, 'material'),      '缺少 lens.material');
assert(isfield(cfg.lens, 'stop_dist'),     '缺少 lens.stop_dist');

% 新增：检查连接参数
assert(isfield(cfg, 'connect_timeout_sec'), '缺少 connect_timeout_sec');
assert(isfield(cfg, 'connect_retry'),       '缺少 connect_retry');

% 检查值类型
assert(isnumeric(cfg.wavelength_um)   && cfg.wavelength_um > 0,   '波长必须为正数');
assert(isnumeric(cfg.field_angle_deg) && cfg.field_angle_deg > 0, '视场角必须为正数');
assert(isnumeric(cfg.aperture_mm)     && cfg.aperture_mm > 0,     '口径必须为正数');
assert(isnumeric(cfg.num_rings)       && cfg.num_rings > 0,       '环数必须为正整数');
assert(isnumeric(cfg.num_arms)        && cfg.num_arms > 0,        '臂数必须为正整数');
assert(ischar(cfg.connection_mode),                                 '连接模式必须为字符串');
assert(islogical(cfg.save_figures),                                 'save_figures 必须为逻辑值');
assert(islogical(cfg.verbose),                                      'verbose 必须为逻辑值');
assert(isnumeric(cfg.lens.R1) && cfg.lens.R1 > 0,                 'lens.R1 必须为正数');
assert(isnumeric(cfg.lens.thickness) && cfg.lens.thickness > 0,   'lens.thickness 必须为正数');
assert(ischar(cfg.lens.material),                                   'lens.material 必须为字符串');

% 检查连接模式有效性
valid_modes = {'standalone', 'interactive'};
assert(ismember(cfg.connection_mode, valid_modes), ...
    '无效的连接模式: %s', cfg.connection_mode);

% 测试 validate_config 函数
[ok, msgs] = validate_config(cfg);
assert(ok, 'validate_config 应返回 true（忽略路径不存在的问题需在 Windows 上测试）');

fprintf('  所有字段存在: PASS\n');
fprintf('  值类型检查:   PASS\n');
fprintf('  validate_config: PASS\n');
fprintf('=== 配置测试通过 ===\n\n');
