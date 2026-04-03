function TheSystem = build_singlet_lens(TheSystem, cfg)
% BUILD_SINGLET_LENS  构建单透镜（Singlet）光学系统
%
%   TheSystem = build_singlet_lens(TheSystem, cfg)
%
%   在已连接的 TheSystem 上清除现有透镜数据并构建一个简单的
%   平凸单透镜系统，用于演示 ZOS-API 的基本表面操作。
%
%   输入：
%       TheSystem - IOpticalSystem 对象（由 connect_zemax 返回）
%       cfg       - 配置结构体（透镜参数从 cfg.lens 子结构读取）
%
%   输出：
%       TheSystem - 修改后的系统对象
%
%   透镜参数（通过 cfg.lens 配置）：
%       cfg.lens.R1         前表面曲率半径 (mm)，默认 100
%       cfg.lens.R2         后表面曲率半径 (mm)，默认 Inf（平面）
%       cfg.lens.thickness  中心厚度 (mm)，默认 5
%       cfg.lens.material   玻璃材料，默认 'N-BK7'
%       cfg.lens.stop_dist  光阑到前表面距离 (mm)，默认 10
%
%   示例：
%       cfg = zemax_config();
%       cfg.lens.R1 = 80;        % 改用 80 mm 曲率
%       cfg.lens.material = 'N-SF11';
%       sys = build_singlet_lens(sys, cfg);

    %% ===== 读取透镜参数（带默认值回退）=====
    R1        = get_lens_param(cfg, 'R1', 100.0);
    R2        = get_lens_param(cfg, 'R2', Inf);
    t         = get_lens_param(cfg, 'thickness', 5.0);
    glass     = get_lens_param(cfg, 'material', 'N-BK7');
    stop_dist = get_lens_param(cfg, 'stop_dist', 10.0);

    if cfg.verbose
        fprintf('[build_singlet_lens] 构建参数:\n');
        fprintf('  R1=%.1f mm, R2=%.1f mm, t=%.1f mm, 材料=%s\n', ...
            R1, R2, t, glass);
    end

    %% ===== 系统基本设置 =====
    TheLDE = TheSystem.LDE;          % Lens Data Editor

    % 清除现有数据，从空白系统开始
    TheSystem.New(false);            % false = 不提示保存
    TheSystem.SystemData.Aperture.ApertureValue = cfg.aperture_mm;

    %% ===== 设置波长 =====
    TheSystem.SystemData.Wavelengths.RemoveAll();
    TheSystem.SystemData.Wavelengths.AddWavelength(cfg.wavelength_um, 1.0);

    %% ===== 设置视场 =====
    TheSystem.SystemData.Fields.RemoveAll();
    TheSystem.SystemData.Fields.AddField(0, 0, 1.0);                         % 轴上
    TheSystem.SystemData.Fields.AddField(0, cfg.field_angle_deg * 0.7, 1.0);  % 0.7 视场
    TheSystem.SystemData.Fields.AddField(0, cfg.field_angle_deg, 1.0);        % 全视场

    %% ===== 插入表面 =====
    % Surface 0: OBJ (物面)
    % Surface 1: Stop (光阑)
    % Surface 2: 透镜前表面
    % Surface 3: 透镜后表面
    % Surface 4: IMA (像面)
    while TheLDE.NumberOfSurfaces < 4
        TheLDE.AddSurface();
    end

    % --- Surface 1: 光阑 (Stop) ---
    Surf1 = TheLDE.GetSurfaceAt(1);
    Surf1.Comment       = 'Stop';
    Surf1.Thickness     = stop_dist;
    Surf1.SemiDiameter  = cfg.aperture_mm / 2;

    % --- Surface 2: 透镜前表面 ---
    Surf2 = TheLDE.GetSurfaceAt(2);
    Surf2.Comment       = sprintf('Lens Front (R=%.1f)', R1);
    Surf2.Radius        = R1;
    Surf2.Thickness     = t;
    Surf2.Material      = glass;

    % --- Surface 3: 透镜后表面 ---
    Surf3 = TheLDE.GetSurfaceAt(3);
    Surf3.Comment       = sprintf('Lens Back (R=%.1f)', R2);
    Surf3.Radius        = R2;
    Surf3.Thickness     = 95.0;          % 初始猜测，由求解器调整

    %% ===== 设置像面求解 (Marginal Ray Height Solve) =====
    solveData = Surf3.ThicknessCell.CreateSolveType( ...
        ZOSAPI.Editors.LDE.SolveType.MarginalRayHeight);
    Surf3.ThicknessCell.SetSolveData(solveData);

    %% ===== 设置光线瞄准 =====
    TheSystem.SystemData.RayAiming.Type = ...
        ZOSAPI.SystemData.RayAimingType.Real;

    if cfg.verbose
        fprintf('[build_singlet_lens] ✓ 构建完成。共 %d 个表面。\n', ...
            TheLDE.NumberOfSurfaces);
    end

end


function val = get_lens_param(cfg, field, default)
% GET_LENS_PARAM  安全读取 cfg.lens 子字段，不存在则返回默认值
    if isfield(cfg, 'lens') && isfield(cfg.lens, field)
        val = cfg.lens.(field);
    else
        val = default;
    end
end
