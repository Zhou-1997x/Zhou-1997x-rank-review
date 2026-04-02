function plot_results(analysis, results, cfg)
% PLOT_RESULTS  可视化光学系统分析结果
%
%   plot_results(analysis, results, cfg)
%
%   输入：
%       analysis - analyze_system() 返回的分析结构体
%       results  - run_raytrace() 返回的光线追迹结果
%       cfg      - 配置结构体
%
%   生成三个子图：
%       1. 点列图 (Spot Diagram)
%       2. MTF 曲线
%       3. 光线在像面的分布

    %% 创建输出目录
    if cfg.save_figures && ~exist(cfg.output_dir, 'dir')
        mkdir(cfg.output_dir);
    end

    %% ===== Figure 1: 点列图 =====
    fig1 = figure('Name', 'Spot Diagram', 'NumberTitle', 'off');
    nFields = length(analysis.spot.x);
    colors = lines(nFields);

    for fIdx = 1:nFields
        subplot(1, nFields, fIdx);
        plot(analysis.spot.x{fIdx} * 1000, ...    % 转换为 µm
             analysis.spot.y{fIdx} * 1000, ...
             '.', 'Color', colors(fIdx, :), 'MarkerSize', 2);
        axis equal; grid on;
        xlabel('X (µm)'); ylabel('Y (µm)');
        title(sprintf('Field %d\nRMS=%.1f µm', ...
            fIdx, analysis.spot.rms_radius(fIdx) * 1000));
    end
    sgtitle('Spot Diagram');

    if cfg.save_figures
        saveas(fig1, fullfile(cfg.output_dir, 'spot_diagram.png'));
        if cfg.verbose
            fprintf('[plot_results] 点列图已保存。\n');
        end
    end

    %% ===== Figure 2: MTF =====
    if ~isempty(analysis.mtf.frequency)
        fig2 = figure('Name', 'MTF', 'NumberTitle', 'off');
        hold on;

        for fIdx = 1:length(analysis.mtf.tangential)
            plot(analysis.mtf.frequency, analysis.mtf.tangential{fIdx}, ...
                '-', 'Color', colors(min(fIdx,nFields), :), ...
                'DisplayName', sprintf('Field %d T', fIdx));
            if fIdx <= length(analysis.mtf.sagittal)
                plot(analysis.mtf.frequency, analysis.mtf.sagittal{fIdx}, ...
                    '--', 'Color', colors(min(fIdx,nFields), :), ...
                    'DisplayName', sprintf('Field %d S', fIdx));
            end
        end

        xlabel('Spatial Frequency (cycles/mm)');
        ylabel('Modulation');
        title('FFT MTF');
        legend('Location', 'southwest');
        grid on;
        ylim([0, 1]);
        hold off;

        if cfg.save_figures
            saveas(fig2, fullfile(cfg.output_dir, 'mtf.png'));
            if cfg.verbose
                fprintf('[plot_results] MTF 图已保存。\n');
            end
        end
    end

    %% ===== Figure 3: 光线分布 =====
    if ~isempty(results.ray_data)
        fig3 = figure('Name', 'Ray Distribution', 'NumberTitle', 'off');

        valid = ~isnan(results.ray_data(:, 4));
        scatter(results.ray_data(valid, 4), ...
                results.ray_data(valid, 5), ...
                3, results.ray_data(valid, 1), 'filled');
        axis equal; grid on;
        xlabel('X (mm)'); ylabel('Y (mm)');
        title(sprintf('Ray Distribution on Image Plane\n(%d rays)', ...
            results.n_success));
        colorbar; colormap(lines(nFields));

        if cfg.save_figures
            saveas(fig3, fullfile(cfg.output_dir, 'ray_distribution.png'));
            if cfg.verbose
                fprintf('[plot_results] 光线分布图已保存。\n');
            end
        end
    end

end
