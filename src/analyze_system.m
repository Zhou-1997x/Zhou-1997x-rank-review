function analysis = analyze_system(TheSystem, cfg)
% ANALYZE_SYSTEM  对光学系统进行综合分析（点列图、MTF、波前、Seidel 像差）
%
%   analysis = analyze_system(TheSystem, cfg)
%
%   输入：
%       TheSystem - IOpticalSystem 对象
%       cfg       - 配置结构体
%
%   输出：
%       analysis  - 结构体，包含：
%           .efl        : 系统有效焦距 (mm)
%           .spot       : 点列图数据结构体
%           .mtf        : MTF 数据结构体
%           .wavefront  : 波前误差 (PV & RMS)
%           .seidel     : Seidel 像差系数 (5 项三级像差)
%
%   示例：
%       analysis = analyze_system(sys, cfg);
%       fprintf('EFL = %.2f mm\n', analysis.efl);
%       fprintf('轴上 RMS = %.2f µm\n', analysis.spot.rms_radius(1)*1000);

    if cfg.verbose
        fprintf('[analyze_system] 正在执行系统分析...\n');
    end

    %% ===== 1. 基本系统参数 =====
    analysis.efl = TheSystem.SystemData.Aperture.EffectiveFocalLength;

    if cfg.verbose
        fprintf('  有效焦距 EFL = %.3f mm\n', analysis.efl);
    end

    %% ===== 2. 点列图 (Spot Diagram) =====
    analysis.spot = get_spot_diagram(TheSystem, cfg);

    %% ===== 3. MTF 分析 =====
    analysis.mtf = get_mtf(TheSystem, cfg);

    %% ===== 4. 波前误差 =====
    analysis.wavefront = get_wavefront(TheSystem, cfg);

    %% ===== 5. Seidel 像差系数 =====
    analysis.seidel = get_seidel(TheSystem, cfg);

    if cfg.verbose
        fprintf('[analyze_system] ✓ 分析完成。\n');
    end

end


%% ==================== 子函数 ====================

function spot = get_spot_diagram(TheSystem, cfg)
% GET_SPOT_DIAGRAM  获取点列图数据

    spotTool = TheSystem.Analyses.New_StandardSpot();
    spotTool.ApplyAndWaitForCompletion();

    spotResults = spotTool.GetResults();
    spotData    = spotResults.SpotData;

    spot.rms_radius = zeros(1, spotData.NumberOfFields);
    spot.geo_radius = zeros(1, spotData.NumberOfFields);
    spot.x = cell(1, spotData.NumberOfFields);
    spot.y = cell(1, spotData.NumberOfFields);

    for fIdx = 1:spotData.NumberOfFields
        fieldSpot = spotData.GetField(fIdx);
        spot.rms_radius(fIdx) = fieldSpot.RMSRadius;
        spot.geo_radius(fIdx) = fieldSpot.GeoRadius;

        nRays = fieldSpot.NumberOfRays;
        xdata = zeros(nRays, 1);
        ydata = zeros(nRays, 1);
        for rIdx = 1:nRays
            ray = fieldSpot.GetRay(rIdx);
            xdata(rIdx) = ray.X;
            ydata(rIdx) = ray.Y;
        end
        spot.x{fIdx} = xdata;
        spot.y{fIdx} = ydata;
    end

    spotTool.Close();

    if cfg.verbose
        fprintf('  点列图 RMS 半径 (µm):');
        fprintf(' %.2f', spot.rms_radius * 1000);
        fprintf('\n');
    end
end


function mtf = get_mtf(TheSystem, cfg)
% GET_MTF  获取 FFT MTF 数据

    mtfTool = TheSystem.Analyses.New_FftMtf();

    % 配置
    mtfSettings = mtfTool.GetSettings();
    mtfSettings.MaximumFrequency = 200;   % cycles/mm
    mtfSettings.SampleSize = ZOSAPI.Analysis.SampleSizes.S_256x256;
    mtfTool.ApplyAndWaitForCompletion();

    mtfResults = mtfTool.GetResults();
    mtfData    = mtfResults.DataSeries;

    mtf.frequency = [];
    mtf.tangential = {};
    mtf.sagittal   = {};

    if mtfData.Length > 0
        series0 = mtfData.Item(0);
        nPoints = series0.NumData;
        mtf.frequency = zeros(nPoints, 1);
        for i = 1:nPoints
            mtf.frequency(i) = series0.XData.Data(i);
        end

        for sIdx = 0:(mtfData.Length - 1)
            series = mtfData.Item(sIdx);
            vals = zeros(nPoints, 1);
            for i = 1:nPoints
                vals(i) = series.YData.Data(i);
            end
            if mod(sIdx, 2) == 0
                mtf.tangential{end+1} = vals;
            else
                mtf.sagittal{end+1} = vals;
            end
        end
    end

    mtfTool.Close();

    if cfg.verbose
        fprintf('  MTF 数据已提取，%d 个频率点。\n', length(mtf.frequency));
    end
end


function wf = get_wavefront(TheSystem, cfg)
% GET_WAVEFRONT  获取波前误差

    wfTool = TheSystem.Analyses.New_WavefrontMap();
    wfTool.ApplyAndWaitForCompletion();

    wfResults = wfTool.GetResults();

    wf.pv  = wfResults.PeakToValley;   % PV (waves)
    wf.rms = wfResults.RMS;             % RMS (waves)

    wfTool.Close();

    if cfg.verbose
        fprintf('  波前误差: PV = %.4f waves, RMS = %.4f waves\n', wf.pv, wf.rms);
    end
end


function seidel = get_seidel(TheSystem, cfg)
% GET_SEIDEL  提取 Seidel（三级）像差系数
%
%   五项 Seidel 像差:
%     S1 - 球差 (Spherical Aberration)
%     S2 - 彗差 (Coma)
%     S3 - 像散 (Astigmatism)
%     S4 - 场曲 (Field Curvature / Petzval)
%     S5 - 畸变 (Distortion)

    seidel = struct('S1', 0, 'S2', 0, 'S3', 0, 'S4', 0, 'S5', 0, ...
                    'names', {{'球差(S1)','彗差(S2)','像散(S3)','场曲(S4)','畸变(S5)'}});

    try
        seidelTool = TheSystem.Analyses.New_SeidelCoefficients();
        seidelTool.ApplyAndWaitForCompletion();

        seidelResults = seidelTool.GetResults();
        dataGrid = seidelResults.DataGrids;

        if dataGrid.Length > 0
            grid = dataGrid.Item(0);
            nRows = grid.NumberOfRows;
            nCols = grid.NumberOfColumns;

            % Seidel 系数表通常：每行是一个表面，列包含 S1~S5 和总和
            % 最后一行是总和 (Sum)
            if nRows > 0 && nCols >= 6
                sumRow = nRows - 1;   % 0-indexed 最后一行
                seidel.S1 = grid.Cell(sumRow, 1).DoubleValue;  % 球差
                seidel.S2 = grid.Cell(sumRow, 2).DoubleValue;  % 彗差
                seidel.S3 = grid.Cell(sumRow, 3).DoubleValue;  % 像散
                seidel.S4 = grid.Cell(sumRow, 4).DoubleValue;  % 场曲
                seidel.S5 = grid.Cell(sumRow, 5).DoubleValue;  % 畸变
            end
        end

        seidelTool.Close();

    catch ME
        if cfg.verbose
            fprintf('  [注意] Seidel 像差提取失败: %s\n', ME.message);
        end
    end

    if cfg.verbose
        fprintf('  Seidel 像差: S1=%.4f, S2=%.4f, S3=%.4f, S4=%.4f, S5=%.4f\n', ...
            seidel.S1, seidel.S2, seidel.S3, seidel.S4, seidel.S5);
    end
end
