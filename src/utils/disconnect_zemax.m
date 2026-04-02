function disconnect_zemax(TheApplication, cfg)
% DISCONNECT_ZEMAX  安全断开与 Zemax 的连接
%
%   disconnect_zemax(TheApplication, cfg)
%
%   输入：
%       TheApplication - IZOSAPI_Application 对象
%       cfg            - 配置结构体

    try
        if ~isempty(TheApplication)
            TheApplication.CloseApplication();
            if cfg.verbose
                fprintf('[disconnect_zemax] 已断开 Zemax 连接。\n');
            end
        end
    catch ME
        warning('disconnect_zemax:CloseError', ...
            '断开连接时出错: %s', ME.message);
    end

end
