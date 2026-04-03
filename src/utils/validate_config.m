function [ok, msgs] = validate_config(cfg)
% VALIDATE_CONFIG  校验配置结构体的完整性和合理性
%
%   [ok, msgs] = validate_config(cfg)
%
%   输入：
%       cfg  - 由 zemax_config() 返回的配置结构体
%
%   输出：
%       ok   - 逻辑值，true 表示全部通过
%       msgs - 字符串 cell array，包含所有警告/错误信息
%
%   示例：
%       cfg = zemax_config();
%       [ok, msgs] = validate_config(cfg);
%       if ~ok, cellfun(@warning, msgs); end

    msgs = {};

    %% 必需字段检查
    required = {'zemax_install_dir', 'zosapi_dll', 'zosapi_interfaces_dll', ...
                'connection_mode', 'wavelength_um', 'field_angle_deg', ...
                'aperture_mm', 'num_rings', 'num_arms', ...
                'output_dir', 'save_figures', 'verbose'};

    for i = 1:length(required)
        if ~isfield(cfg, required{i})
            msgs{end+1} = sprintf('缺少必需字段: cfg.%s', required{i}); %#ok<AGROW>
        end
    end

    if ~isempty(msgs)
        ok = false;
        return;
    end

    %% 路径检查
    if ~exist(cfg.zemax_install_dir, 'dir')
        msgs{end+1} = sprintf(['Zemax 安装目录不存在: %s\n' ...
            '  提示: 请修改 config/zemax_config.m 中的 zemax_install_dir'], ...
            cfg.zemax_install_dir);
    end

    if ~exist(cfg.zosapi_dll, 'file')
        msgs{end+1} = sprintf(['ZOSAPI.dll 未找到: %s\n' ...
            '  提示: 请确认 OpticStudio 已正确安装且包含 ZOS-API 组件'], ...
            cfg.zosapi_dll);
    end

    %% 数值范围检查
    if ~isnumeric(cfg.wavelength_um) || cfg.wavelength_um <= 0.01 || cfg.wavelength_um > 100
        msgs{end+1} = sprintf('波长超出合理范围 (0.01~100 µm): %.4f', cfg.wavelength_um);
    end

    if ~isnumeric(cfg.field_angle_deg) || cfg.field_angle_deg < 0 || cfg.field_angle_deg > 90
        msgs{end+1} = sprintf('视场角超出合理范围 (0~90°): %.2f', cfg.field_angle_deg);
    end

    if ~isnumeric(cfg.aperture_mm) || cfg.aperture_mm <= 0
        msgs{end+1} = sprintf('入瞳直径必须为正数: %.2f', cfg.aperture_mm);
    end

    if ~isnumeric(cfg.num_rings) || cfg.num_rings < 1 || mod(cfg.num_rings, 1) ~= 0
        msgs{end+1} = '光线追迹环数 (num_rings) 必须为正整数';
    end

    if ~isnumeric(cfg.num_arms) || cfg.num_arms < 1 || mod(cfg.num_arms, 1) ~= 0
        msgs{end+1} = '光线追迹臂数 (num_arms) 必须为正整数';
    end

    %% 连接模式检查
    valid_modes = {'standalone', 'interactive'};
    if ~ismember(lower(cfg.connection_mode), valid_modes)
        msgs{end+1} = sprintf('无效的连接模式: "%s" (请使用 "standalone" 或 "interactive")', ...
            cfg.connection_mode);
    end

    %% 类型检查
    if ~islogical(cfg.save_figures) && ~isnumeric(cfg.save_figures)
        msgs{end+1} = 'save_figures 必须为逻辑值或 0/1';
    end

    if ~islogical(cfg.verbose) && ~isnumeric(cfg.verbose)
        msgs{end+1} = 'verbose 必须为逻辑值或 0/1';
    end

    %% 汇总
    ok = isempty(msgs);

    if cfg.verbose
        if ok
            fprintf('[validate_config] ✓ 配置校验通过。\n');
        else
            fprintf('[validate_config] ✗ 发现 %d 个问题:\n', length(msgs));
            for i = 1:length(msgs)
                fprintf('  %d. %s\n', i, msgs{i});
            end
        end
    end

end
