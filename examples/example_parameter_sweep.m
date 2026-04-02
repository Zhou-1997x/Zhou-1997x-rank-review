%% example_parameter_sweep.m  —— 参数扫描示例
%
%  演示如何对透镜曲率半径进行参数扫描，
%  观察 RMS 点列图半径随曲率的变化趋势。
%  这是 MATLAB 数值循环 + Zemax 分析引擎协作的典型用法。

clear; clc; close all;

%% 添加路径
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, '..', 'src'));
addpath(fullfile(projectRoot, '..', 'src', 'utils'));
addpath(fullfile(projectRoot, '..', 'config'));

%% 1. 基础配置
cfg = zemax_config();
cfg.verbose = false;   % 扫描时关闭详细输出以提高效率

%% 2. 连接 Zemax
[app, sys] = connect_zemax(cfg);

%% 3. 定义扫描范围
R_values = 50:10:200;   % 前表面曲率半径 50~200 mm
rms_results = zeros(size(R_values));

fprintf('正在扫描前表面曲率半径 R = %d ~ %d mm (%d 个点)...\n', ...
    R_values(1), R_values(end), length(R_values));

%% 4. 参数扫描
for i = 1:length(R_values)
    % 构建系统
    sys = build_singlet_lens(sys, cfg);

    % 修改前表面曲率
    TheLDE = sys.LDE;
    Surf2 = TheLDE.GetSurfaceAt(2);
    Surf2.Radius = R_values(i);

    % 更新系统并分析
    analysis = analyze_system(sys, cfg);
    rms_results(i) = analysis.spot.rms_radius(1) * 1000;  % 转为 µm

    fprintf('  R = %3d mm → RMS = %.2f µm\n', R_values(i), rms_results(i));
end

%% 5. 绘图
figure('Name', 'Parameter Sweep', 'NumberTitle', 'off');
plot(R_values, rms_results, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6);
xlabel('Front Surface Radius (mm)');
ylabel('RMS Spot Radius (µm)');
title('Parameter Sweep: RMS vs Front Curvature Radius');
grid on;

% 标记最优点
[minRMS, minIdx] = min(rms_results);
hold on;
plot(R_values(minIdx), minRMS, 'r*', 'MarkerSize', 15, 'LineWidth', 2);
text(R_values(minIdx) + 5, minRMS, ...
    sprintf('最优 R=%.0f mm\nRMS=%.2f µm', R_values(minIdx), minRMS), ...
    'Color', 'r', 'FontSize', 10);
hold off;

fprintf('\n最优前表面曲率半径: R = %.0f mm, RMS = %.2f µm\n', ...
    R_values(minIdx), minRMS);

%% 6. 保存
if cfg.save_figures
    if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
    saveas(gcf, fullfile(cfg.output_dir, 'parameter_sweep.png'));
end

%% 7. 断开
disconnect_zemax(app, cfg);
fprintf('参数扫描完成！\n');
