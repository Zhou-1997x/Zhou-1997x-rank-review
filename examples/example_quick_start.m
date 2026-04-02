%% example_quick_start.m  —— 快速入门示例
%
%  最简化的 MATLAB + Zemax 连接-构建-分析流程。
%  适合第一次使用本框架的用户。

clear; clc; close all;

%% 添加路径
projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, '..', 'src'));
addpath(fullfile(projectRoot, '..', 'src', 'utils'));
addpath(fullfile(projectRoot, '..', 'config'));

%% 1. 加载配置
cfg = zemax_config();

%% 2. 连接 Zemax
[app, sys] = connect_zemax(cfg);

%% 3. 构建简单透镜
sys = build_singlet_lens(sys, cfg);

%% 4. 分析
analysis = analyze_system(sys, cfg);

fprintf('\n===== 快速入门结果 =====\n');
fprintf('有效焦距: %.3f mm\n', analysis.efl);
fprintf('轴上 RMS 点列图半径: %.2f µm\n', analysis.spot.rms_radius(1) * 1000);
fprintf('波前 RMS: %.4f waves\n', analysis.wavefront.rms);

%% 5. 断开
disconnect_zemax(app, cfg);
fprintf('完成！\n');
