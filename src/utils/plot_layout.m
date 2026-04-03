function plot_layout(TheSystem, cfg)
% PLOT_LAYOUT  绘制 2D 光学系统布局图
%
%   plot_layout(TheSystem, cfg)
%
%   利用 ZOS-API 提取每个表面的位置与半径信息，
%   在 MATLAB 中绘制简化的 2D 系统截面布局图。
%
%   输入：
%       TheSystem - IOpticalSystem 对象
%       cfg       - 配置结构体

    if cfg.verbose
        fprintf('[plot_layout] 正在绘制系统布局...\n');
    end

    TheLDE = TheSystem.LDE;
    nSurf  = TheLDE.NumberOfSurfaces;

    %% 提取表面数据
    z_pos     = zeros(nSurf, 1);   % 沿光轴位置
    radii     = zeros(nSurf, 1);   % 曲率半径
    semi_dia  = zeros(nSurf, 1);   % 半口径
    thickness = zeros(nSurf, 1);   % 厚度
    materials = cell(nSurf, 1);    % 材料名
    comments  = cell(nSurf, 1);    % 注释

    cumZ = 0;
    for sIdx = 0:(nSurf - 1)
        surf = TheLDE.GetSurfaceAt(sIdx);
        z_pos(sIdx+1)     = cumZ;
        radii(sIdx+1)     = surf.Radius;
        semi_dia(sIdx+1)  = surf.SemiDiameter;
        thickness(sIdx+1) = surf.Thickness;
        materials{sIdx+1} = char(surf.Material);
        comments{sIdx+1}  = char(surf.Comment);
        cumZ = cumZ + surf.Thickness;
    end

    %% 绘制布局
    fig = figure('Name', '2D System Layout', 'NumberTitle', 'off', ...
                 'Position', [100, 100, 900, 400]);
    hold on;

    % 绘制光轴
    plot([z_pos(1)-5, z_pos(end)+5], [0, 0], 'k--', 'LineWidth', 0.5);

    % 绘制每个表面
    for sIdx = 1:nSurf
        sd = semi_dia(sIdx);
        if sd == 0
            sd = cfg.aperture_mm / 2;   % 回退到入瞳半径
        end
        R  = radii(sIdx);
        zc = z_pos(sIdx);

        if isinf(R) || R == 0
            % 平面 → 画直线
            plot([zc, zc], [-sd, sd], 'b-', 'LineWidth', 1.5);
        else
            % 球面 → 画弧
            % 弧的张角 = 2 * asin(semi_dia / R)
            if abs(R) > sd
                theta_max = asin(sd / abs(R));
            else
                theta_max = pi / 4;   % 截断
            end
            theta = linspace(-theta_max, theta_max, 100);
            if R > 0
                y_arc = R * sin(theta);
                z_arc = zc + R - R * cos(theta);
            else
                y_arc = abs(R) * sin(theta);
                z_arc = zc + R + abs(R) * cos(theta);
            end
            plot(z_arc, y_arc, 'b-', 'LineWidth', 1.5);
        end

        % 标注玻璃填充
        if sIdx < nSurf && ~isempty(materials{sIdx}) && ~strcmp(materials{sIdx}, '')
            z_next = z_pos(sIdx) + thickness(sIdx);
            sd_fill = max(semi_dia(sIdx), semi_dia(min(sIdx+1, nSurf)));
            fill([zc, z_next, z_next, zc], ...
                 [-sd_fill, -sd_fill, sd_fill, sd_fill], ...
                 [0.85, 0.92, 1.0], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
            text(mean([zc, z_next]), sd_fill + 1, materials{sIdx}, ...
                 'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.2, 0.2, 0.6]);
        end

        % 表面编号
        text(zc, -sd - 2, sprintf('S%d', sIdx-1), ...
             'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', [0.5, 0.5, 0.5]);
    end

    % 标注光阑
    for sIdx = 1:nSurf
        if contains(lower(comments{sIdx}), 'stop') || ...
           (sIdx == 2 && nSurf > 3)   % 通常 Surface 1 是光阑
            sd = semi_dia(sIdx);
            zc = z_pos(sIdx);
            plot([zc, zc], [sd, sd+3], 'r-', 'LineWidth', 2);
            plot([zc, zc], [-sd, -sd-3], 'r-', 'LineWidth', 2);
            text(zc, sd + 4, 'STOP', 'HorizontalAlignment', 'center', ...
                 'FontSize', 8, 'FontWeight', 'bold', 'Color', 'r');
        end
    end

    hold off;
    xlabel('Z (mm) — 光轴方向');
    ylabel('Y (mm)');
    title('2D Optical System Layout');
    axis equal;
    grid on;
    set(gca, 'FontSize', 10);

    %% 保存
    if cfg.save_figures
        if ~exist(cfg.output_dir, 'dir'), mkdir(cfg.output_dir); end
        saveas(fig, fullfile(cfg.output_dir, 'system_layout.png'));
        if cfg.verbose
            fprintf('[plot_layout] 布局图已保存。\n');
        end
    end

end
