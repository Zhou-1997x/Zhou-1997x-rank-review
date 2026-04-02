function results = run_raytrace(TheSystem, cfg)
% RUN_RAYTRACE  在当前系统上执行光线追迹并返回结果
%
%   results = run_raytrace(TheSystem, cfg)
%
%   输入：
%       TheSystem - IOpticalSystem 对象
%       cfg       - 配置结构体
%
%   输出：
%       results   - 结构体，包含：
%           .ray_data  : N×7 矩阵 [field_idx, px, py, x, y, z, intensity]
%           .n_success : 成功追迹的光线数
%           .n_fail    : 失败（全反射/遮挡）的光线数

    if cfg.verbose
        fprintf('[run_raytrace] 正在执行光线追迹...\n');
    end

    %% ===== 创建批量光线追迹工具 =====
    TheTool = TheSystem.Tools.OpenBatchRayTrace();
    normUnpol = TheTool.CreateNormUnpol( ...
        cfg.num_rings * cfg.num_arms * 3 + 10, ...  % 最大光线数
        CYCLOPAPI.Tools.RayTrace.RaysType.Real, ...
        TheSystem.LDE.NumberOfSurfaces - 1);         % 追迹到像面

    %% ===== 添加光线 =====
    nFields = TheSystem.SystemData.Fields.NumberOfFields;
    rayCount = 0;

    for fIdx = 1:nFields
        hx = TheSystem.SystemData.Fields.GetField(fIdx).X;
        hy = TheSystem.SystemData.Fields.GetField(fIdx).Y;

        for ring = 1:cfg.num_rings
            for arm = 1:cfg.num_arms
                theta = 2 * pi * (arm - 1) / cfg.num_arms;
                rho   = ring / cfg.num_rings;
                px = rho * cos(theta);
                py = rho * sin(theta);
                normUnpol.AddRay(0, hx, hy, px, py, ...
                    CYCLOPAPI.Tools.RayTrace.OPDMode.None);
                rayCount = rayCount + 1;
            end
        end
    end

    if cfg.verbose
        fprintf('[run_raytrace] 已添加 %d 条光线，正在追迹...\n', rayCount);
    end

    %% ===== 执行追迹 =====
    TheTool.RunAndWaitForCompletion();

    %% ===== 提取结果 =====
    ray_data  = zeros(rayCount, 7);
    n_success = 0;
    n_fail    = 0;
    fIdx_curr = 0;
    idx = 0;

    for fIdx = 1:nFields
        for ring = 1:cfg.num_rings
            for arm = 1:cfg.num_arms
                idx = idx + 1;
                readResult = normUnpol.ReadNextResult();

                if readResult.IsValid
                    n_success = n_success + 1;
                    ray_data(idx, :) = [ ...
                        fIdx, ...
                        ring / cfg.num_rings * cos(2*pi*(arm-1)/cfg.num_arms), ...
                        ring / cfg.num_rings * sin(2*pi*(arm-1)/cfg.num_arms), ...
                        readResult.X, ...
                        readResult.Y, ...
                        readResult.Z, ...
                        readResult.Intensity];
                else
                    n_fail = n_fail + 1;
                    ray_data(idx, :) = [fIdx, NaN, NaN, NaN, NaN, NaN, 0];
                end
            end
        end
    end

    %% ===== 关闭工具 =====
    TheTool.Close();

    %% ===== 打包返回 =====
    results.ray_data  = ray_data(1:idx, :);
    results.n_success = n_success;
    results.n_fail    = n_fail;

    if cfg.verbose
        fprintf('[run_raytrace] 追迹完成：成功 %d，失败 %d。\n', ...
            n_success, n_fail);
    end

end
