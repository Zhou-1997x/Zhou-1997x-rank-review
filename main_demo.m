%% main_demo.m  —— MATLAB + Zemax 最小可运行原型 (Main Entry Point)
%
%  本脚本演示完整的 MATLAB ↔ Zemax OpticStudio 工作流：
%    1. 加载配置 & 校验
%    2. 连接 Zemax
%    3. 构建单透镜系统
%    4. 执行光线追迹
%    5. 系统分析（点列图 / MTF / 波前 / Seidel）
%    6. 优化
%    7. 重新分析 & 可视化
%    8. 保存结果
%    9. 断开连接
%
%  使用方法：
%    1) 确保已安装 Zemax OpticStudio 并可用
%    2) 修改 config/zemax_config.m 中的路径（或依赖自动检测）
%    3) 在 MATLAB 命令行运行: >> main_demo
%
%  ★ 如需同时打开 MATLAB 和 Zemax 实操，请改用:
%    >> example_interactive_session
%
%  作者: Zhou-1997x
%  日期: 2026-04-02 (updated 2026-04-03)

clear; clc; close all;

%% ===== 添加路径 =====
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'src'));
addpath(fullfile(projectRoot, 'src', 'utils'));
addpath(fullfile(projectRoot, 'config'));

fprintf('============================================\n');
fprintf('  MATLAB + Zemax 最小可运行原型\n');
fprintf('============================================\n\n');

%% ===== Step 1: 加载配置 & 校验 =====
fprintf('Step 1/9: 加载配置...\n');
cfg = zemax_config();
[cfgOk, cfgMsgs] = validate_config(cfg);
if ~cfgOk
    fprintf('  ⚠ 配置问题:\n');
    for i = 1:length(cfgMsgs)
        fprintf('    %d. %s\n', i, cfgMsgs{i});
    end
    fprintf('  请修改 config/zemax_config.m 后重试。\n');
    return;
end
fprintf('  波长: %.3f µm, 入瞳: %.1f mm, 视场: %.1f°\n', ...
    cfg.wavelength_um, cfg.aperture_mm, cfg.field_angle_deg);
fprintf('  透镜: R1=%.0f mm, 材料=%s, 厚度=%.1f mm\n\n', ...
    cfg.lens.R1, cfg.lens.material, cfg.lens.thickness);

%% ===== Step 2: 连接 Zemax =====
fprintf('Step 2/9: 连接 Zemax OpticStudio (%s 模式)...\n', cfg.connection_mode);
[TheApplication, TheSystem] = connect_zemax(cfg);

%% ===== Step 3: 构建光学系统 =====
fprintf('\nStep 3/9: 构建单透镜系统...\n');
TheSystem = build_singlet_lens(TheSystem, cfg);

%% ===== Step 4: 光线追迹 =====
fprintf('\nStep 4/9: 执行光线追迹...\n');
ray_results = run_raytrace(TheSystem, cfg);
fprintf('  追迹完成: %d 条光线成功。\n', ray_results.n_success);

%% ===== Step 5: 系统分析 (优化前) =====
fprintf('\nStep 5/9: 优化前分析...\n');
analysis_before = analyze_system(TheSystem, cfg);

%% ===== Step 6: 优化 =====
fprintf('\nStep 6/9: 执行 DLS 优化...\n');
opt_results = optimize_system(TheSystem, cfg, ...
    'Method', 'DLS', 'Cycles', 50, 'Criterion', 'RMS');
fprintf('  Merit: %.6f → %.6f (改善 %.2f%%)\n', ...
    opt_results.merit_initial, opt_results.merit_final, opt_results.improvement);

%% ===== Step 7: 优化后分析 =====
fprintf('\nStep 7/9: 优化后分析...\n');
analysis_after = analyze_system(TheSystem, cfg);
ray_results_after = run_raytrace(TheSystem, cfg);

%% ===== Step 8: 可视化 & 保存 =====
fprintf('\nStep 8/9: 生成图表并保存结果...\n');
plot_results(analysis_after, ray_results_after, cfg);
plot_layout(TheSystem, cfg);
save_results(analysis_after, opt_results, ray_results_after, cfg);
fprintf('  结果已保存到: %s\n', cfg.output_dir);

%% ===== Step 9: 断开连接 =====
fprintf('\nStep 9/9: 断开 Zemax 连接...\n');
disconnect_zemax(TheApplication, cfg);

fprintf('\n============================================\n');
fprintf('  ✓ 全部流程完成！\n');
fprintf('============================================\n');
