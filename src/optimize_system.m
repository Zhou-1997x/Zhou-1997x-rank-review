function opt_results = optimize_system(TheSystem, cfg, varargin)
% OPTIMIZE_SYSTEM  对光学系统执行优化
%
%   opt_results = optimize_system(TheSystem, cfg)
%   opt_results = optimize_system(TheSystem, cfg, 'Name', Value, ...)
%
%   输入：
%       TheSystem - IOpticalSystem 对象
%       cfg       - 配置结构体
%
%   可选参数（Name-Value 对）：
%       'Method'       : 'DLS' (默认) 或 'HAMMER'
%       'Cycles'       : 优化循环数 (默认: 50)
%       'Criterion'    : 'RMS' (默认) 或 'PTV'
%       'Variables'     : 自定义变量设置函数句柄 (默认: 自动设置曲率变量)
%
%   输出：
%       opt_results - 结构体：
%           .merit_initial  : 初始评价函数值
%           .merit_final    : 优化后评价函数值
%           .improvement    : 改善百分比
%           .n_cycles       : 实际运行循环数

    %% ===== 解析参数 =====
    p = inputParser;
    addParameter(p, 'Method',    'DLS',  @ischar);
    addParameter(p, 'Cycles',    50,     @isnumeric);
    addParameter(p, 'Criterion', 'RMS',  @ischar);
    addParameter(p, 'Variables', [],     @(x) isempty(x) || isa(x, 'function_handle'));
    parse(p, varargin{:});
    opts = p.Results;

    if cfg.verbose
        fprintf('[optimize_system] 方法=%s, 循环数=%d, 准则=%s\n', ...
            opts.Method, opts.Cycles, opts.Criterion);
    end

    %% ===== 设置变量 =====
    if isempty(opts.Variables)
        set_default_variables(TheSystem, cfg);
    else
        opts.Variables(TheSystem, cfg);
    end

    %% ===== 设置评价函数 =====
    TheMFE = TheSystem.MFE;   % Merit Function Editor

    % 使用默认评价函数向导
    wizard = TheMFE.SEQOptimizationWizard;
    if strcmpi(opts.Criterion, 'RMS')
        wizard.Type = ZOSAPI.Editors.MFE.MeritCriterionType.RMSSpotRadiusCentroid;
    else
        wizard.Type = ZOSAPI.Editors.MFE.MeritCriterionType.PTV_OPD;
    end
    wizard.IsAssumeAxialSymmetry = true;
    wizard.Apply();

    %% ===== 记录初始 Merit =====
    merit_initial = TheMFE.CalculateMeritFunction();

    if cfg.verbose
        fprintf('  初始评价函数值: %.6f\n', merit_initial);
    end

    %% ===== 执行优化 =====
    switch upper(opts.Method)
        case 'DLS'
            optTool = TheSystem.Tools.OpenLocalOptimization();
            optTool.Algorithm = ...
                ZOSAPI.Tools.Optimization.OptimizationAlgorithm.DampedLeastSquares;
            optTool.Cycles    = opts.Cycles;
            optTool.NumberOfCores = 0;   % 0 = 全部可用核心

        case 'HAMMER'
            optTool = TheSystem.Tools.OpenGlobalOptimization();
            optTool.Cycles = opts.Cycles;
            optTool.NumberOfCores = 0;

        otherwise
            error('optimize_system:InvalidMethod', ...
                '不支持的优化方法: "%s"。请使用 "DLS" 或 "HAMMER"。', ...
                opts.Method);
    end

    if cfg.verbose
        fprintf('  正在运行 %s 优化...\n', opts.Method);
    end

    optTool.RunAndWaitForCompletion();
    optTool.Close();

    %% ===== 记录最终 Merit =====
    merit_final = TheMFE.CalculateMeritFunction();
    improvement = (merit_initial - merit_final) / merit_initial * 100;

    %% ===== 打包结果 =====
    opt_results.merit_initial = merit_initial;
    opt_results.merit_final   = merit_final;
    opt_results.improvement   = improvement;
    opt_results.n_cycles      = opts.Cycles;
    opt_results.method        = opts.Method;

    if cfg.verbose
        fprintf('  最终评价函数值: %.6f (改善 %.2f%%)\n', ...
            merit_final, improvement);
        fprintf('[optimize_system] 优化完成。\n');
    end

end


%% ==================== 子函数 ====================

function set_default_variables(TheSystem, cfg)
% SET_DEFAULT_VARIABLES  设置默认优化变量
%   将透镜前后表面曲率半径设为变量

    TheLDE = TheSystem.LDE;
    nSurf  = TheLDE.NumberOfSurfaces;

    for sIdx = 1:(nSurf - 1)
        surf = TheLDE.GetSurfaceAt(sIdx);
        material = char(surf.Material);

        % 对有玻璃材料的面及其前一面设置曲率变量
        if ~isempty(material)
            % 当前面（前表面）设置曲率变量
            surf.RadiusCell.MakeSolveVariable();
            if cfg.verbose
                fprintf('  Surface %d (%s): Radius -> Variable\n', ...
                    sIdx, char(surf.Comment));
            end

            % 如果存在下一个面（后表面），也设为变量
            if sIdx + 1 < nSurf
                nextSurf = TheLDE.GetSurfaceAt(sIdx + 1);
                nextSurf.RadiusCell.MakeSolveVariable();
                if cfg.verbose
                    fprintf('  Surface %d (%s): Radius -> Variable\n', ...
                        sIdx + 1, char(nextSurf.Comment));
                end
            end
        end
    end
end
