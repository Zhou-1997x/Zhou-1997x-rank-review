%% test_framework_structure.m  —— 测试框架文件结构完整性
%
%  验证所有必需的源文件、配置文件和目录都存在。
%  本测试不需要 Zemax 安装即可运行。

fprintf('=== 测试: 框架文件结构 ===\n');

projectRoot = fullfile(fileparts(mfilename('fullpath')), '..');

%% 检查目录
required_dirs = {
    'src'
    'src/utils'
    'config'
    'examples'
    'tests'
    'docs'
};

for i = 1:length(required_dirs)
    dirPath = fullfile(projectRoot, required_dirs{i});
    assert(exist(dirPath, 'dir') == 7, ...
        '缺少目录: %s', required_dirs{i});
    fprintf('  [OK] 目录: %s\n', required_dirs{i});
end

%% 检查核心源文件
required_files = {
    'main_demo.m'
    'startup.m'
    'config/zemax_config.m'
    'src/connect_zemax.m'
    'src/build_singlet_lens.m'
    'src/run_raytrace.m'
    'src/analyze_system.m'
    'src/optimize_system.m'
    'src/utils/plot_results.m'
    'src/utils/plot_layout.m'
    'src/utils/save_results.m'
    'src/utils/disconnect_zemax.m'
    'src/utils/validate_config.m'
};

for i = 1:length(required_files)
    filePath = fullfile(projectRoot, required_files{i});
    assert(exist(filePath, 'file') == 2, ...
        '缺少文件: %s', required_files{i});
    fprintf('  [OK] 文件: %s\n', required_files{i});
end

%% 检查示例文件
example_files = {
    'examples/example_quick_start.m'
    'examples/example_custom_lens.m'
    'examples/example_parameter_sweep.m'
    'examples/example_interactive_session.m'
};

for i = 1:length(example_files)
    filePath = fullfile(projectRoot, example_files{i});
    assert(exist(filePath, 'file') == 2, ...
        '缺少示例: %s', example_files{i});
    fprintf('  [OK] 示例: %s\n', example_files{i});
end

fprintf('=== 文件结构测试通过 ===\n\n');
