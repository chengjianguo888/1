function launch()
    % launch - 水下机器人控制系统启动入口
    % 运行此函数以启动系统，首先显示登录界面

    % 将当前文件夹加入路径
    thisDir = fileparts(mfilename('fullpath'));
    addpath(thisDir);

    % 启动登录界面
    LoginGUI();
end
