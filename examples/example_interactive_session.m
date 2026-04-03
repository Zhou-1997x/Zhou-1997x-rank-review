%% example_interactive_session.m
%  ============================================================
%  ★★★  MATLAB + Zemax 交互式实操示例  ★★★
%  ============================================================
%
%  本示例专为 "同时打开 MATLAB 和 Zemax OpticStudio" 的实操场景设计。
%  你可以在 MATLAB 中逐段运行代码，同时在 Zemax 界面上实时观察变化。
%
%  ============ 使用前准备 ============
%
%  步骤 1: 打开 Zemax OpticStudio
%  步骤 2: 在 OpticStudio 中点击:
%          Programming → Interactive Extension
%          等待状态栏显示 "Interactive Extension Running..."
%  步骤 3: 回到 MATLAB，逐段运行下面的代码（Ctrl+Enter 逐节执行）
%
%  ============ 注意事项 ============
%
%  - 每次修改后，你可以在 Zemax 窗口中看到 Lens Data Editor 实时更新
%  - 你也可以在 Zemax 中手动修改参数，然后在 MATLAB 中读取
%  - Interactive 模式下，Zemax GUI 完全可操作
%  - 如果连接断开，请在 Zemax 中重新启用 Interactive Extension
%
%  作者: Zhou-1997x
%  日期: 2026-04-03
%  ============================================================

%% ========== 第 0 步：初始化环境 ==========
clear; clc; close all;

% 自动设置路径（如果从项目根目录运行 startup.m 可跳过此步）
projectRoot = fullfile(fileparts(mfilename('fullpath')), '..');
addpath(fullfile(projectRoot, 'src'));
addpath(fullfile(projectRoot, 'src', 'utils'));
addpath(fullfile(projectRoot, 'config'));

fprintf('============================================================\n');
fprintf('  MATLAB + Zemax 交互式实操示例\n');
fprintf('============================================================\n');
fprintf('请确保:\n');
fprintf('  1. Zemax OpticStudio 已打开\n');
fprintf('  2. 已点击 Programming → Interactive Extension\n');
fprintf('  3. 状态栏显示 "Interactive Extension Running..."\n');
fprintf('============================================================\n\n');
fprintf('准备好后，请按任意键继续...\n');
pause;

%% ========== 第 1 步：连接到 Zemax（Interactive 模式）==========
fprintf('\n>>> 第 1 步: 连接到 Zemax...\n');

cfg = zemax_config();
cfg.connection_mode = 'interactive';   % ★ 关键：使用交互模式
cfg.verbose = true;

% 连接到已打开的 OpticStudio
[TheApplication, TheSystem] = connect_zemax(cfg);

fprintf('\n✓ 连接成功! 现在 MATLAB 和 Zemax 已建立双向通信。\n');
fprintf('  → 请查看 Zemax 窗口，它现在受 MATLAB 控制。\n\n');

%% ========== 第 2 步：构建单透镜系统 ==========
fprintf('>>> 第 2 步: 构建单透镜系统...\n');
fprintf('  → 执行后请查看 Zemax 的 Lens Data Editor，你会看到表面数据出现\n\n');

cfg.lens.R1        = 100;       % 前表面曲率半径 100 mm
cfg.lens.R2        = Inf;       % 后表面平面
cfg.lens.thickness = 5;         % 中心厚度 5 mm
cfg.lens.material  = 'N-BK7';   % 玻璃材料

TheSystem = build_singlet_lens(TheSystem, cfg);

fprintf('\n✓ 单透镜已构建!\n');
fprintf('  → 在 Zemax 中你应该能看到:\n');
fprintf('    Surface 1: Stop\n');
fprintf('    Surface 2: Lens Front (R=100)\n');
fprintf('    Surface 3: Lens Back (平面)\n');
fprintf('  → 点击 Zemax 中的 "2D Layout" 按钮查看光路图\n\n');

fprintf('观察完毕后，按任意键继续...\n');
pause;

%% ========== 第 3 步：初始分析 ==========
fprintf('\n>>> 第 3 步: 分析当前系统...\n');

analysis = analyze_system(TheSystem, cfg);

fprintf('\n┌─────────────── 分析结果 ───────────────┐\n');
fprintf('│ 有效焦距 (EFL):    %8.2f mm          │\n', analysis.efl);
fprintf('│ 轴上 RMS 点列图:   %8.2f µm          │\n', analysis.spot.rms_radius(1)*1000);
fprintf('│ 全视场 RMS 点列图: %8.2f µm          │\n', analysis.spot.rms_radius(end)*1000);
fprintf('│ 波前 PV:           %8.4f waves       │\n', analysis.wavefront.pv);
fprintf('│ 波前 RMS:          %8.4f waves       │\n', analysis.wavefront.rms);
fprintf('│ Seidel S1(球差):   %8.4f             │\n', analysis.seidel.S1);
fprintf('│ Seidel S2(彗差):   %8.4f             │\n', analysis.seidel.S2);
fprintf('└────────────────────────────────────────┘\n\n');

fprintf('  → 在 Zemax 中打开 Analyze → Spot Diagram 对比验证\n\n');
fprintf('按任意键继续到交互式修改...\n');
pause;

%% ========== 第 4 步：★ 交互式修改透镜参数 ==========
fprintf('\n>>> 第 4 步: ★ 交互式修改参数 — 这是核心实操环节!\n');
fprintf('============================================================\n');
fprintf('  现在我们将逐步修改前表面曲率半径，\n');
fprintf('  你可以同时在 Zemax 窗口中观察 Lens Data Editor 和 2D Layout 的变化。\n');
fprintf('============================================================\n\n');

R_values = [60, 80, 100, 120, 150];
rms_record = zeros(size(R_values));

TheLDE = TheSystem.LDE;

for i = 1:length(R_values)
    R = R_values(i);

    % 直接修改 Surface 2 的曲率半径 — Zemax GUI 会实时更新!
    Surf2 = TheLDE.GetSurfaceAt(2);
    Surf2.Radius = R;

    % 重新分析
    analysis_i = analyze_system(TheSystem, cfg);
    rms_record(i) = analysis_i.spot.rms_radius(1) * 1000;   % µm

    fprintf('  R = %3d mm → 轴上 RMS = %6.2f µm | EFL = %7.2f mm\n', ...
        R, rms_record(i), analysis_i.efl);
    fprintf('    → 现在看 Zemax 窗口! 表面数据和光路图都变了\n');

    if i < length(R_values)
        fprintf('    按任意键修改到 R = %d mm...\n', R_values(i+1));
        pause;
    end
end

% 找最优
[bestRMS, bestIdx] = min(rms_record);
bestR = R_values(bestIdx);

fprintf('\n┌─────────── 参数扫描结果 ───────────┐\n');
fprintf('│ 最优曲率半径: R = %d mm            │\n', bestR);
fprintf('│ 最小 RMS:     %.2f µm             │\n', bestRMS);
fprintf('└────────────────────────────────────┘\n');

% 设回最优值
Surf2.Radius = bestR;
fprintf('\n已将曲率设为最优值 R = %d mm\n\n', bestR);

fprintf('按任意键继续到优化...\n');
pause;

%% ========== 第 5 步：运行 DLS 优化 ==========
fprintf('\n>>> 第 5 步: 运行 DLS 优化...\n');
fprintf('  → 在 Zemax 中观察: Tools → Optimization 会显示进度\n\n');

opt = optimize_system(TheSystem, cfg, ...
    'Method', 'DLS', 'Cycles', 30, 'Criterion', 'RMS');

fprintf('\n┌─────────── 优化结果 ───────────┐\n');
fprintf('│ 初始 Merit: %.6f            │\n', opt.merit_initial);
fprintf('│ 最终 Merit: %.6f            │\n', opt.merit_final);
fprintf('│ 改善:       %.2f%%              │\n', opt.improvement);
fprintf('└────────────────────────────────┘\n\n');

%% ========== 第 6 步：优化后对比分析 ==========
fprintf('>>> 第 6 步: 优化后分析...\n');

analysis_after = analyze_system(TheSystem, cfg);

fprintf('\n┌─────────── 优化前 vs 优化后 ───────────┐\n');
fprintf('│                   优化前      优化后     │\n');
fprintf('│ 轴上 RMS (µm):  %8.2f   %8.2f     │\n', ...
    rms_record(bestIdx), analysis_after.spot.rms_radius(1)*1000);
fprintf('│ 波前 RMS (waves): %7.4f   %8.4f     │\n', ...
    analysis.wavefront.rms, analysis_after.wavefront.rms);
fprintf('│ EFL (mm):       %8.2f   %8.2f     │\n', ...
    analysis.efl, analysis_after.efl);
fprintf('└────────────────────────────────────────┘\n\n');

fprintf('  → 在 Zemax 中对比:\n');
fprintf('    - 打开 Analyze → Spot Diagram 查看点列图变化\n');
fprintf('    - 打开 Analyze → FFT MTF 查看 MTF 曲线\n');
fprintf('    - 打开 Analyze → Wavefront Map 查看波前\n\n');

fprintf('按任意键继续到读取 Zemax 数据...\n');
pause;

%% ========== 第 7 步：★ 从 Zemax 读取手动修改 ==========
fprintf('\n>>> 第 7 步: ★ 从 Zemax 读取你的手动修改\n');
fprintf('============================================================\n');
fprintf('  现在请在 Zemax OpticStudio 中:\n');
fprintf('    1. 在 Lens Data Editor 中手动修改任意参数\n');
fprintf('       例如: 修改 Surface 2 的 Radius 为 75\n');
fprintf('             或修改 Surface 2 的 Thickness 为 8\n');
fprintf('    2. 修改完成后，回到 MATLAB 按任意键\n');
fprintf('============================================================\n');
pause;

% 读取 Zemax 中的当前状态
fprintf('\n  正在从 Zemax 读取最新数据...\n');
Surf2_now = TheLDE.GetSurfaceAt(2);
R_now = Surf2_now.Radius;
t_now = Surf2_now.Thickness;
mat_now = char(Surf2_now.Material);

fprintf('  Zemax 当前参数:\n');
fprintf('    Surface 2 曲率半径: %.2f mm\n', R_now);
fprintf('    Surface 2 厚度:     %.2f mm\n', t_now);
fprintf('    Surface 2 材料:     %s\n', mat_now);

% 重新分析
fprintf('\n  使用 Zemax 当前参数重新分析...\n');
analysis_manual = analyze_system(TheSystem, cfg);
fprintf('  手动修改后 RMS: %.2f µm, EFL: %.2f mm\n\n', ...
    analysis_manual.spot.rms_radius(1)*1000, analysis_manual.efl);

%% ========== 第 8 步：保存结果 & 可视化 ==========
fprintf('>>> 第 8 步: 生成图表和保存结果...\n');

cfg.output_dir = fullfile(projectRoot, 'results_interactive');

ray_results = run_raytrace(TheSystem, cfg);
plot_results(analysis_after, ray_results, cfg);
plot_layout(TheSystem, cfg);
save_results(analysis_after, opt, ray_results, cfg);

fprintf('\n✓ 结果已保存到: %s\n', cfg.output_dir);
fprintf('  - spot_diagram.png\n');
fprintf('  - mtf.png\n');
fprintf('  - ray_distribution.png\n');
fprintf('  - system_layout.png\n');
fprintf('  - data.mat\n');
fprintf('  - summary.txt\n\n');

%% ========== 第 9 步：断开连接 ==========
fprintf('>>> 第 9 步: 断开连接...\n');
fprintf('  断开后 Zemax 将恢复为正常 GUI 模式，你可以继续手动操作。\n\n');

disconnect_zemax(TheApplication, cfg);

fprintf('============================================================\n');
fprintf('  ★ 交互式实操完成!\n');
fprintf('============================================================\n');
fprintf('\n');
fprintf('  你已经学会了:\n');
fprintf('  ✓ 通过 Interactive Extension 连接 MATLAB 和 Zemax\n');
fprintf('  ✓ 在 MATLAB 中构建光学系统，Zemax 实时显示\n');
fprintf('  ✓ 在 MATLAB 中修改参数，观察 Zemax 变化\n');
fprintf('  ✓ 在 Zemax 中手动修改，MATLAB 读取结果\n');
fprintf('  ✓ 使用 MATLAB 执行优化并分析结果\n');
fprintf('  ✓ 双向协作：MATLAB 计算 + Zemax 可视化\n');
fprintf('\n');
fprintf('  下一步建议:\n');
fprintf('  - 修改 cfg.lens 参数尝试不同透镜设计\n');
fprintf('  - 运行 example_custom_lens.m 尝试不同玻璃材料\n');
fprintf('  - 运行 example_parameter_sweep.m 做系统化扫描\n');
fprintf('============================================================\n');
