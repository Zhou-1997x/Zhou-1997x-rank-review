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
%       'standalone'   : 无 GUI，启动独立计算引擎
%       'interactive'  : 连接到已打开的 OpticStudio（需开启 Interactive Extension）
%
%   示例：
%       cfg = zemax_config();
%       [app, sys] = connect_zemax(cfg);

    %% 加载 .NET 程序集
    if ~exist(cfg.zosapi_dll, 'file')
        error('connect_zemax:DLLNotFound', ...
            '找不到 ZOSAPI.dll，请检查配置路径：\n  %s', cfg.zosapi_dll);
    end

    NET.addAssembly(cfg.zosapi_interfaces_dll);
    NET.addAssembly(cfg.zosapi_dll);

    import ZOSAPI.*;

    %% 根据模式连接
    switch lower(cfg.connection_mode)
        case 'standalone'
            if cfg.verbose
                fprintf('[connect_zemax] 正在以 Standalone 模式启动 OpticStudio...\n');
            end
            TheApplication = ZOSAPI.ZOSAPI_Connection();
            IsInit = TheApplication.ConnectAsExtension(0);
            if ~IsInit
                % 回退：尝试创建新的 Standalone Application
                TheApplication = ZOSAPI.ZOSAPI_Connection();
                modeFlag = ZOSAPI.SessionMode.Standalone;
                TheApplication.CreateNewApplication(modeFlag);
            end

        case 'interactive'
            if cfg.verbose
                fprintf('[connect_zemax] 正在以 Interactive Extension 模式连接...\n');
            end
            TheApplication = ZOSAPI.ZOSAPI_Connection();
            IsInit = TheApplication.ConnectAsExtension(0);
            if ~IsInit
                error('connect_zemax:ConnectionFailed', ...
                    '无法连接到 OpticStudio Interactive Extension。\n请确认：\n  1) OpticStudio 已打开\n  2) Programming > Interactive Extension 已启用');
            end

        otherwise
            error('connect_zemax:InvalidMode', ...
                '无效的连接模式: "%s"。请使用 "standalone" 或 "interactive"。', ...
                cfg.connection_mode);
    end

    %% 获取主光学系统
    TheSystem = TheApplication.PrimarySystem;

    if cfg.verbose
        fprintf('[connect_zemax] 连接成功。系统名称: %s\n', ...
            char(TheSystem.SystemName));
    end

end
