%% run_all_tests.m  —— 运行所有离线测试
%
%  本脚本运行所有不需要 Zemax 安装的测试。
%  在提交代码前建议运行此脚本确保框架完整性。
%
%  用法: >> run_all_tests

fprintf('######################################\n');
fprintf('#  运行所有离线测试                    #\n');
fprintf('######################################\n\n');

addpath(fullfile(fileparts(mfilename('fullpath'))));

try
    test_config;
    test_framework_structure;
    
    fprintf('\n######################################\n');
    fprintf('#  所有测试通过!                      #\n');
    fprintf('######################################\n');
catch ME
    fprintf('\n!!! 测试失败 !!!\n');
    fprintf('错误: %s\n', ME.message);
    fprintf('位置: %s (行 %d)\n', ME.stack(1).file, ME.stack(1).line);
end
