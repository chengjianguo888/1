function applyFont(fig, fontName)
    % applyFont  将中文字体应用到图形窗口中所有支持 FontName 属性的组件
    %
    % 用法：
    %   applyFont(fig, getCJKFont())
    %
    % 参数：
    %   fig      - uifigure 或 figure 句柄
    %   fontName - 字体名称字符串（例如 'Microsoft YaHei'）
    %
    % 该函数通过 findall 遍历图形树中的全部子对象，
    % 对所有含 FontName 属性的对象（uilabel、uibutton、uieditfield、
    % uiaxes、uipanel、text、axes 等）均设置相同的字体，
    % 从而确保中文字符在不同平台上均能正常显示。

    if isempty(fontName)
        return;
    end

    % 获取图形内所有对象（含嵌套子对象）
    allObjs = findall(fig);

    for k = 1:numel(allObjs)
        try
            if isprop(allObjs(k), 'FontName')
                allObjs(k).FontName = fontName;
            end
        catch
            % 跳过不支持设置 FontName 的对象
        end
    end
end
