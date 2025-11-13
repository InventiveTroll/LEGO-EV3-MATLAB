function test()
    % --- LEGO EV3 Remote Control with Smart Obstacle Avoidance (1 Ultrasonic) ---
    % Ultrasonic Sensor -> Port 1
    % Color Sensor -> Port 2 (optional)
    % Motors -> A (Left), D (Right), B (Auxiliary)

    try
        brick = ConnectBrick('ACCESOR');
        brick.beep();
        disp('✅ Connected to EV3 Brick!');
    catch ME
        error('❌ Could not connect to EV3 brick: %s', ME.message);
    end

    % --- Parameters ---
    speed = 50;               % Driving motor speed
    distanceThreshold = 20;   % cm — obstacle detection
    checkPause = 0.3;         % seconds between sensor checks
    turnDuration = 0.8;       % time to turn ~90 degrees
    backupDuration = 0.5;     % reverse duration if stuck
    speedIncrement = 10;

    % --- Setup GUI ---
    hFig = figure('Name', 'EV3 Remote Control', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'KeyPressFcn', @keyDown, ...
        'KeyReleaseFcn', @keyUp, ...
        'CloseRequestFcn', @onClose);

    axis off;
    text(0.5, 0.5, ...
        sprintf(['Use Arrow Keys to Drive\n' ...
                 'K/L = Forklift Up/Down\n' ...
                 'W/S = Speed +/-\n' ...
                 'B = Run Motor B\n' ...
                 'A = Toggle Auto Mode\n' ...
                 'Space = Stop | Q = Quit | Esc = Kill Switch\n' ...
                 'Ultrasonic: Port 1 | Color: Port 2 (optional)']), ...
        'HorizontalAlignment', 'center', 'FontSize', 12);

    setappdata(hFig, 'key', '');
    setappdata(hFig, 'running', true);

    lastCheck = tic;
    auto = false; % start in manual mode
    forkliftOpen = true;

    % --- Setup Color Sensor ---
    brick.SetColorMode(3, 2);

    % --- Main loop ---
    while ishandle(hFig) && getappdata(hFig, 'running')
        key = getappdata(hFig, 'key');

        % --- Autonomous Navigation (Right-first Maze Solver) ---
        if auto
            if toc(lastCheck) > checkPause
                lastCheck = tic;
                try
                    dist = brick.UltrasonicDist(1);
                    touch = brick.TouchPressed(2);
                catch
                    dist = 999;
                end
    
                if dist > distanceThreshold
                    disp(['Opening detected (' num2str(dist) ' cm)']);
                    brick.StopMotor('AD', 'Brake');
                    brick.beep();
                    pause(0.2);
    
                    % --- Try turning right first ---
                    brick.MoveMotor('A', speed);
                    brick.MoveMotor('D', -speed);
                    pause(turnDuration);
                    brick.StopMotor('AD', 'Brake');
                    pause(0.2);
                else
                    if touch
                        % --- Turn left ---
                        brick.MoveMotor('A', -speed);
                        brick.MoveMotor('D', speed);
                        pause(turnDuration);
                        brick.StopMotor('AD', 'Brake');
                        pause(0.2);
                    else 
                        % Path clear, move forward
                        brick.MoveMotor('A', -speed);
                        brick.MoveMotor('D', -speed);
                    end
                end
            end
        end

        % --- Manual Control ---
        try
            switch key
                case 'uparrow'
                    brick.MoveMotor('A', -speed);
                    brick.MoveMotor('D', -speed);

                case 'downarrow'
                    brick.MoveMotor('A', speed);
                    brick.MoveMotor('D', speed);

                case 'leftarrow'
                    brick.MoveMotor('A', -speed);
                    brick.MoveMotor('D', speed);

                case 'rightarrow'
                    brick.MoveMotor('A', speed);
                    brick.MoveMotor('D', -speed);

                case 'k'
                    % Forklift up (short pulse)
                    disp('⬆️ Forklift lifting up...');
                    brick.MoveMotor('B', -40);
                    pause(0.4);  % adjust time for lift height
                    brick.StopMotor('B', 'Brake');

                case 'l'
                    % Forklift down (short pulse)
                    disp('⬇️ Forklift lowering down...');
                    brick.MoveMotor('B', 40);
                    pause(0.4);  % adjust time for lower distance
                    brick.StopMotor('B', 'Brake');
                case '1'
                    if (forkliftOpen)
                        forkliftOpen = false;
                        brick.ResetMotorAngle('B');
                        disp('Forklift grabbing');
                        brick.MoveMotorAngleAbs('B', 50, 180*12);
                        brick.WaitForMotor('B');
                    else
                        forkliftOpen = true;
                        brick.ResetMotorAngle('B');
                        disp('Forklift letting go');
                        brick.MoveMotorAngleAbs('B', 50, -180*12);
                        brick.WaitForMotor('B');
                    end
                case 'space'
                    brick.StopAllMotors('Brake');

                case 's'
                    if (speed >= 0 + speedIncrement)
                        speed = speed - speedIncrement;
                        disp(['Speed decreased to ' num2str(speed)]);
                    end

                case 'w'
                    if (speed <= 100 - speedIncrement)
                        speed = speed + speedIncrement;
                        disp(['Speed increased to ' num2str(speed)]);
                    end

                case {'q', 'Q'}
                    stopAndCleanup();
                    return;

                case 'escape'
                    brick.StopAllMotors();
                    brick.beep();
                    disp('🛑 KILL SWITCH ACTIVATED');
                    stopAndCleanup();
                    return;

                case 'a'
                    auto = ~auto;
                    if auto
                        brick.beep();
                        disp('🤖 AUTO MODE: ON');
                    else
                        brick.beep();
                        pause(0.2);
                        brick.beep();
                        disp('🕹️ AUTO MODE: OFF (Manual Control)');
                        brick.StopAllMotors('Brake');
                    end

                otherwise
                    if ~auto
                        brick.StopMotor('AD', 'Brake');
                    end
            end
        catch ME
            disp(['Motor command failed: ' ME.message]);
        end

        pause(0.05);
    end

    % --- Nested helper functions ---
    function keyDown(~, event)
        setappdata(hFig, 'key', event.Key);
    end

    function keyUp(~, ~)
        setappdata(hFig, 'key', '');
    end

    function onClose(~, ~)
        stopAndCleanup();
    end

    function stopAndCleanup()
        if isvalid(hFig)
            setappdata(hFig, 'running', false);
            try
                brick.StopAllMotors();
                brick.beep();
                disp('Motors stopped and brick cleaned up.');
            catch
            end
            pause(0.2);
            close(hFig);
        end
        clear brick;
        disp('🔌 Disconnected from EV3 safely.');
    end
end
