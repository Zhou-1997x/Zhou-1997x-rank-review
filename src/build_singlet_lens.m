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
%       cfg       - 配置结构体
%
%   输出：
%       TheSystem - 修改后的系统对象
%
%   透镜参数（可在此函数内调整）：
%       前表面曲率半径  R1 = 100 mm
%       后表面          平面 (R2 = Infinity)
%       中心厚度        t  = 5 mm
%       玻璃材料        N-BK7
%       像面距离        BFL ≈ 自动求解

    if cfg.verbose
        fprintf('[build_singlet_lens] 正在构建单透镜系统...\n');
    end

    %% ===== 系统基本设置 =====
    TheLDE = TheSystem.LDE;          % Lens Data Editor

    % 清除现有数据，从空白系统开始
    TheSystem.New(false);            % false = 不提示保存
    TheSystem.SystemData.Aperture.ApertureValue = cfg.aperture_mm;

    %% ===== 设置波长 =====
    TheSystem.SystemData.Wavelengths.RemoveAll();
    wl = TheSystem.SystemData.Wavelengths.AddWavelength(cfg.wavelength_um, 1.0);
    % wl 是 IWavelength 对象，权重 = 1.0

    %% ===== 设置视场 =====
    TheSystem.SystemData.Fields.RemoveAll();
    TheSystem.SystemData.Fields.AddField(0, 0, 1.0);                         % 轴上
    TheSystem.SystemData.Fields.AddField(0, cfg.field_angle_deg * 0.7, 1.0);  % 0.7 视场
    TheSystem.SystemData.Fields.AddField(0, cfg.field_angle_deg, 1.0);        % 全视场

    %% ===== 插入表面 =====
    % 默认有 OBJ (Surface 0) 和 IMA (最后一个面)
    % 添加 Surface 1: 前表面（球面）
    % 添加 Surface 2: 后表面（平面）
    % Surface 3: 像面 (IMA)

    % 确保至少有 3 个面 (OBJ + Stop + IMA)
    while TheLDE.NumberOfSurfaces < 4
        TheLDE.AddSurface();
    end

    % --- Surface 1: 光阑 (Stop) ---
    Surf1 = TheLDE.GetSurfaceAt(1);
    Surf1.Comment       = 'Stop';
    Surf1.Thickness     = 10.0;          % 光阑到前透镜面的距离 (mm)
    Surf1.SemiDiameter  = cfg.aperture_mm / 2;

    % --- Surface 2: 透镜前表面 ---
    Surf2 = TheLDE.GetSurfaceAt(2);
    Surf2.Comment       = 'Lens Front (R=100)';
    Surf2.Radius        = 100.0;         % 曲率半径 100 mm
    Surf2.Thickness     = 5.0;           % 中心厚度 5 mm
    Surf2.Material      = 'N-BK7';       % 玻璃材料

    % --- Surface 3: 透镜后表面 ---
    Surf3 = TheLDE.GetSurfaceAt(3);
    Surf3.Comment       = 'Lens Back (Plano)';
    Surf3.Radius        = Inf;           % 平面
    Surf3.Thickness     = 95.0;          % 后截距初始猜测

    %% ===== 设置像面求解 (Marginal Ray Height Solve) =====
    % 让 Zemax 自动调整后截距使边缘光线汇聚到像面
    solveData = Surf3.ThicknessCell.CreateSolveType( ...
        CYCLOPAPI.Editors.LDE.SolveType.MarginalRayHeight);
    Surf3.ThicknessCell.SetSolveData(solveData);

    %% ===== 更新系统 =====
    TheSystem.SystemData.RayAiming.Type = ...
        CYCLOPAPI.SystemData.RayAimingType.Real;

    if cfg.verbose
        fprintf('[build_singlet_lens] 单透镜构建完成。共 %d 个表面。\n', ...
            TheLDE.NumberOfSurfaces);
    end

end
