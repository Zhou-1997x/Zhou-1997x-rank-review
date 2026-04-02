function analysis = analyze_system(TheSystem, cfg)
% ANALYZE_SYSTEM  对光学系统进行综合分析（点列图、MTF、波前）
%
%   analysis = analyze_system(TheSystem, cfg)
%
%   输入：
%       TheSystem - IOpticalSystem 对象
%       cfg       - 配置结构体
%
%   输出：
%       analysis  - 结构体，包含：
%           .spot       : 点列图数据结构体
%           .mtf        : MTF 数据结构体
%           .wavefront  : 波前误差 (PV & RMS)
%           .efl        : 系统有效焦距 (mm)

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

    if cfg.verbose
        fprintf('[analyze_system] 分析完成。\n');
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
    mtfSettings.SampleSize = CYCLOPAPI.Analysis.SampleSizes.S_256x256;
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
