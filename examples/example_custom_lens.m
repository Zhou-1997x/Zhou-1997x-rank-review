%% example_custom_lens.m  —— 自定义透镜参数示例
%
%  演示如何修改配置参数，构建不同规格的光学系统，
%  并比较优化前后的性能。

clear; clc; close all;

%% 添加路径
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, '..', 'src'));
addpath(fullfile(projectRoot, '..', 'src', 'utils'));
addpath(fullfile(projectRoot, '..', 'config'));

%% 1. 自定义配置
cfg = zemax_config();
cfg.wavelength_um   = 0.632;    % He-Ne 激光波长 632.8 nm
cfg.field_angle_deg = 3.0;      % 较小视场
cfg.aperture_mm     = 50.0;     % 较大口径
cfg.output_dir      = fullfile(pwd, 'results_custom');

fprintf('自定义配置: λ=%.3f µm, 口径=%.1f mm, 视场=%.1f°\n', ...
    cfg.wavelength_um, cfg.aperture_mm, cfg.field_angle_deg);

%% 2. 连接 & 构建
[app, sys] = connect_zemax(cfg);
sys = build_singlet_lens(sys, cfg);

%% 3. 优化前分析
fprintf('\n--- 优化前 ---\n');
analysis_pre = analyze_system(sys, cfg);

%% 4. 使用 Hammer 全局优化
opt = optimize_system(sys, cfg, ...
    'Method', 'HAMMER', 'Cycles', 20, 'Criterion', 'RMS');

%% 5. 优化后分析
fprintf('\n--- 优化后 ---\n');
analysis_post = analyze_system(sys, cfg);
ray_results   = run_raytrace(sys, cfg);

%% 6. 对比输出
fprintf('\n===== 优化对比 =====\n');
fprintf('            优化前       优化后\n');
fprintf('RMS 点列图: %.2f µm    %.2f µm\n', ...
    analysis_pre.spot.rms_radius(1)*1000, ...
    analysis_post.spot.rms_radius(1)*1000);
fprintf('波前 RMS:   %.4f waves  %.4f waves\n', ...
    analysis_pre.wavefront.rms, analysis_post.wavefront.rms);
fprintf('Merit:      %.6f       %.6f (↓%.2f%%)\n', ...
    opt.merit_initial, opt.merit_final, opt.improvement);

%% 7. 保存
plot_results(analysis_post, ray_results, cfg);
save_results(analysis_post, opt, ray_results, cfg);

%% 8. 断开
disconnect_zemax(app, cfg);
fprintf('\n自定义透镜示例完成！\n');
