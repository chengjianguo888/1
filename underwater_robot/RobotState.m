classdef RobotState < handle
    % RobotState - 水下机器人共享状态管理类
    % 用于在各个面板之间共享机器人实时状态数据
    
    properties
        % 位置与姿态
        Depth           = 0.0       % 当前深度 (米)
        TargetDepth     = 0.0       % 目标深度 (米)
        Heading         = 0.0       % 航向角 (度, 0-360)
        Pitch           = 0.0       % 俯仰角 (度)
        Roll            = 0.0       % 横滚角 (度)
        PositionX       = 0.0       % X 坐标 (米)
        PositionY       = 0.0       % Y 坐标 (米)
        
        % 速度
        SpeedForward    = 0.0       % 前进速度 (节)
        SpeedLateral    = 0.0       % 侧向速度 (节)
        SpeedVertical   = 0.0       % 垂直速度 (节)
        
        % 环境传感器
        WaterTemp       = 15.0      % 水温 (°C)
        Pressure        = 1.0       % 水压 (bar)
        Salinity        = 35.0      % 盐度 (PSU)
        Turbidity       = 0.5       % 浑浊度 (NTU)
        OxygenLevel     = 8.0       % 溶解氧 (mg/L)
        
        % 系统状态
        Battery         = 100.0     % 电池电量 (%)
        BatteryVoltage  = 24.0      % 电池电压 (V)
        MotorTemp       = 25.0      % 电机温度 (°C)
        SignalStrength  = 95.0      % 信号强度 (%)
        
        % 推进器功率 (%, -100 到 100)
        Thruster1       = 0.0       % 前左推进器
        Thruster2       = 0.0       % 前右推进器
        Thruster3       = 0.0       % 后左推进器
        Thruster4       = 0.0       % 后右推进器
        Thruster5       = 0.0       % 垂直前推进器
        Thruster6       = 0.0       % 垂直后推进器
        
        % 机械臂状态 (度)
        Arm1Angle       = 0.0       % 关节 1
        Arm2Angle       = 0.0       % 关节 2
        Arm3Angle       = 0.0       % 关节 3
        Arm4Angle       = 0.0       % 关节 4
        GripperOpen     = 100.0     % 夹爪开合 (%)
        
        % 运行模式
        Mode            = '手动'    % '手动' / '自动' / '悬停'
        IsConnected     = true      % 连接状态
        IsArmed         = false     % 解锁状态
        EmergencyStop   = false     % 紧急停止
        
        % 数据日志
        LogData         = {}        % 日志数据
        LogActive       = false     % 日志是否激活
        
        % 任务路点
        Waypoints       = []        % Nx3 矩阵 [X, Y, Depth]
        CurrentWaypoint = 0         % 当前目标路点索引
        
        % 声纳数据
        SonarAngle      = 0         % 声纳扫描角度
        SonarMap        = []        % 声纳地图数据
    end
    
    methods
        function obj = RobotState()
            % 初始化声纳地图
            obj.SonarMap = zeros(360, 1) + 5 + rand(360, 1) * 15;
        end
        
        function updateSimulation(obj)
            % 仿真更新 - 模拟传感器数据变化
            if obj.EmergencyStop
                obj.SpeedForward  = 0;
                obj.SpeedLateral  = 0;
                obj.SpeedVertical = 0;
                return;
            end
            
            % 深度随垂直速度变化
            obj.Depth = max(0, obj.Depth + obj.SpeedVertical * 0.1);
            
            % 位置随速度变化
            headRad = obj.Heading * pi / 180;
            obj.PositionX = obj.PositionX + obj.SpeedForward * cos(headRad) * 0.1;
            obj.PositionY = obj.PositionY + obj.SpeedForward * sin(headRad) * 0.1;
            
            % 压力随深度变化 (每10米增加约1bar)
            obj.Pressure = 1.0 + obj.Depth / 10.0;
            
            % 水温随深度变化
            obj.WaterTemp = 20.0 - obj.Depth * 0.1 + randn() * 0.05;
            
            % 电池消耗
            totalThrust = abs(obj.Thruster1) + abs(obj.Thruster2) + ...
                          abs(obj.Thruster3) + abs(obj.Thruster4) + ...
                          abs(obj.Thruster5) + abs(obj.Thruster6);
            obj.Battery = max(0, obj.Battery - totalThrust * 0.00005);
            obj.BatteryVoltage = 20 + obj.Battery / 100 * 4.8;
            
            % 电机温度
            obj.MotorTemp = 25 + totalThrust * 0.2 + randn() * 0.5;
            
            % 信号强度随深度衰减
            obj.SignalStrength = max(10, 100 - obj.Depth * 0.5 + randn() * 2);
            
            % 声纳扫描更新
            obj.SonarAngle = mod(obj.SonarAngle + 3, 360);
            noiseLevel = randn() * 2;
            obj.SonarMap(obj.SonarAngle + 1) = 10 + rand() * 20 + noiseLevel;
        end
        
        function setMode(obj, mode)
            obj.Mode = mode;
            if strcmp(mode, '悬停')
                obj.SpeedForward  = 0;
                obj.SpeedLateral  = 0;
                obj.SpeedVertical = 0;
            end
        end
        
        function addLogEntry(obj, entry)
            if obj.LogActive
                obj.LogData{end+1} = entry;
            end
        end
        
        function addWaypoint(obj, x, y, depth)
            obj.Waypoints = [obj.Waypoints; x, y, depth];
        end
        
        function clearWaypoints(obj)
            obj.Waypoints = [];
            obj.CurrentWaypoint = 0;
        end
    end
end
