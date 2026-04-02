%% ==========================================================================
% rotation_shift_absolute_test.m
%
% 旋转平移法绝对检测完整算法（平面/球面通用版）
%
% 测量方案：
%   M1 = A + ShiftX(B)          — X方向平移
%   M2 = A + Rot(B, 0°)         — 0° 旋转
%   M3 = A + Rot(B, 90°)        — 90° 旋转
%   M4 = A + Rot(B, 180°)       — 180° 旋转
%   M5 = A + Rot(B, 270°)       — 270° 旋转
%
% 算法结构：
%   外层：搜索/优化 旋转中心(cx,cy)、各角度误差(dθ_k)、平移误差(δx_k,δy_k)
%   内层：对每组几何参数做像素级稀疏线性最小二乘恢复 A 和 B
%
% 适用场景：
%   - 平面镜检测（plane = true）
%   - 球面镜检测（plane = false，配合低阶 Zernike 约束/参数化）
%
% 依赖：MATLAB Image Processing Toolbox（imrotate, imwarp, affine2d）
% ==========================================================================

clear; clc; close all;

%% ==========================================================================
% 0. 用户参数设置
% ==========================================================================
SURFACE_TYPE = 'plane';   % 'plane' 或 'sphere'
                           % 平面：直接像素级恢复
                           % 球面：先用 Zernike 参数化 + 低阶项约束

% --- 图像尺寸 ---
m = 128;   % 行数（像素）
n = 128;   % 列数（像素）

% --- 圆形孔径半径（像素） ---
aperture_radius = 55;

% --- X方向平移量（像素，整数）---
shiftX = 8;

% --- 真实几何误差（仿真中"制造"的误差，用于验证算法能否找回来）---
% 旋转中心偏移（像素，相对图像理想中心）
true_dcx =  1.5;
true_dcy = -2.0;

% 各角度的真实角度偏差（度）
true_dtheta0   =  0.00;
true_dtheta90  =  0.10;
true_dtheta180 = -0.08;
true_dtheta270 =  0.12;

% 各测量的额外平移误差（像素，针对旋转测量M2~M5）
true_dtx = [0.0,  0.3, -0.2,  0.1];   % M2~M5 的 x 平移误差
true_dty = [0.0, -0.1,  0.2, -0.3];   % M2~M5 的 y 平移误差

% --- 加性高斯噪声标准差（灰度/nm 量纲与面形一致）---
noise_sigma = 0.005;

% --- 优化搜索范围 ---
cx_search_range   = 4;     % 旋转中心搜索半径（像素）
cx_search_step    = 0.5;   % 搜索步长（像素）
theta_search_range = 0.3;  % 角度误差搜索范围（度）
theta_search_step  = 0.05; % 角度搜索步长（度）
tx_search_range   = 0.5;   % 平移搜索范围（像素），初始设小，后续精化
tx_search_step    = 0.25;

% 是否执行二阶段精化（先粗搜后精化，推荐开启）
DO_REFINE = true;

% 球面模式下：Zernike 项数（用于参数化 A 和 B 的低阶成分）
N_ZERNIKE = 15;   % 使用前 N_ZERNIKE 项 Zernike 多项式（按 Noll 排列）

% ==========================================================================
% 1. 构造坐标与掩模
% ==========================================================================
[X, Y] = meshgrid(1:n, 1:m);
cx0 = (n + 1) / 2;   % 理想图像中心 x
cy0 = (m + 1) / 2;   % 理想图像中心 y

% 归一化半径（用于 Zernike 计算，单位圆）
R_abs = sqrt((X - cx0).^2 + (Y - cy0).^2);
mask  = R_abs <= aperture_radius;           % 逻辑掩模
r_norm = R_abs / aperture_radius;           % 归一化半径 [0,1]
theta_coord = atan2(Y - cy0, X - cx0);     % 极角（弧度）

Npix = sum(mask(:));   % 孔径内像素数

fprintf('图像尺寸: %d x %d，孔径内像素数: %d\n', m, n, Npix);

% ==========================================================================
% 2. 生成真实面形 A 和 B
% ==========================================================================
rng(42);   % 固定随机数种子，便于复现

if strcmp(SURFACE_TYPE, 'plane')
    % 平面：用随机低中高频叠加生成面形
    A_true = generate_random_surface(m, n, mask, r_norm, theta_coord, 'plane');
    B_true = generate_random_surface(m, n, mask, r_norm, theta_coord, 'plane');
else
    % 球面：用 Zernike 展开生成面形（含离焦、像散等主要项）
    A_true = generate_random_surface(m, n, mask, r_norm, theta_coord, 'sphere');
    B_true = generate_random_surface(m, n, mask, r_norm, theta_coord, 'sphere');
end

% 归一化使 RMS ≈ 1（方便检查误差比例）
rms_A = rms_mask(A_true, mask);
rms_B = rms_mask(B_true, mask);
A_true = A_true / rms_A;
B_true = B_true / rms_B;

fprintf('真实面形 RMS: A = %.4f, B = %.4f\n', rms_mask(A_true, mask), rms_mask(B_true, mask));

% ==========================================================================
% 3. 合法性检查
% ==========================================================================
if shiftX < 0 || shiftX >= n
    error('shiftX 必须满足 0 <= shiftX < n，当前 shiftX = %d', shiftX);
end

% ==========================================================================
% 4. 构造 B 的几何变换（含真实误差）
% ==========================================================================
true_cx = cx0 + true_dcx;
true_cy = cy0 + true_dcy;

% --- X方向平移（整数像素，非循环）---
B_shiftX = zeros(m, n);
if shiftX > 0
    B_shiftX(:, 1 + shiftX : end) = B_true(:, 1 : end - shiftX);
else
    B_shiftX = B_true;
end
B_shiftX = B_shiftX .* mask;

% --- 四个旋转（绕真实中心，含角度误差和平移误差）---
angles_true = [  0 + true_dtheta0, ...
                90 + true_dtheta90, ...
               180 + true_dtheta180, ...
               270 + true_dtheta270];

B_rot = cell(4, 1);
for k = 1:4
    B_rot{k} = warp_rotate_translate( ...
        B_true, angles_true(k), ...
        true_cx, true_cy, ...
        true_dtx(k), true_dty(k), ...
        m, n) .* mask;
end

% ==========================================================================
% 5. 构造测量数据（加噪声）
% ==========================================================================
M1 = (A_true + B_shiftX)   .* mask + noise_sigma * randn(m, n) .* mask;
M2 = (A_true + B_rot{1})   .* mask + noise_sigma * randn(m, n) .* mask;
M3 = (A_true + B_rot{2})   .* mask + noise_sigma * randn(m, n) .* mask;
M4 = (A_true + B_rot{3})   .* mask + noise_sigma * randn(m, n) .* mask;
M5 = (A_true + B_rot{4})   .* mask + noise_sigma * randn(m, n) .* mask;

fprintf('\n--- 仿真测量生成完成 ---\n');
fprintf('真实旋转中心偏移: dcx = %.3f px, dcy = %.3f px\n', true_dcx, true_dcy);
fprintf('真实角度误差: dθ90 = %.3f°, dθ180 = %.3f°, dθ270 = %.3f°\n', ...
    true_dtheta90, true_dtheta180, true_dtheta270);

% ==========================================================================
% 6. 球面模式：构造 Zernike 基底
% ==========================================================================
if strcmp(SURFACE_TYPE, 'sphere')
    Z_basis = build_zernike_basis(r_norm, theta_coord, mask, N_ZERNIKE);
    fprintf('球面模式：使用 %d 项 Zernike 基底参数化面形\n', N_ZERNIKE);
end

% ==========================================================================
% 7. 优化：搜索最优几何参数 (cx, cy, dθ_k, δx_k, δy_k)
% ==========================================================================
fprintf('\n========== 开始外层几何参数优化 ==========\n');

% --- 搜索网格（粗搜）---
cx_vals = cx0 + (-cx_search_range : cx_search_step : cx_search_range);
cy_vals = cy0 + (-cx_search_range : cx_search_step : cx_search_range);
dtheta_vals = -theta_search_range : theta_search_step : theta_search_range;

best_cost = inf;
best_params = struct('cx', cx0, 'cy', cy0, ...
    'dtheta', [0, 0, 0, 0], ...
    'dtx', [0, 0, 0, 0], 'dty', [0, 0, 0, 0]);
best_x = [];

fprintf('搜索网格大小: cx×cy = %d×%d, dθ = %d 点/角度\n', ...
    numel(cx_vals), numel(cy_vals), numel(dtheta_vals));
fprintf('（首先固定平移误差为零做粗搜）\n\n');

total_iters = numel(cx_vals) * numel(cy_vals);
iter_count = 0;

for icx = 1:numel(cx_vals)
    for icy = 1:numel(cy_vals)
        iter_count = iter_count + 1;
        cx_try = cx_vals(icx);
        cy_try = cy_vals(icy);

        % 对当前(cx,cy)，用理想角度做内层恢复，得到基础代价
        params_try = struct('cx', cx_try, 'cy', cy_try, ...
            'dtheta', [0, 0, 0, 0], ...
            'dtx',    [0, 0, 0, 0], ...
            'dty',    [0, 0, 0, 0]);

        [cost_try, x_try] = inner_reconstruct( ...
            M1, M2, M3, M4, M5, ...
            mask, m, n, ...
            shiftX, params_try, SURFACE_TYPE, ...
            [], N_ZERNIKE);

        if cost_try < best_cost
            best_cost  = cost_try;
            best_params = params_try;
            best_x = x_try;
        end
    end
    if mod(iter_count, max(1, floor(total_iters/10))) == 0
        fprintf('  粗搜进度: %d/%d (当前最优 cost = %.6f)\n', ...
            iter_count, total_iters, best_cost);
    end
end

fprintf('\n粗搜完成：最优中心 cx = %.3f, cy = %.3f, cost = %.6f\n', ...
    best_params.cx, best_params.cy, best_cost);

% --- 若开启精化：在最优邻域做更细的搜索（含角度和平移）---
if DO_REFINE
    fprintf('\n========== 开始精化搜索（含角度/平移误差）==========\n');

    refine_range_c = cx_search_step;
    refine_step_c  = cx_search_step / 4;
    cx_fine = best_params.cx + (-refine_range_c : refine_step_c : refine_range_c);
    cy_fine = best_params.cy + (-refine_range_c : refine_step_c : refine_range_c);

    % 精化角度：只搜 dtheta90/180/270（dtheta0 对 B_rot{1} 影响极小，固定为0）
    dtheta_fine = -theta_search_range : theta_search_step/2 : theta_search_range;

    total_fine = numel(cx_fine) * numel(cy_fine) * numel(dtheta_fine)^3;
    fprintf('精化搜索规模（角度轴，中心轴）: 约 %d 次内层求解\n', total_fine);

    if total_fine > 50000
        fprintf('  警告: 精化搜索量较大，改用 fminsearch 局部优化...\n');
        % 用 fminsearch 替代网格搜索
        p0 = [best_params.cx, best_params.cy, 0, 0, 0, ...
              0, 0, 0, 0, 0, 0, 0, 0];
        opt = optimset('TolX', 0.01, 'TolFun', 1e-6, 'MaxIter', 500, 'Display', 'off');
        popt = fminsearch(@(p) cost_func(p, M1, M2, M3, M4, M5, ...
            mask, m, n, shiftX, SURFACE_TYPE, N_ZERNIKE), p0, opt);
        params_refined = unpack_params(popt);
        [cost_refined, x_refined] = inner_reconstruct( ...
            M1, M2, M3, M4, M5, mask, m, n, ...
            shiftX, params_refined, SURFACE_TYPE, [], N_ZERNIKE);
        if cost_refined < best_cost
            best_cost   = cost_refined;
            best_params = params_refined;
            best_x      = x_refined;
        end
    else
        for icx = 1:numel(cx_fine)
          for icy = 1:numel(cy_fine)
            for idt90 = 1:numel(dtheta_fine)
              for idt180 = 1:numel(dtheta_fine)
                for idt270 = 1:numel(dtheta_fine)
                    params_try = struct(...
                        'cx', cx_fine(icx), ...
                        'cy', cy_fine(icy), ...
                        'dtheta', [0, dtheta_fine(idt90), ...
                                      dtheta_fine(idt180), ...
                                      dtheta_fine(idt270)], ...
                        'dtx',    [0, 0, 0, 0], ...
                        'dty',    [0, 0, 0, 0]);

                    [cost_try, x_try] = inner_reconstruct( ...
                        M1, M2, M3, M4, M5, mask, m, n, ...
                        shiftX, params_try, SURFACE_TYPE, [], N_ZERNIKE);

                    if cost_try < best_cost
                        best_cost   = cost_try;
                        best_params = params_try;
                        best_x      = x_try;
                    end
                end
              end
            end
          end
        end
    end

    fprintf('精化完成：cx = %.3f, cy = %.3f\n', best_params.cx, best_params.cy);
    fprintf('           dθ90 = %.4f°, dθ180 = %.4f°, dθ270 = %.4f°\n', ...
        best_params.dtheta(2), best_params.dtheta(3), best_params.dtheta(4));
    fprintf('           cost = %.6f\n', best_cost);
end

% ==========================================================================
% 8. 用最优参数做最终恢复
% ==========================================================================
fprintf('\n========== 最终恢复 ==========\n');

[~, x_final] = inner_reconstruct( ...
    M1, M2, M3, M4, M5, mask, m, n, ...
    shiftX, best_params, SURFACE_TYPE, [], N_ZERNIKE);

% 解包 A_rec 和 B_rec
A_rec = zeros(m, n);
B_rec = zeros(m, n);
A_rec(mask) = x_final(1:Npix);
B_rec(mask) = x_final(Npix+1:end);

% ==========================================================================
% 9. 误差分析
% ==========================================================================
err_A = A_true - A_rec;
err_B = B_true - B_rec;

% 去掉 piston（绝对偏置不可分离，是算法固有限制）
mean_A_err = mean(err_A(mask));
mean_B_err = mean(err_B(mask));
err_A(mask) = err_A(mask) - mean_A_err;
err_B(mask) = err_B(mask) - mean_B_err;

rms_err_A = rms_mask(err_A, mask);
rms_err_B = rms_mask(err_B, mask);
rms_A_true = rms_mask(A_true, mask);
rms_B_true = rms_mask(B_true, mask);

fprintf('恢复误差（去 piston 后）:\n');
fprintf('  A: RMS误差 = %.6f，相对误差 = %.2f%%\n', rms_err_A, 100*rms_err_A/rms_A_true);
fprintf('  B: RMS误差 = %.6f，相对误差 = %.2f%%\n', rms_err_B, 100*rms_err_B/rms_B_true);

fprintf('\n估计的几何参数 vs 真实值:\n');
fprintf('  旋转中心: 估计 (%.3f, %.3f)，真实 (%.3f, %.3f)，误差 (%.3f, %.3f) px\n', ...
    best_params.cx, best_params.cy, true_cx, true_cy, ...
    best_params.cx - true_cx, best_params.cy - true_cy);
fprintf('  dθ90:  估计 %.4f°，真实 %.4f°\n', best_params.dtheta(2), true_dtheta90);
fprintf('  dθ180: 估计 %.4f°，真实 %.4f°\n', best_params.dtheta(3), true_dtheta180);
fprintf('  dθ270: 估计 %.4f°，真实 %.4f°\n', best_params.dtheta(4), true_dtheta270);

% ==========================================================================
% 10. 可视化
% ==========================================================================
visualize_results(A_true, B_true, A_rec, B_rec, err_A, err_B, mask, m, n, SURFACE_TYPE);

% 角度误差敏感性曲线（仅在最优中心下做快速扫描，不含平移误差）
fprintf('\n========== 角度误差敏感性扫描 ==========\n');
delta_scan = [0, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1.0];
errA_scan  = zeros(size(delta_scan));
errB_scan  = zeros(size(delta_scan));

for kk = 1:numel(delta_scan)
    delt = delta_scan(kk);
    params_scan = struct('cx', cx0, 'cy', cy0, ...
        'dtheta', [0, delt, delt, delt], ...
        'dtx',    [0, 0, 0, 0], ...
        'dty',    [0, 0, 0, 0]);

    % 生成含此角度误差的测量数据（恢复时按理想角度）
    B_r90_scan  = warp_rotate_translate(B_true, 90+delt,  cx0, cy0, 0, 0, m, n) .* mask;
    B_r180_scan = warp_rotate_translate(B_true, 180+delt, cx0, cy0, 0, 0, m, n) .* mask;
    B_r270_scan = warp_rotate_translate(B_true, 270+delt, cx0, cy0, 0, 0, m, n) .* mask;

    M3s = (A_true + B_r90_scan)  .* mask;
    M4s = (A_true + B_r180_scan) .* mask;
    M5s = (A_true + B_r270_scan) .* mask;

    % 恢复时用理想模型
    params_ideal = struct('cx', cx0, 'cy', cy0, ...
        'dtheta', [0, 0, 0, 0], 'dtx', [0,0,0,0], 'dty', [0,0,0,0]);
    [~, x_scan] = inner_reconstruct( ...
        M1, M2, M3s, M4s, M5s, mask, m, n, ...
        shiftX, params_ideal, SURFACE_TYPE, [], N_ZERNIKE);

    A_sc = zeros(m,n);  B_sc = zeros(m,n);
    A_sc(mask) = x_scan(1:Npix);
    B_sc(mask) = x_scan(Npix+1:end);

    eA = A_true - A_sc;  eB = B_true - B_sc;
    eA(mask) = eA(mask) - mean(eA(mask));
    eB(mask) = eB(mask) - mean(eB(mask));
    errA_scan(kk) = rms_mask(eA, mask);
    errB_scan(kk) = rms_mask(eB, mask);
end

figure('Name','角度误差敏感性', 'NumberTitle','off');
semilogx(delta_scan, errA_scan, '-o', 'LineWidth', 1.8, 'DisplayName', 'A恢复误差'); hold on;
semilogx(delta_scan, errB_scan, '-s', 'LineWidth', 1.8, 'DisplayName', 'B恢复误差');
grid on; xlabel('旋转角误差 (°)'); ylabel('恢复 RMS 误差');
legend('Location', 'best'); title('角度误差敏感性曲线（理想中心，恢复用理想角度）');

fprintf('角度误差敏感性扫描完成。\n');
fprintf('========== 全部完成 ==========\n');

%% ==========================================================================
%  局部函数定义
% ==========================================================================

% --------------------------------------------------------------------------
function cost = cost_func(p, M1, M2, M3, M4, M5, mask, m, n, ...
    shiftX, SURFACE_TYPE, N_ZERNIKE)
% 供 fminsearch 调用的代价函数，p 是打包的参数向量
params = unpack_params(p);
cost = inner_reconstruct(M1, M2, M3, M4, M5, mask, m, n, ...
    shiftX, params, SURFACE_TYPE, [], N_ZERNIKE);
end

% --------------------------------------------------------------------------
function params = unpack_params(p)
% p = [cx, cy, dtheta90, dtheta180, dtheta270,
%       dtx2, dtx3, dtx4, dty2, dty3, dty4, (unused), (unused)]
params.cx  = p(1);
params.cy  = p(2);
params.dtheta = [0, p(3), p(4), p(5)];
params.dtx    = [0, p(6), p(7), p(8)];
params.dty    = [0, p(9), p(10), p(11)];
end

% --------------------------------------------------------------------------
function [cost, x] = inner_reconstruct(M1, M2, M3, M4, M5, ...
    mask, m, n, shiftX, params, SURFACE_TYPE, Z_basis, N_ZERNIKE)
%INNER_RECONSTRUCT  给定几何参数，构造观测矩阵 H，用 lsqr 恢复 A 和 B。
%
%  返回：
%    cost  — 残差 RMS（越小越优）
%    x     — [A(mask); B(mask)] 向量

Npix = sum(mask(:));

% 构造各几何变换后的 B
cx = params.cx;  cy = params.cy;
dtheta  = params.dtheta;
dtx_arr = params.dtx;
dty_arr = params.dty;

angles = [  0 + dtheta(1), ...
           90 + dtheta(2), ...
          180 + dtheta(3), ...
          270 + dtheta(4)];

% ---------- 构造变换矩阵（像素级稀疏）----------
% 对 ShiftX 使用精确索引映射（无插值），对旋转使用 imrotate 插值映射

% 变换 1：X 方向平移
T_shift = build_shift_matrix(mask, m, n, shiftX, Npix);

% 变换 2~5：旋转（含中心偏移、角度误差、平移误差）
T_rot = cell(4, 1);
for k = 1:4
    T_rot{k} = build_rotation_matrix(mask, m, n, ...
        angles(k), cx, cy, dtx_arr(k), dty_arr(k), Npix);
end

% ---------- 组装观测矩阵 H ----------
% 每个测量方程 Mk(mask) = IA * a + Tk * b，其中 IA = 单位算子（提取孔径内）
IA = speye(Npix);

% M1: a + T_shift * b
H1 = [IA, T_shift];

% M2~M5: a + T_rot{k} * b
H2 = [IA, T_rot{1}];
H3 = [IA, T_rot{2}];
H4 = [IA, T_rot{3}];
H5 = [IA, T_rot{4}];

H = [H1; H2; H3; H4; H5];

% 组装观测向量 Y
y1 = M1(mask);
y2 = M2(mask);
y3 = M3(mask);
y4 = M4(mask);
y5 = M5(mask);
Y  = [y1; y2; y3; y4; y5];

% ---------- 线性最小二乘求解 ----------
if strcmp(SURFACE_TYPE, 'plane')
    % 平面：直接像素级 lsqr
    [x, flag] = lsqr(H, Y, 1e-8, 500);
    if flag ~= 0 && flag ~= 3
        % flag==3 表示达到 maxit 仍未收敛，作为警告但继续
    end
else
    % 球面：用 Zernike 参数化（降维）
    % 若 Z_basis 未传入，则临时重建
    if isempty(Z_basis)
        [X2, Y2] = meshgrid(1:n, 1:m);
        cx0_local = (n+1)/2;  cy0_local = (m+1)/2;
        aperture_r = max(sqrt((X2(:)-cx0_local).^2 + (Y2(:)-cy0_local).^2) .* mask(:));
        r_n = sqrt((X2-cx0_local).^2+(Y2-cy0_local).^2)/aperture_r;
        th  = atan2(Y2-cy0_local, X2-cx0_local);
        Z_basis = build_zernike_basis(r_n, th, mask, N_ZERNIKE);
    end
    % Z_basis: Npix x N_ZERNIKE
    % A(mask) = Z_basis * c_A, B(mask) = Z_basis * c_B
    % 构造降维观测矩阵（A 和 B 各自用 Zernike 展开）
    ZZ = sparse(Z_basis);
    ZZ0 = sparse(Npix, N_ZERNIKE);
    H_AB = [ZZ, ZZ0; ZZ0, ZZ];  % 2*Npix x 2*N_ZERNIKE
    H_full = H * H_AB;
    [c_vec, flag] = lsqr(H_full, Y, 1e-8, 500);
    c_A = c_vec(1:N_ZERNIKE);
    c_B = c_vec(N_ZERNIKE+1:end);
    x_A = Z_basis * c_A;
    x_B = Z_basis * c_B;
    x   = [x_A; x_B];
end

% ---------- 计算残差 cost ----------
residuals = Y - H * x;
cost = sqrt(mean(residuals.^2));
end

% --------------------------------------------------------------------------
function T = build_shift_matrix(mask, m, n, shiftX, Npix)
%BUILD_SHIFT_MATRIX  构造 X 方向平移的稀疏变换矩阵 T（Npix x Npix）。
%  B_shifted(mask) = T * B(mask)
%  仅处理孔径内的像素，使用精确整数像素映射。

% 把 mask 内的线性索引列出来
mask_idx = find(mask);            % Npix x 1，掩模内线性索引
[row_src, col_src] = ind2sub([m, n], mask_idx);   % 对应(行,列)

% 平移后的列坐标
col_dst = col_src - shiftX;      % X正向平移：源列 - shiftX

% 有效的：平移后仍在图像内且在 mask 内
valid = col_dst >= 1;            % 不越界

% 构建稀疏矩阵
% 目标索引（掩模内顺序编号）
idx_dst = (1:Npix)';             % 目标像素在 Y 向量中的行

% 找每个目标像素对应的源像素在掩模内的编号
row_full = row_src;
col_full = col_dst;
lin_src  = sub2ind([m, n], row_full(valid), col_full(valid));

% 查找 lin_src 是否在 mask 内，并获取其在 mask_idx 中的位置
[found, src_ord] = ismember(lin_src, mask_idx);

% 仅保留在掩模内的有效映射
dst_valid_local = find(valid);          % valid 中 true 的局部编号
dst_rows = idx_dst(dst_valid_local(found));
src_cols = src_ord(found);

T = sparse(dst_rows, src_cols, 1, Npix, Npix);
end

% --------------------------------------------------------------------------
function T = build_rotation_matrix(mask, m, n, angle_deg, cx, cy, dtx, dty, Npix)
%BUILD_ROTATION_MATRIX  构造绕任意中心旋转 + 平移的稀疏插值变换矩阵。
%  B_rot(mask) ≈ T * B(mask)
%
%  实现思路：
%    对每个目标像素 (r,c)（掩模内），通过反向映射求出其对应的源坐标，
%    再用双线性插值系数分解为4个相邻源像素的加权和，
%    只保留4个相邻像素中落在掩模内的那些。

mask_idx  = find(mask);
[row_all, col_all] = ind2sub([m, n], mask_idx);   % Npix x 1

% 目标坐标（相对旋转中心，补偿平移误差）
xd = col_all - cx - dtx;
yd = row_all - cy - dty;

% 反向旋转角（从目标找源）
ang_rad = -angle_deg * pi / 180;
cos_a   = cos(ang_rad);
sin_a   = sin(ang_rad);

xs = cos_a .* xd - sin_a .* yd + cx;  % 源列（连续）
ys = sin_a .* xd + cos_a .* yd + cy;  % 源行（连续）

% 双线性插值：将连续坐标分解为整数格点
x0 = floor(xs);  x1 = x0 + 1;
y0 = floor(ys);  y1 = y0 + 1;
wx = xs - x0;    wy = ys - y0;

% 权重
w00 = (1-wx) .* (1-wy);
w10 =    wx  .* (1-wy);
w01 = (1-wx) .*    wy;
w11 =    wx  .*    wy;

% 构造稀疏矩阵（目标行 x 源列）
row_vec = [];
col_vec = [];
val_vec = [];

pts = {x0, y0, w00; x1, y0, w10; x0, y1, w01; x1, y1, w11};

for pp = 1:4
    xp = pts{pp,1};
    yp = pts{pp,2};
    wp = pts{pp,3};

    % 检查边界
    in_bounds = xp >= 1 & xp <= n & yp >= 1 & yp <= m;
    lin_src   = zeros(Npix, 1);
    lin_src(in_bounds) = sub2ind([m, n], yp(in_bounds), xp(in_bounds));

    % 检查是否在掩模内
    in_mask = false(Npix, 1);
    in_mask(in_bounds) = mask(lin_src(in_bounds));

    % 获取源像素在 mask_idx 中的编号
    [~, src_col_idx] = ismember(lin_src(in_mask), mask_idx);

    dst_row_idx = find(in_mask);
    valid_src   = src_col_idx > 0;

    row_vec = [row_vec; dst_row_idx(valid_src)];      %#ok<AGROW>
    col_vec = [col_vec; src_col_idx(valid_src)];      %#ok<AGROW>
    val_vec = [val_vec; wp(dst_row_idx(valid_src))]; %#ok<AGROW>
end

T = sparse(row_vec, col_vec, val_vec, Npix, Npix);
end

% --------------------------------------------------------------------------
function surf = generate_random_surface(m, n, mask, r_norm, theta_coord, type)
%GENERATE_RANDOM_SURFACE  生成随机面形（平面或球面风格）。

surf = zeros(m, n);

if strcmp(type, 'plane')
    % 平面：低频基底 + 中频随机 + 轻微高频
    % 低频：用前 15 项 Zernike
    Z_low = build_zernike_basis(r_norm, theta_coord, mask, 15);
    % Zernike 权重（按 Noll 排列）：
    %   j=1  piston               → 0（piston 不可检测）
    %   j=2,3 tilt x/y            → 0.3
    %   j=4,5 defocus/astig       → 0.8  （平面镜低阶成分通常较小）
    %   j=6~9 coma/trefoil        → 0.5
    %   j=10~15 higher order      → 0.3/0.2 （逐渐衰减）
    zernike_weights_plane = [0; 0.3; 0.3; 0.8; 0.8; 0.5; 0.5; 0.5; ...
                             0.3; 0.3; 0.3; 0.2; 0.2; 0.2; 0.2];
    c_low = randn(15, 1) .* zernike_weights_plane;
    surf_low = zeros(m, n);
    surf_low(mask) = Z_low * c_low;
    % 中频：随机相位傅里叶成分（频率范围 2~12，覆盖中频纹理）
    MID_FREQ_MIN = 2;
    MID_FREQ_MAX = 12;
    noise_map = randn(m, n);
    freq_mask = zeros(m, n);
    f = MID_FREQ_MIN : MID_FREQ_MAX;
    for fx = f
        for fy = f
            freq_mask(fx, fy)     = 1;
            freq_mask(end-fx+2, fy)   = 1;
            freq_mask(fx, end-fy+2)   = 1;
            freq_mask(end-fx+2, end-fy+2) = 1;
        end
    end
    surf_mid_f = ifft2(fft2(noise_map) .* fftshift(freq_mask), 'symmetric');
    surf = (surf_low + 0.15 * surf_mid_f) .* mask;
else
    % 球面：主要用 Zernike 展开，包含离焦、像散、彗差、球差
    Z_all = build_zernike_basis(r_norm, theta_coord, mask, 21);
    c_sphere = randn(21, 1);
    % Zernike 权重（按 Noll 排列，球面镜低阶项更显著）：
    %   j=1  piston               → 0（不可检测）
    %   j=2,3 tilt x/y            → 0.5
    %   j=4,5 defocus/astig       → 1.5  （球面镜主要低阶误差）
    %   j=6,7 astig high / coma   → 1.0/0.8
    %   j=8~10 coma/trefoil       → 0.8/0.5
    %   j=11~21 higher order      → 0.5→0.2 逐渐衰减
    zernike_weights_sphere = [0; 0.5; 0.5; 1.5; 1.5; 1.0; 0.8; 0.8; 0.8; 0.5; ...
                              0.5; 0.5; 0.5; 0.3; 0.3; 0.3; 0.3; 0.2; 0.2; 0.2; 0.2];
    c_sphere = c_sphere .* zernike_weights_sphere;
    surf = zeros(m, n);
    surf(mask) = Z_all * c_sphere;
    surf = surf .* mask;
end
end

% --------------------------------------------------------------------------
function Z = build_zernike_basis(r_norm, theta, mask, N)
%BUILD_ZERNIKE_BASIS  生成前 N 项 Zernike 多项式基底（Noll 排列，单位圆）。
%  输入：
%    r_norm    — 归一化半径矩阵（m x n）
%    theta     — 极角矩阵（m x n，弧度）
%    mask      — 孔径掩模（logical m x n）
%    N         — Zernike 项数
%  输出：
%    Z         — Npix x N 矩阵，每列为一项 Zernike 在掩模内像素上的值

Npix = sum(mask(:));
r = r_norm(mask);
t = theta(mask);
Z = zeros(Npix, N);

% Noll 排列前 21 项 [n, m, 正弦/余弦标志]
noll_table = noll_index_table(N);

for j = 1:N
    nn = noll_table(j,1);
    mm = noll_table(j,2);
    sign_flag = noll_table(j,3);  % 1=cos(m*theta), -1=sin(m*theta), 0=rotational

    R = zernike_radial(nn, abs(mm), r);

    if mm == 0
        Z(:,j) = sqrt(nn+1) * R;
    elseif sign_flag >= 0
        Z(:,j) = sqrt(2*(nn+1)) * R .* cos(abs(mm)*t);
    else
        Z(:,j) = sqrt(2*(nn+1)) * R .* sin(abs(mm)*t);
    end
end
end

% --------------------------------------------------------------------------
function R = zernike_radial(n, m, r)
%ZERNIKE_RADIAL  计算 Zernike 多项式的径向部分。
R = zeros(size(r));
for s = 0:(n-m)/2
    coeff = (-1)^s * factorial(n-s) / ...
        (factorial(s) * factorial((n+m)/2-s) * factorial((n-m)/2-s));
    R = R + coeff * r.^(n-2*s);
end
end

% --------------------------------------------------------------------------
function tbl = noll_index_table(N)
%NOLL_INDEX_TABLE  返回 Noll 排列前 N 项的 [n, m, sign] 表。
% sign: +1 = even (cos), -1 = odd (sin), 0 = m==0
tbl = zeros(N, 3);
j = 0;
n = 0;
while j < N
    for m_abs = mod(n,2):2:n
        if m_abs == 0
            j = j + 1;
            if j <= N, tbl(j,:) = [n, 0, 0]; end
        else
            j = j + 1;
            if j <= N, tbl(j,:) = [n, m_abs, 1]; end   % even
            j = j + 1;
            if j <= N, tbl(j,:) = [n, -m_abs, -1]; end % odd
        end
        if j >= N, break; end
    end
    n = n + 1;
end
end

% --------------------------------------------------------------------------
function val = rms_mask(surf, mask)
%RMS_MASK  计算面形在掩模内的 RMS 值。
vals = surf(mask);
val  = sqrt(mean(vals.^2));
end

% --------------------------------------------------------------------------
function B_out = warp_rotate_translate(B_in, angle_deg, cx, cy, dtx, dty, m, n)
%WARP_ROTATE_TRANSLATE  绕任意中心 (cx,cy) 旋转 angle_deg 度，再加平移 (dtx,dty)。
%  使用 imwarp + affine2d 保证正确的仿射变换中心处理。

% 构造仿射变换矩阵（MATLAB 坐标：列对应 x，行对应 y）
ang_rad = angle_deg * pi / 180;
cos_a   = cos(ang_rad);
sin_a   = sin(ang_rad);

% 平移到原点 -> 旋转 -> 平移回来 -> 额外平移
% affine2d 矩阵（3x3，行向量格式：[x, y, 1] * T = [x', y', 1]）
% MATLAB intrinsic 坐标：1-based，列对应 x，行对应 y
T_to_origin  = [1,0,0; 0,1,0; -(cx-1), -(cy-1), 1];  % 平移至旋转中心为原点（0-based 偏移）
T_rotate     = [cos_a, sin_a, 0; -sin_a, cos_a, 0; 0, 0, 1];
T_from_origin = [1,0,0; 0,1,0; (cx-1)+dtx, (cy-1)+dty, 1];
T_total = T_to_origin * T_rotate * T_from_origin;

tform = affine2d(T_total);
ref2d = imref2d([m, n]);
B_out = imwarp(B_in, tform, 'OutputView', ref2d, ...
    'Interp', 'bilinear', 'FillValues', 0);
end

% --------------------------------------------------------------------------
function visualize_results(A_true, B_true, A_rec, B_rec, err_A, err_B, ...
    mask, m, n, SURFACE_TYPE)
%VISUALIZE_RESULTS  显示恢复结果与误差图。

A_disp   = A_true;   A_disp(~mask) = NaN;
B_disp   = B_true;   B_disp(~mask) = NaN;
Ar_disp  = A_rec;    Ar_disp(~mask) = NaN;
Br_disp  = B_rec;    Br_disp(~mask) = NaN;
eA_disp  = err_A;    eA_disp(~mask) = NaN;
eB_disp  = err_B;    eB_disp(~mask) = NaN;

figure('Name', sprintf('恢复结果 (%s)', SURFACE_TYPE), ...
    'NumberTitle', 'off', 'Position', [50, 50, 1200, 700]);

titles = {'真实 A', '恢复 A', 'A 误差', '真实 B', '恢复 B', 'B 误差'};
data   = {A_disp, Ar_disp, eA_disp, B_disp, Br_disp, eB_disp};

for k = 1:6
    subplot(2, 3, k);
    imagesc(data{k});
    axis image off; colorbar;
    title(titles{k}, 'FontSize', 11);
    colormap(gca, 'gray');
end

sgtitle(sprintf('旋转平移法绝对检测恢复结果（%s 面）', SURFACE_TYPE));
end
