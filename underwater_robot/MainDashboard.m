function MainDashboard(username)
    % MainDashboard - 水下机器人主控制台
    % 包含：导航控制、传感器监控、声纳显示、摄像头、机械臂、任务规划、数据日志

    if nargin < 1, username = 'operator'; end

    % ---- 颜色主题 ----
    C.bg       = [0.04  0.10  0.18];
    C.panel    = [0.06  0.14  0.24];
    C.panelDk  = [0.04  0.10  0.18];
    C.accent   = [0.00  0.60  0.90];
    C.accentDk = [0.00  0.40  0.65];
    C.text     = [0.85  0.95  1.00];
    C.subtext  = [0.50  0.70  0.85];
    C.border   = [0.10  0.28  0.46];
    C.success  = [0.10  0.80  0.50];
    C.warn     = [1.00  0.75  0.10];
    C.error    = [1.00  0.35  0.35];
    C.green    = [0.20  0.85  0.45];

    % ---- 机器人状态 ----
    state = RobotState();
    state.IsConnected = true;

    % ---- 主窗口 ----
    fig = uifigure('Name', '水下机器人控制系统', ...
        'Position',       [20 20 1440 860], ...
        'Color',          C.bg, ...
        'CloseRequestFcn', @onClose);
    movegui(fig, 'center');

    % ============================================================
    %   顶部标题栏
    % ============================================================
    topBar = uipanel(fig, ...
        'Position',       [0 830 1440 30], ...
        'BackgroundColor', C.accentDk, ...
        'BorderType',     'none');

    uilabel(topBar, 'Text', ['▶  水下机器人控制系统  |  操作员: ', username], ...
        'Position',       [10 5 500 20], ...
        'FontSize',       11, 'FontWeight', 'bold', ...
        'FontColor',      [1 1 1], 'BackgroundColor', 'none');

    lblConn = uilabel(topBar, 'Text', '● 已连接', ...
        'Position',       [1200 5 120 20], ...
        'FontSize',       11, ...
        'FontColor',      C.success, 'BackgroundColor', 'none', ...
        'HorizontalAlignment', 'right');

    lblMode = uilabel(topBar, 'Text', '模式: 手动', ...
        'Position',       [1050 5 140 20], ...
        'FontSize',       11, ...
        'FontColor',      C.warn, 'BackgroundColor', 'none', ...
        'HorizontalAlignment', 'right');

    % ============================================================
    %   左侧面板 — 导航控制
    % ============================================================
    panNav = makePanel(fig, [5 460 310 360], C.panel, C.border, '◈  导航控制', C);

    % 方向控制按钮组
    btnSize = [60 30];
    bPos = @(r,c) [80 + (c-1)*70, 355 - r*42, btnSize];

    btnFwd   = makeCtrlBtn(panNav, bPos(1,2), '▲  前进',   C, @() setSpeed(state, 'fwd',  1));
    btnBwd   = makeCtrlBtn(panNav, bPos(3,2), '▼  后退',   C, @() setSpeed(state, 'fwd', -1));
    btnLeft  = makeCtrlBtn(panNav, bPos(2,1), '◄  左转',   C, @() setSpeed(state, 'yaw', -1));
    btnRight = makeCtrlBtn(panNav, bPos(2,3), '右转  ►', C, @() setSpeed(state, 'yaw',  1));
    btnStop  = uibutton(panNav, 'push', 'Text', '■ 停止', ...
        'Position', bPos(2,2), 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', C.error, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) stopMotion(state));

    % 深度控制
    uilabel(panNav, 'Text', '深  度  控  制', ...
        'Position', [10 155 290 18], 'FontSize', 10, ...
        'FontColor', C.subtext, 'HorizontalAlignment', 'center', ...
        'BackgroundColor', 'none');

    btnUp   = makeCtrlBtn(panNav, [80 130 60 26], '↑ 上浮', C, @() setSpeed(state, 'vert', -1));
    btnDown = makeCtrlBtn(panNav, [175 130 60 26], '↓ 下潜', C, @() setSpeed(state, 'vert',  1));

    uilabel(panNav, 'Text', '目标深度 (m)', ...
        'Position', [10 100 130 18], 'FontSize', 10, ...
        'FontColor', C.subtext, 'BackgroundColor', 'none');
    spinDepth = uispinner(panNav, 'Value', 0, 'Limits', [0 300], 'Step', 0.5, ...
        'Position', [145 100 100 24], 'FontSize', 11, ...
        'BackgroundColor', C.panelDk, 'FontColor', C.text, ...
        'ValueChangedFcn', @(s,~) setTargetDepth(state, s.Value));

    % 速度滑块
    uilabel(panNav, 'Text', '推进功率', ...
        'Position', [10 68 100 18], 'FontSize', 10, ...
        'FontColor', C.subtext, 'BackgroundColor', 'none');
    sldPower = uislider(panNav, 'Value', 50, 'Limits', [0 100], ...
        'Position', [110 75 160 3], ...
        'ValueChangedFcn', @(s,~) setPower(state, s.Value));
    lblPower = uilabel(panNav, 'Text', '50 %', ...
        'Position', [275 68 40 18], 'FontSize', 10, ...
        'FontColor', C.text, 'BackgroundColor', 'none');

    % 模式选择
    uilabel(panNav, 'Text', '运行模式', ...
        'Position', [10 35 80 18], 'FontSize', 10, ...
        'FontColor', C.subtext, 'BackgroundColor', 'none');
    ddMode = uidropdown(panNav, ...
        'Items', {'手动', '自动', '悬停'}, ...
        'Value', '手动', ...
        'Position', [100 33 150 24], ...
        'BackgroundColor', C.panelDk, 'FontColor', C.text, ...
        'ValueChangedFcn', @onModeChange);

    % ============================================================
    %   左侧面板 — 传感器数据
    % ============================================================
    panSensor = makePanel(fig, [5 145 310 305], C.panel, C.border, '◈  传感器监控', C);

    [lblDepthVal,  ~] = makeSensorRow(panSensor, 270, '深  度',   '0.00 m',    C);
    [lblPressVal,  ~] = makeSensorRow(panSensor, 238, '水  压',   '1.00 bar',  C);
    [lblTempVal,   ~] = makeSensorRow(panSensor, 206, '水  温',   '15.0 °C',   C);
    [lblSalinVal,  ~] = makeSensorRow(panSensor, 174, '盐  度',   '35.0 PSU',  C);
    [lblO2Val,     ~] = makeSensorRow(panSensor, 142, '溶解氧',   '8.0 mg/L',  C);
    [lblBatVal,    ~] = makeSensorRow(panSensor, 110, '电  量',   '100 %',     C);
    [lblVoltVal,   ~] = makeSensorRow(panSensor,  78, '电  压',   '24.0 V',    C);
    [lblSigVal,    ~] = makeSensorRow(panSensor,  46, '信  号',   '95 %',      C);
    [lblMotTVal,   ~] = makeSensorRow(panSensor,  14, '电机温度', '25.0 °C',   C);

    % ============================================================
    %   左下 — 紧急停止
    % ============================================================
    btnEmg = uibutton(fig, 'push', 'Text', '⛔  紧 急 停 止', ...
        'Position', [5 5 310 130], ...
        'FontSize', 20, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.6 0.05 0.05], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @onEmergencyStop);

    % ============================================================
    %   中央上方 — 声纳显示
    % ============================================================
    panSonar = makePanel(fig, [320 440 420 420], C.panel, C.border, '◈  声纳扫描', C);
    axSonar = uiaxes(panSonar, ...
        'Position', [10 10 400 395], ...
        'Color', [0.02 0.08 0.12], ...
        'XColor', C.border, 'YColor', C.border, ...
        'GridColor', C.border, 'GridAlpha', 0.3, ...
        'XLim', [-25 25], 'YLim', [-25 25], ...
        'DataAspectRatio', [1 1 1]);
    axSonar.Toolbar.Visible = 'off';
    title(axSonar, '', 'Color', C.text);
    xlabel(axSonar, '水平距离 (m)', 'Color', C.subtext, 'FontSize', 9);
    ylabel(axSonar, '垂直距离 (m)', 'Color', C.subtext, 'FontSize', 9);
    grid(axSonar, 'on');
    hold(axSonar, 'on');
    % 距离圈
    theta = linspace(0, 2*pi, 120);
    for r = [5 10 15 20]
        plot(axSonar, r*cos(theta), r*sin(theta), ':', ...
            'Color', [C.border, 0.5], 'LineWidth', 0.8);
    end
    % 扫描线
    hScanLine = plot(axSonar, [0 0], [0 0], 'Color', C.accent, 'LineWidth', 1.5);
    % 回波点
    hEchoScat = scatter(axSonar, [], [], 15, [], 'filled', ...
        'MarkerFaceAlpha', 0.7);
    colormap(axSonar, 'cool');

    % ============================================================
    %   中央下方 — 摄像头视图
    % ============================================================
    panCam = makePanel(fig, [320 5 420 425], C.panel, C.border, '◈  水下摄像头', C);
    axCam = uiaxes(panCam, ...
        'Position', [10 10 400 395], ...
        'Color', [0.02 0.10 0.20], ...
        'XColor', 'none', 'YColor', 'none', ...
        'XLim', [0 100], 'YLim', [0 100]);
    axCam.Toolbar.Visible = 'off';
    disableDefaultInteractivity(axCam);
    hold(axCam, 'on');
    % 初始摄像头帧（占位）
    hCamImg = imagesc(axCam, [0 100], [0 100], generateCameraFrame(state));
    colormap(axCam, 'ocean');
    hCamParticles = plot(axCam, rand(30,1)*100, rand(30,1)*100, 'w.', ...
        'MarkerSize', 3);

    % 摄像头控制
    uilabel(panCam, 'Text', '亮度', ...
        'Position', [10 8 40 18], 'FontSize', 9, ...
        'FontColor', C.subtext, 'BackgroundColor', 'none');
    sldBright = uislider(panCam, 'Value', 70, 'Limits', [0 100], ...
        'Position', [55 14 100 3]);
    uilabel(panCam, 'Text', '对比度', ...
        'Position', [170 8 50 18], 'FontSize', 9, ...
        'FontColor', C.subtext, 'BackgroundColor', 'none');
    sldContrast = uislider(panCam, 'Value', 60, 'Limits', [0 100], ...
        'Position', [225 14 100 3]);
    uibutton(panCam, 'push', 'Text', '截图', ...
        'Position', [335 5 70 24], 'FontSize', 10, ...
        'BackgroundColor', C.accentDk, 'FontColor', C.text, ...
        'ButtonPushedFcn', @onCapture);

    % ============================================================
    %   右上 — 推进器状态
    % ============================================================
    panThrust = makePanel(fig, [745 660 340 200], C.panel, C.border, '◈  推进器状态', C);
    thrNames  = {'前左','前右','后左','后右','垂前','垂后'};
    hThrBars  = gobjects(6, 1);
    hThrLbls  = gobjects(6, 1);
    for i = 1:6
        row = floor((i-1)/3);
        col = mod(i-1, 3);
        x0  = 18 + col * 105;
        y0  = 100 - row * 68;
        uilabel(panThrust, 'Text', thrNames{i}, ...
            'Position', [x0 y0+36 90 16], 'FontSize', 9, ...
            'FontColor', C.subtext, 'HorizontalAlignment', 'center', ...
            'BackgroundColor', 'none');
        hThrBars(i) = uiaxes(panThrust, ...
            'Position', [x0 y0+2 90 32], ...
            'Color', C.panelDk, 'XColor', 'none', 'YColor', 'none', ...
            'XLim', [-100 100], 'YLim', [0 1]);
        hThrBars(i).Toolbar.Visible = 'off';
        hold(hThrBars(i), 'on');
        bar(hThrBars(i), 0, 0.6, 20, 'FaceColor', C.green, 'EdgeColor', 'none');
        hThrLbls(i) = uilabel(panThrust, 'Text', '0 %', ...
            'Position', [x0 y0-8 90 16], 'FontSize', 9, ...
            'FontColor', C.text, 'HorizontalAlignment', 'center', ...
            'BackgroundColor', 'none');
    end

    % ============================================================
    %   右中上 — 机械臂控制
    % ============================================================
    panArm = makePanel(fig, [745 440 340 210], C.panel, C.border, '◈  机械臂控制', C);
    armJoints = {'关节 1','关节 2','关节 3','关节 4','夹  爪'};
    armLimits = {[-90 90],[-90 90],[-135 135],[-90 90],[0 100]};
    armInit   = [0 0 0 0 100];
    hArmSliders = gobjects(5,1);
    hArmLabels  = gobjects(5,1);
    for i = 1:5
        y0 = 155 - (i-1)*32;
        uilabel(panArm, 'Text', armJoints{i}, ...
            'Position', [10 y0+2 55 18], 'FontSize', 9, ...
            'FontColor', C.subtext, 'BackgroundColor', 'none');
        hArmSliders(i) = uislider(panArm, ...
            'Value', armInit(i), ...
            'Limits', armLimits{i}, ...
            'Position', [70 y0+8 200 3], ...
            'ValueChangedFcn', @(s,~) updateArmJoint(state, i, s.Value));
        hArmLabels(i) = uilabel(panArm, 'Text', sprintf('%d°', armInit(i)), ...
            'Position', [278 y0+2 50 18], 'FontSize', 9, ...
            'FontColor', C.text, 'BackgroundColor', 'none');
    end

    uibutton(panArm, 'push', 'Text', '复位', ...
        'Position', [10 8 80 26], 'FontSize', 10, ...
        'BackgroundColor', C.accentDk, 'FontColor', C.text, ...
        'ButtonPushedFcn', @onArmReset);
    uibutton(panArm, 'push', 'Text', '抓取', ...
        'Position', [120 8 90 26], 'FontSize', 10, ...
        'BackgroundColor', C.accent, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) onGrip(state, hArmSliders, hArmLabels));
    uibutton(panArm, 'push', 'Text', '释放', ...
        'Position', [230 8 90 26], 'FontSize', 10, ...
        'BackgroundColor', C.accentDk, 'FontColor', C.text, ...
        'ButtonPushedFcn', @(~,~) onRelease(state, hArmSliders, hArmLabels));

    % ============================================================
    %   右中 — 任务规划
    % ============================================================
    panMission = makePanel(fig, [745 230 340 200], C.panel, C.border, '◈  任务规划', C);

    uilabel(panMission, 'Text', 'X(m)', 'Position', [10 155 40 18], ...
        'FontSize', 9, 'FontColor', C.subtext, 'BackgroundColor', 'none');
    edtWpX = uieditfield(panMission, 'numeric', 'Value', 0, ...
        'Position', [55 153 65 22], 'FontSize', 10, ...
        'BackgroundColor', C.panelDk, 'FontColor', C.text);
    uilabel(panMission, 'Text', 'Y(m)', 'Position', [130 155 40 18], ...
        'FontSize', 9, 'FontColor', C.subtext, 'BackgroundColor', 'none');
    edtWpY = uieditfield(panMission, 'numeric', 'Value', 0, ...
        'Position', [175 153 65 22], 'FontSize', 10, ...
        'BackgroundColor', C.panelDk, 'FontColor', C.text);
    uilabel(panMission, 'Text', '深(m)', 'Position', [250 155 40 18], ...
        'FontSize', 9, 'FontColor', C.subtext, 'BackgroundColor', 'none');
    edtWpD = uieditfield(panMission, 'numeric', 'Value', 5, ...
        'Position', [295 153 35 22], 'FontSize', 10, ...
        'BackgroundColor', C.panelDk, 'FontColor', C.text);

    uibutton(panMission, 'push', 'Text', '添加路点', ...
        'Position', [10 123 90 24], 'FontSize', 9, ...
        'BackgroundColor', C.accent, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @onAddWaypoint);
    uibutton(panMission, 'push', 'Text', '清除路点', ...
        'Position', [110 123 90 24], 'FontSize', 9, ...
        'BackgroundColor', C.accentDk, 'FontColor', C.text, ...
        'ButtonPushedFcn', @(~,~) onClearWaypoints());
    uibutton(panMission, 'push', 'Text', '执行任务', ...
        'Position', [230 123 100 24], 'FontSize', 9, ...
        'BackgroundColor', C.success, 'FontColor', [0 0 0], ...
        'ButtonPushedFcn', @onStartMission);

    lblWpList = uitextarea(panMission, ...
        'Value',  '路点列表为空', ...
        'Position', [10 10 320 108], ...
        'FontSize', 9, ...
        'BackgroundColor', C.panelDk, 'FontColor', C.subtext, ...
        'Editable', 'off');

    % ============================================================
    %   右下 — 数据日志
    % ============================================================
    panLog = makePanel(fig, [745 5 340 215], C.panel, C.border, '◈  数据日志', C);

    txtLog = uitextarea(panLog, ...
        'Value', {'--- 系统日志 ---'}, ...
        'Position', [10 38 320 155], ...
        'FontSize', 9, ...
        'BackgroundColor', C.panelDk, 'FontColor', C.subtext, ...
        'Editable', 'off');

    uibutton(panLog, 'push', 'Text', '开始记录', ...
        'Position', [10 8 90 24], 'FontSize', 9, ...
        'BackgroundColor', C.green, 'FontColor', [0 0 0], ...
        'ButtonPushedFcn', @(~,~) startLogging(state, txtLog));
    uibutton(panLog, 'push', 'Text', '停止记录', ...
        'Position', [110 8 90 24], 'FontSize', 9, ...
        'BackgroundColor', C.accentDk, 'FontColor', C.text, ...
        'ButtonPushedFcn', @(~,~) stopLogging(state, txtLog));
    uibutton(panLog, 'push', 'Text', '导出 CSV', ...
        'Position', [230 8 100 24], 'FontSize', 9, ...
        'BackgroundColor', C.accent, 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @(~,~) exportLog(state));

    % ============================================================
    %   顶部中央 — 姿态仪 & 速度表
    % ============================================================
    panAttitude = makePanel(fig, [745 865 690 0], C.panel, C.border, '', C);
    % (折叠于顶部 topBar)

    % ============================================================
    %   定时器 — 仿真更新
    % ============================================================
    tmr = timer('ExecutionMode', 'fixedRate', 'Period', 0.2, ...
        'TimerFcn', @onTimerTick, 'ErrorFcn', @onTimerError);
    start(tmr);

    tickCount = 0;

    % ============================================================
    %   内部回调函数
    % ============================================================

    function onTimerTick(~, ~)
        if ~isvalid(fig), stopTimer(); return; end
        tickCount = tickCount + 1;
        state.updateSimulation();
        updateSensorLabels();
        if mod(tickCount, 2) == 0
            updateSonar();
        end
        if mod(tickCount, 3) == 0
            updateCameraView();
        end
        updateThrusterBars();
        updateTopBar();
        if state.LogActive
            logEntry = sprintf('深度=%.2fm 水温=%.1f°C 电量=%.1f%% 位置=(%.1f,%.1f)', ...
                state.Depth, state.WaterTemp, state.Battery, ...
                state.PositionX, state.PositionY);
            state.addLogEntry(logEntry);
            if mod(tickCount, 25) == 0
                appendLog(txtLog, logEntry);
            end
        end
    end

    function onTimerError(~, ~)
        stopTimer();
    end

    function stopTimer()
        try
            if isvalid(tmr) && strcmp(tmr.Running, 'on')
                stop(tmr);
            end
            delete(tmr);
        catch
        end
    end

    function updateSensorLabels()
        lblDepthVal.Text  = sprintf('%.2f m',    state.Depth);
        lblPressVal.Text  = sprintf('%.2f bar',  state.Pressure);
        lblTempVal.Text   = sprintf('%.1f °C',   state.WaterTemp);
        lblSalinVal.Text  = sprintf('%.1f PSU',  state.Salinity);
        lblO2Val.Text     = sprintf('%.2f mg/L', state.OxygenLevel);
        lblBatVal.Text    = sprintf('%.1f %%',   state.Battery);
        lblVoltVal.Text   = sprintf('%.1f V',    state.BatteryVoltage);
        lblSigVal.Text    = sprintf('%.0f %%',   state.SignalStrength);
        lblMotTVal.Text   = sprintf('%.1f °C',   state.MotorTemp);

        % 电量颜色预警
        if state.Battery < 20
            lblBatVal.FontColor = C.error;
        elseif state.Battery < 40
            lblBatVal.FontColor = C.warn;
        else
            lblBatVal.FontColor = C.success;
        end
    end

    function updateSonar()
        angles = linspace(0, 2*pi, 361);
        r      = state.SonarMap;
        xs     = r .* cos(angles(1:360)');
        ys     = r .* sin(angles(1:360)');
        % 扫描线
        ang = state.SonarAngle * pi / 180;
        set(hScanLine, 'XData', [0 22*cos(ang)], 'YData', [0 22*sin(ang)]);
        % 回波散点
        set(hEchoScat, 'XData', xs, 'YData', ys, 'CData', r);
    end

    function updateCameraView()
        frame = generateCameraFrame(state);
        set(hCamImg, 'CData', frame);
        % 浮游颗粒动画
        newX = mod(hCamParticles.XData + randn(size(hCamParticles.XData))*2, 100);
        newY = mod(hCamParticles.YData + randn(size(hCamParticles.YData))*2, 100);
        set(hCamParticles, 'XData', newX, 'YData', newY);
    end

    function updateThrusterBars()
        thrusters = [state.Thruster1, state.Thruster2, state.Thruster3, ...
                     state.Thruster4, state.Thruster5, state.Thruster6];
        for k = 1:6
            v = thrusters(k);
            cla(hThrBars(k));
            hold(hThrBars(k), 'on');
            clr = C.green;
            if abs(v) > 70, clr = C.warn; end
            if abs(v) > 90, clr = C.error; end
            bar(hThrBars(k), v, 0.6, 20, 'FaceColor', clr, 'EdgeColor', 'none');
            hThrBars(k).XLim = [-100 100];
            hThrBars(k).YLim = [0 1];
            hThrLbls(k).Text = sprintf('%+.0f%%', v);
        end
    end

    function updateTopBar()
        if state.EmergencyStop
            lblMode.Text      = '模式: 紧急停止';
            lblMode.FontColor = C.error;
        else
            lblMode.Text      = ['模式: ' state.Mode];
            lblMode.FontColor = C.warn;
        end
        if state.IsConnected
            lblConn.Text      = '● 已连接';
            lblConn.FontColor = C.success;
        else
            lblConn.Text      = '● 已断开';
            lblConn.FontColor = C.error;
        end
    end

    function onModeChange(src, ~)
        state.setMode(src.Value);
        ddMode.Value = src.Value;
        appendLog(txtLog, ['模式切换: ' src.Value]);
    end

    function setSpeed(st, axis, dir)
        power = sldPower.Value / 100;
        switch axis
            case 'fwd'
                st.SpeedForward  = dir * power * 3;
                st.Thruster1     = dir * power * 80;
                st.Thruster2     = dir * power * 80;
                st.Thruster3     = dir * power * 80;
                st.Thruster4     = dir * power * 80;
            case 'yaw'
                st.Heading       = mod(st.Heading + dir * 5, 360);
                st.Thruster1     =  dir * power * 60;
                st.Thruster2     = -dir * power * 60;
                st.Thruster3     =  dir * power * 60;
                st.Thruster4     = -dir * power * 60;
            case 'vert'
                st.SpeedVertical = dir * power * 1.5;
                st.Thruster5     = dir * power * 70;
                st.Thruster6     = dir * power * 70;
        end
        lblPower.Text = sprintf('%d %%', round(sldPower.Value));
    end

    function stopMotion(st)
        st.SpeedForward  = 0;
        st.SpeedLateral  = 0;
        st.SpeedVertical = 0;
        st.Thruster1     = 0; st.Thruster2 = 0;
        st.Thruster3     = 0; st.Thruster4 = 0;
        st.Thruster5     = 0; st.Thruster6 = 0;
        appendLog(txtLog, '运动停止');
    end

    function setPower(~, val)
        lblPower.Text = sprintf('%d %%', round(val));
    end

    function setTargetDepth(st, d)
        st.TargetDepth = d;
        appendLog(txtLog, sprintf('目标深度设定: %.1f m', d));
    end

    function onEmergencyStop(~, ~)
        state.EmergencyStop = true;
        stopMotion(state);
        btnEmg.BackgroundColor = [0.9 0.1 0.1];
        btnEmg.Text = '⛔  紧急停止已激活  —  点击解除';
        btnEmg.ButtonPushedFcn = @onEmergencyRelease;
        appendLog(txtLog, '!!! 紧急停止已激活 !!!');
    end

    function onEmergencyRelease(~, ~)
        state.EmergencyStop = false;
        btnEmg.BackgroundColor = [0.6 0.05 0.05];
        btnEmg.Text = '⛔  紧 急 停 止';
        btnEmg.ButtonPushedFcn = @onEmergencyStop;
        appendLog(txtLog, '紧急停止已解除');
    end

    function updateArmJoint(st, idx, val)
        switch idx
            case 1, st.Arm1Angle = val;
            case 2, st.Arm2Angle = val;
            case 3, st.Arm3Angle = val;
            case 4, st.Arm4Angle = val;
            case 5, st.GripperOpen = val;
        end
        if idx == 5
            unitStr = '%';
        else
            unitStr = '°';
        end
        hArmLabels(idx).Text = sprintf('%.0f%s', val, unitStr);
    end

    function onArmReset(~, ~)
        defaults = [0 0 0 0 100];
        for k = 1:5
            hArmSliders(k).Value = defaults(k);
            updateArmJoint(state, k, defaults(k));
        end
        appendLog(txtLog, '机械臂复位');
    end

    function onGrip(st, sliders, labels)
        sliders(5).Value = 10;
        updateArmJoint(st, 5, 10);
        appendLog(txtLog, '夹爪: 抓取');
    end

    function onRelease(st, sliders, labels)
        sliders(5).Value = 100;
        updateArmJoint(st, 5, 100);
        appendLog(txtLog, '夹爪: 释放');
    end

    function onAddWaypoint(~, ~)
        x = edtWpX.Value;
        y = edtWpY.Value;
        d = edtWpD.Value;
        state.addWaypoint(x, y, d);
        updateWaypointList();
        appendLog(txtLog, sprintf('添加路点: (%.1f, %.1f, %.1f)', x, y, d));
    end

    function onClearWaypoints()
        state.clearWaypoints();
        lblWpList.Value = {'路点列表为空'};
        appendLog(txtLog, '路点已清除');
    end

    function onStartMission(~, ~)
        if isempty(state.Waypoints)
            appendLog(txtLog, '任务启动失败: 无路点');
        else
            state.CurrentWaypoint = 1;
            state.setMode('自动');
            ddMode.Value = '自动';
            appendLog(txtLog, sprintf('任务启动，共 %d 个路点', size(state.Waypoints,1)));
        end
    end

    function updateWaypointList()
        if isempty(state.Waypoints)
            lblWpList.Value = {'路点列表为空'};
            return;
        end
        lines = cell(size(state.Waypoints, 1), 1);
        for k = 1:size(state.Waypoints, 1)
            lines{k} = sprintf('#%d  X=%.1f  Y=%.1f  深=%.1fm', ...
                k, state.Waypoints(k,1), state.Waypoints(k,2), state.Waypoints(k,3));
        end
        lblWpList.Value = lines;
    end

    function startLogging(st, txt)
        st.LogActive = true;
        appendLog(txt, '数据记录已开始');
    end

    function stopLogging(st, txt)
        st.LogActive = false;
        appendLog(txt, '数据记录已停止');
    end

    function exportLog(st)
        if isempty(st.LogData)
            uialert(fig, '日志为空，无数据可导出。', '导出失败');
            return;
        end
        [fname, fpath] = uiputfile('*.csv', '导出日志', 'robot_log.csv');
        if isequal(fname, 0), return; end
        fid = fopen(fullfile(fpath, fname), 'w');
        fprintf(fid, '序号,数据\n');
        for k = 1:numel(st.LogData)
            fprintf(fid, '%d,%s\n', k, st.LogData{k});
        end
        fclose(fid);
        uialert(fig, ['已导出 ' num2str(numel(st.LogData)) ' 条记录。'], '导出成功');
    end

    function onCapture(~, ~)
        frame = generateCameraFrame(state);
        [fname, fpath] = uiputfile('*.png', '保存截图', 'underwater_capture.png');
        if ~isequal(fname, 0)
            imwrite(uint8(frame * 2.55), fullfile(fpath, fname));
            appendLog(txtLog, ['摄像头截图已保存: ' fname]);
        end
    end

    function appendLog(txt, msg)
        cur = txt.Value;
        if numel(cur) > 80
            cur = cur(end-50:end);
        end
        txt.Value = [cur; {msg}];
        drawnow limitrate;
    end

    function onClose(~, ~)
        stopTimer();
        delete(fig);
    end

end

% ============================================================
%   辅助函数
% ============================================================

function p = makePanel(parent, pos, bgColor, borderColor, titleStr, C)
    p = uipanel(parent, ...
        'Position',       pos, ...
        'BackgroundColor', bgColor, ...
        'BorderColor',    borderColor, ...
        'BorderType',     'line', ...
        'FontSize',       10, ...
        'FontWeight',     'bold', ...
        'ForegroundColor', C.accent, ...
        'Title',          titleStr);
end

function btn = makeCtrlBtn(parent, pos, label, C, callback)
    btn = uibutton(parent, 'push', 'Text', label, ...
        'Position',       pos, ...
        'FontSize',       10, 'FontWeight', 'bold', ...
        'BackgroundColor', C.accentDk, 'FontColor', C.text, ...
        'ButtonPushedFcn', @(~,~) callback());
end

function [valLabel, nameLabel] = makeSensorRow(parent, yPos, name, initVal, C)
    nameLabel = uilabel(parent, 'Text', name, ...
        'Position', [10 yPos 65 20], 'FontSize', 10, ...
        'FontColor', C.subtext, 'BackgroundColor', 'none');
    valLabel = uilabel(parent, 'Text', initVal, ...
        'Position', [80 yPos 210 20], 'FontSize', 10, ...
        'FontColor', C.text, 'BackgroundColor', 'none', ...
        'HorizontalAlignment', 'right');
end

function frame = generateCameraFrame(state)
    % 生成仿真水下摄像头画面 (100×100 灰度图)
    [X, Y] = meshgrid(linspace(0, 1, 100));
    depth_factor = min(1, state.Depth / 50);
    % 水体颜色（随深度变暗）
    base = 0.4 - depth_factor * 0.3;
    noise = randn(100) * 0.03;
    frame = base + noise;
    % 模拟光晕
    cx = 0.5 + randn() * 0.1;
    cy = 0.5 + randn() * 0.1;
    glow = exp(-((X-cx).^2 + (Y-cy).^2) / 0.08) * (0.3 - depth_factor*0.25);
    frame = frame + glow;
    % 模拟海底线（大于某深度可见）
    if state.Depth > 5
        seabedRow = round(60 + randn() * 3);
        seabedRow = max(1, min(100, seabedRow));
        frame(seabedRow:end, :) = frame(seabedRow:end, :) * 0.6 + 0.15;
    end
    % 模拟颗粒/浮游物
    for k = 1:8
        px = randi(100); py = randi(100);
        r  = randi(2);
        r1 = max(1, px-r); r2 = min(100, px+r);
        c1 = max(1, py-r); c2 = min(100, py+r);
        frame(r1:r2, c1:c2) = frame(r1:r2, c1:c2) + 0.15;
    end
    frame = max(0, min(1, frame)) * 100;
end
