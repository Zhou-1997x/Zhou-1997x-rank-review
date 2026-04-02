function cfg = zemax_config()
% ZEMAX_CONFIG  全局配置：Zemax 连接参数与默认光学参数
%
%   cfg = zemax_config()
%
%   返回结构体 cfg，包含 ZOS-API 路径、连接模式及默认光学系统参数。
%   用户应根据本地安装修改此文件。

    %% ===== ZOS-API 路径配置 =====
    % OpticStudio 安装目录（包含 ZOSAPI.dll / ZOSAPI_Interfaces.dll）
    cfg.zemax_install_dir = 'C:\Program Files\Zemax OpticStudio';

    % ZOS-API .NET DLL 路径（通常在安装目录下）
    cfg.zosapi_dll = fullfile(cfg.zemax_install_dir, ...
        'ZOS-API', 'Libraries', 'ZOSAPI.dll');
    cfg.zosapi_interfaces_dll = fullfile(cfg.zemax_install_dir, ...
        'ZOS-API', 'Libraries', 'ZOSAPI_Interfaces.dll');

    %% ===== 连接模式 =====
    % 'standalone' : 启动独立 OpticStudio 实例（无 GUI）
    % 'interactive': 连接到已打开的 OpticStudio（需在 OpticStudio 中启用
    %                Interactive Extension 模式）
    cfg.connection_mode = 'standalone';

    %% ===== 默认光学系统参数 =====
    cfg.wavelength_um   = 0.550;        % 默认波长 (µm)，550 nm 可见光
    cfg.field_angle_deg = 5.0;          % 默认视场半角 (°)
    cfg.aperture_mm     = 25.0;         % 入瞳直径 (mm)
    cfg.num_rings       = 6;            % 光线追迹环数
    cfg.num_arms        = 8;            % 光线追迹臂数

    %% ===== 输出与日志 =====
    cfg.output_dir   = fullfile(pwd, 'results');   % 结果输出目录
    cfg.save_figures = true;                       % 是否自动保存图片
    cfg.verbose      = true;                       % 是否打印详细日志

end
