function fontName = getCJKFont()
    % getCJKFont  返回当前系统上可用的中文字体名称
    %
    % 按优先级依次尝试各平台的常见中文字体，
    % 若均不可用则回退到 MATLAB 默认字体。
    % 支持：Windows / macOS / Linux

    if ispc
        % Windows 常见中文字体（优先微软雅黑）
        candidates = {
            'Microsoft YaHei', ...   % 微软雅黑（Vista+，最常见）
            'Microsoft YaHei UI', ...
            'SimHei', ...            % 黑体
            'SimSun', ...            % 宋体
            'NSimSun', ...           % 新宋体
            'FangSong', ...          % 仿宋
            'KaiTi'                  % 楷体
        };
    elseif ismac
        % macOS 常见中文字体
        candidates = {
            'PingFang SC', ...       % 苹方-简（macOS 10.11+）
            'Heiti SC', ...          % 黑体-简
            'STHeiti', ...           % 华文黑体
            'Songti SC', ...         % 宋体-简
            'STSong', ...            % 华文宋体
            'STKaiti'                % 华文楷体
        };
    else
        % Linux / 其他系统
        candidates = {
            'Noto Sans CJK SC', ...  % 谷歌思源黑体（最广泛）
            'Noto Sans SC', ...
            'WenQuanYi Zen Hei', ... % 文泉驿正黑
            'WenQuanYi Micro Hei', ...
            'AR PL UMing CN', ...    % 文鼎PL细上海宋
            'Droid Sans Fallback', ...
            'Source Han Sans CN'     % 思源黑体
        };
    end

    % 获取系统已安装字体列表（MATLAB 内置）
    try
        available = listfonts();
    catch
        available = {};
    end

    % 依次检测候选字体是否可用
    for i = 1:numel(candidates)
        if any(strcmpi(available, candidates{i}))
            fontName = candidates{i};
            return;
        end
    end

    % 所有候选均不可用时，使用 MATLAB 默认字体
    try
        fontName = get(groot, 'defaultUicontrolFontName');
    catch
        fontName = '';
    end
    if isempty(fontName)
        fontName = 'Helvetica';
    end
end
