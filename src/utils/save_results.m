function save_results(analysis, opt_results, results, cfg)
% SAVE_RESULTS  将分析与优化结果保存到文件
%
%   save_results(analysis, opt_results, results, cfg)
%
%   输入：
%       analysis    - analyze_system() 返回的结构体
%       opt_results - optimize_system() 返回的结构体（可为空 []）
%       results     - run_raytrace() 返回的结构体
%       cfg         - 配置结构体
%
%   输出文件：
%       results/summary.txt   - 人类可读的文本摘要
%       results/data.mat      - MATLAB 数据文件

    %% 确保输出目录存在
    if ~exist(cfg.output_dir, 'dir')
        mkdir(cfg.output_dir);
    end

    %% ===== 保存 .mat 数据 =====
    matFile = fullfile(cfg.output_dir, 'data.mat');
    save(matFile, 'analysis', 'opt_results', 'results', 'cfg');

    if cfg.verbose
        fprintf('[save_results] 数据已保存: %s\n', matFile);
    end

    %% ===== 生成文本摘要 =====
    txtFile = fullfile(cfg.output_dir, 'summary.txt');
    fid = fopen(txtFile, 'w');
    if fid == -1
        warning('save_results:FileOpen', '无法创建摘要文件: %s', txtFile);
        return;
    end

    fprintf(fid, '===== MATLAB + Zemax 原型分析报告 =====\n');
    fprintf(fid, '生成时间: %s\n\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

    % 系统参数
    fprintf(fid, '--- 系统参数 ---\n');
    fprintf(fid, '波长:       %.3f µm\n', cfg.wavelength_um);
    fprintf(fid, '入瞳直径:   %.1f mm\n', cfg.aperture_mm);
    fprintf(fid, '视场半角:   %.1f°\n', cfg.field_angle_deg);
    fprintf(fid, '有效焦距:   %.3f mm\n\n', analysis.efl);

    % 点列图
    fprintf(fid, '--- 点列图结果 ---\n');
    for fIdx = 1:length(analysis.spot.rms_radius)
        fprintf(fid, 'Field %d: RMS = %.2f µm, GEO = %.2f µm\n', ...
            fIdx, ...
            analysis.spot.rms_radius(fIdx) * 1000, ...
            analysis.spot.geo_radius(fIdx) * 1000);
    end
    fprintf(fid, '\n');

    % 波前
    fprintf(fid, '--- 波前误差 ---\n');
    fprintf(fid, 'PV  = %.4f waves\n', analysis.wavefront.pv);
    fprintf(fid, 'RMS = %.4f waves\n\n', analysis.wavefront.rms);

    % 光线追迹
    fprintf(fid, '--- 光线追迹 ---\n');
    fprintf(fid, '成功: %d, 失败: %d\n\n', results.n_success, results.n_fail);

    % 优化结果
    if ~isempty(opt_results)
        fprintf(fid, '--- 优化结果 ---\n');
        fprintf(fid, '方法:       %s\n', opt_results.method);
        fprintf(fid, '循环数:     %d\n', opt_results.n_cycles);
        fprintf(fid, '初始 Merit: %.6f\n', opt_results.merit_initial);
        fprintf(fid, '最终 Merit: %.6f\n', opt_results.merit_final);
        fprintf(fid, '改善:       %.2f%%\n', opt_results.improvement);
    end

    fprintf(fid, '\n===== 报告结束 =====\n');
    fclose(fid);

    if cfg.verbose
        fprintf('[save_results] 摘要已保存: %s\n', txtFile);
    end

end
