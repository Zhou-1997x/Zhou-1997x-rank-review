%% startup.m  —— 项目启动脚本（自动设置路径）
%
%  将此文件所在目录设为 MATLAB 当前目录后，运行此脚本或
%  将其放在 MATLAB 用户路径中，即可自动加载所有项目模块。
%
%  用法：
%    >> cd('path/to/Zhou-1997x-rank-review')
%    >> startup    % 自动执行

projectRoot = fileparts(mfilename('fullpath'));

% 添加所有子目录到路径
addpath(fullfile(projectRoot, 'src'));
addpath(fullfile(projectRoot, 'src', 'utils'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'examples'));
addpath(fullfile(projectRoot, 'tests'));

fprintf('=== MATLAB + Zemax 原型框架 ===\n');
fprintf('项目根目录: %s\n', projectRoot);
fprintf('路径已自动加载。\n');
fprintf('  输入 "help connect_zemax"   查看连接帮助\n');
fprintf('  输入 "main_demo"            运行完整演示\n');
fprintf('  输入 "run_all_tests"        运行离线测试\n');
fprintf('================================\n\n');
