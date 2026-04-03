function cfg = zemax_config()
% ZEMAX_CONFIG  全局配置：Zemax 连接参数与默认光学参数
%
%   cfg = zemax_config()
%
%   返回结构体 cfg，包含 ZOS-API 路径、连接模式及默认光学系统参数。
%   用户应根据本地安装修改此文件。
%
%   示例：
%       cfg = zemax_config();
%       cfg.connection_mode = 'interactive';   % 切换到交互模式
%       cfg.wavelength_um   = 0.632;           % 改为 He-Ne 波长

    %% ===== ZOS-API 路径配置 =====
    % OpticStudio 安装目录 —— 自动检测常见路径，找不到则使用默认值
    cfg.zemax_install_dir = auto_detect_zemax();

    % ZOS-API .NET DLL 路径（通常在安装目录下的 ZOS-API\Libraries）
    cfg.zosapi_dll = fullfile(cfg.zemax_install_dir, ...
        'ZOS-API', 'Libraries', 'ZOSAPI.dll');
    cfg.zosapi_interfaces_dll = fullfile(cfg.zemax_install_dir, ...
        'ZOS-API', 'Libraries', 'ZOSAPI_Interfaces.dll');

    %% ===== 连接模式 =====
    % 'standalone'  : 启动独立 OpticStudio 实例（无 GUI，适合批处理）
    % 'interactive' : 连接到已打开的 OpticStudio（需在 OpticStudio 中启用
    %                 Programming > Interactive Extension 模式）
    %
    %  ★ 如果你想同时打开 MATLAB 和 Zemax 实操，请设为 'interactive'
    cfg.connection_mode = 'standalone';

    %% ===== 默认光学系统参数 =====
    cfg.wavelength_um   = 0.550;        % 默认波长 (µm)，550 nm 可见光
    cfg.field_angle_deg = 5.0;          % 默认视场半角 (°)
    cfg.aperture_mm     = 25.0;         % 入瞳直径 (mm)
    cfg.num_rings       = 6;            % 光线追迹环数
    cfg.num_arms        = 8;            % 光线追迹臂数

    %% ===== 默认透镜参数 =====
    % 这些参数被 build_singlet_lens 使用，可在调用前修改
    cfg.lens.R1          = 100.0;       % 前表面曲率半径 (mm)
    cfg.lens.R2          = Inf;         % 后表面曲率半径 (mm)，Inf = 平面
    cfg.lens.thickness   = 5.0;         % 中心厚度 (mm)
    cfg.lens.material    = 'N-BK7';     % 玻璃材料
    cfg.lens.stop_dist   = 10.0;        % 光阑到前表面距离 (mm)

    %% ===== 输出与日志 =====
    cfg.output_dir   = fullfile(pwd, 'results');   % 结果输出目录
    cfg.save_figures = true;                       % 是否自动保存图片
    cfg.verbose      = true;                       % 是否打印详细日志

    %% ===== 连接参数 =====
    cfg.connect_timeout_sec = 60;       % 连接超时 (秒)
    cfg.connect_retry       = 3;        % 连接重试次数

end


function installDir = auto_detect_zemax()
% AUTO_DETECT_ZEMAX  自动检测 Zemax OpticStudio 安装路径
%   按优先级搜索常见安装位置，找到则返回，否则返回默认路径。

    candidates = {
        'C:\Program Files\Zemax OpticStudio'
        'C:\Program Files\Ansys Zemax OpticStudio'
        'C:\Program Files (x86)\Zemax OpticStudio'
        fullfile(getenv('PROGRAMFILES'), 'Zemax OpticStudio')
        fullfile(getenv('LOCALAPPDATA'), 'Programs', 'Zemax OpticStudio')
    };

    for i = 1:length(candidates)
        if ~isempty(candidates{i}) && exist(candidates{i}, 'dir')
            installDir = candidates{i};
            return;
        end
    end

    % 未找到，返回默认值（用户需手动修改）
    installDir = 'C:\Program Files\Zemax OpticStudio';
end
