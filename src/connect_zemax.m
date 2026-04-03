function [TheApplication, TheSystem] = connect_zemax(cfg)
% CONNECT_ZEMAX  建立 MATLAB 与 Zemax OpticStudio 的连接
%
%   [TheApplication, TheSystem] = connect_zemax(cfg)
%
%   输入：
%       cfg  - 配置结构体，由 zemax_config() 返回
%
%   输出：
%       TheApplication - IZOSAPI_Application 对象
%       TheSystem      - IOpticalSystem 主系统对象
%
%   支持两种模式：
%       'standalone'   : 无 GUI，启动独立计算引擎（适合批处理）
%       'interactive'  : 连接到已打开的 OpticStudio（实时交互实操）
%
%   Interactive 模式使用前提：
%       1) 打开 Zemax OpticStudio
%       2) 点击 Programming > Interactive Extension
%       3) 在 MATLAB 中运行本函数
%
%   示例：
%       cfg = zemax_config();
%       cfg.connection_mode = 'interactive';  % 切换到交互模式
%       [app, sys] = connect_zemax(cfg);

    %% 获取重试参数
    maxRetry = 3;
    timeoutSec = 60;
    if isfield(cfg, 'connect_retry'),      maxRetry   = cfg.connect_retry;       end
    if isfield(cfg, 'connect_timeout_sec'), timeoutSec = cfg.connect_timeout_sec; end

    %% 加载 .NET 程序集
    if ~exist(cfg.zosapi_dll, 'file')
        error('connect_zemax:DLLNotFound', [...
            '找不到 ZOSAPI.dll:\n  %s\n\n' ...
            '排查步骤:\n' ...
            '  1) 确认 Zemax OpticStudio 已安装\n' ...
            '  2) 修改 config/zemax_config.m 中的 zemax_install_dir\n' ...
            '  3) 确认安装目录下存在 ZOS-API\\Libraries\\ZOSAPI.dll'], ...
            cfg.zosapi_dll);
    end

    if cfg.verbose
        fprintf('[connect_zemax] 加载 ZOS-API 程序集...\n');
    end
    NET.addAssembly(cfg.zosapi_interfaces_dll);
    NET.addAssembly(cfg.zosapi_dll);

    import ZOSAPI.*;

    %% 根据模式连接（带重试）
    TheApplication = [];
    lastError = '';

    switch lower(cfg.connection_mode)
        case 'standalone'
            if cfg.verbose
                fprintf('[connect_zemax] 模式: Standalone（无 GUI）\n');
            end

            for attempt = 1:maxRetry
                try
                    if cfg.verbose && attempt > 1
                        fprintf('[connect_zemax] 第 %d 次重试...\n', attempt);
                    end

                    TheConnection = ZOSAPI.ZOSAPI_Connection();
                    TheApplication = TheConnection.CreateNewApplication();

                    if ~isempty(TheApplication)
                        break;
                    end
                catch ME
                    lastError = ME.message;
                    if attempt < maxRetry
                        pause(2);   % 等待 2 秒后重试
                    end
                end
            end

            if isempty(TheApplication)
                error('connect_zemax:StandaloneFailed', [...
                    'Standalone 模式连接失败 (尝试 %d 次)。\n' ...
                    '最后错误: %s\n\n' ...
                    '排查步骤:\n' ...
                    '  1) 确认 OpticStudio 许可证有效\n' ...
                    '  2) 确认没有其他 OpticStudio 实例正在运行\n' ...
                    '  3) 尝试以管理员身份运行 MATLAB'], ...
                    maxRetry, lastError);
            end

        case 'interactive'
            if cfg.verbose
                fprintf('[connect_zemax] 模式: Interactive Extension（连接到已打开的 OpticStudio）\n');
                fprintf('  ★ 请确保 OpticStudio 已打开并启用了 Interactive Extension\n');
                fprintf('    操作路径: Programming → Interactive Extension\n');
            end

            for attempt = 1:maxRetry
                try
                    if cfg.verbose && attempt > 1
                        fprintf('[connect_zemax] 第 %d 次重试 (等待 OpticStudio 就绪)...\n', attempt);
                    end

                    TheConnection = ZOSAPI.ZOSAPI_Connection();
                    TheApplication = TheConnection.ConnectToApplication();

                    if ~isempty(TheApplication)
                        break;
                    end
                catch ME
                    lastError = ME.message;
                    if attempt < maxRetry
                        if cfg.verbose
                            fprintf('  连接未成功，%d 秒后重试...\n', 3);
                        end
                        pause(3);   % Interactive 模式等待更久
                    end
                end
            end

            if isempty(TheApplication)
                error('connect_zemax:InteractiveFailed', [...
                    'Interactive Extension 连接失败 (尝试 %d 次)。\n' ...
                    '最后错误: %s\n\n' ...
                    '★ 操作步骤 ★\n' ...
                    '  1) 打开 Zemax OpticStudio\n' ...
                    '  2) 点击顶部菜单: Programming → Interactive Extension\n' ...
                    '  3) 等待 OpticStudio 状态栏显示 "Interactive Extension Running"\n' ...
                    '  4) 回到 MATLAB，重新运行本函数\n\n' ...
                    '常见问题:\n' ...
                    '  - 确保没有其他 MATLAB 实例占用连接\n' ...
                    '  - 确保 OpticStudio 许可证支持 ZOS-API'], ...
                    maxRetry, lastError);
            end

        otherwise
            error('connect_zemax:InvalidMode', ...
                '无效的连接模式: "%s"。\n请使用 "standalone" 或 "interactive"。', ...
                cfg.connection_mode);
    end

    %% 获取主光学系统
    TheSystem = TheApplication.PrimarySystem;

    if cfg.verbose
        fprintf('[connect_zemax] ✓ 连接成功!\n');
        fprintf('  系统名称: %s\n', char(TheSystem.SystemName));
        fprintf('  模式: %s\n', cfg.connection_mode);
    end

end
