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
    speedB = 11;              % Motor B speed (separate key)
    distanceThreshold = 15;   % cm — obstacle detection
    checkPause = 0.3;         % seconds between sensor checks
    turnDuration = 0.5;       % seconds to test direction
    backupDuration = 0.5;     % reverse duration if stuck

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
                 'B = Run Motor B\n' ...
                 'Space = Stop | Q = Quit | Esc = Kill Switch\n' ...
                 'Ultrasonic: Port 1 | Color: Port 2 (optional)']), ...
        'HorizontalAlignment', 'center', 'FontSize', 12);

    setappdata(hFig, 'key', '');
    setappdata(hFig, 'running', true);

    lastCheck = tic;

    % --- Main loop ---
    while ishandle(hFig) && getappdata(hFig, 'running')
        key = getappdata(hFig, 'key');

        % --- Obstacle check every 0.3s ---
        if toc(lastCheck) > checkPause
            lastCheck = tic;
            try
                dist = brick.UltrasonicDist(1);
                colorVal = brick.ColorCode(2);
            catch
                dist = 999;
            end

            % If object too close in front
            if dist > 0 && dist < distanceThreshold
                disp(['git Obstacle detected at ' num2str(dist) ' cm!']);

                % Stop
                brick.StopMotor('AD', 'Brake');
                brick.beep();
                pause(0.2);

                % Try turning right
                brick.MoveMotor('A', speed);
                brick.MoveMotor('D', -speed);
                pause(turnDuration);
                brick.StopMotor('AD', 'Brake');
                pause(0.2);

                % Recheck
                try
                    distAfterRight = brick.UltrasonicDist(1);
                catch
                    distAfterRight = 999;
                end

                if distAfterRight < distanceThreshold
                    disp('Right blocked → trying left...');
                    % Turn left instead
                    brick.MoveMotor('A', -speed);
                    brick.MoveMotor('D', speed);
                    pause(turnDuration * 2);
                    brick.StopMotor('AD', 'Brake');
                    pause(0.2);

                    try
                        distAfterLeft = brick.UltrasonicDist(1);
                    catch
                        distAfterLeft = 999;
                    end

                    if distAfterLeft < distanceThreshold
                        disp('Front + both sides blocked → backing up...');
                        % Backup and turn right
                        brick.MoveMotor('A', speed);
                        brick.MoveMotor('D', speed);
                        pause(backupDuration);
                        brick.MoveMotor('A', speed);
                        brick.MoveMotor('D', -speed);
                        pause(turnDuration);
                        brick.StopMotor('AD', 'Brake');
                    else
                        disp('✅ Path clear on left, continuing...');
                    end
                else
                    disp('✅ Path clear on right, continuing...');
                end
            end

            % If color is black
            if colorVal == 1
                brick.STopMotor('AD', 'Brake');
                brick.beep();
                disp('Black surface detected, stopping');
                pause(0.5);
            end


        end

        % --- Manual control ---
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
                case 'b'
                    brick.MoveMotor('B', speedB);
                case 'space'
                    brick.StopAllMotors('Brake');
                case {'q','Q'}
                    stopAndCleanup();
                    return;
                case 'escape'
                    brick.StopAllMotors();
                    brick.beep();
                    disp('⚠️ KILL SWITCH ACTIVATED');
                    stopAndCleanup();
                    return;
                otherwise
                    brick.StopMotor('AD', 'Brake');
            end
        catch ME
            disp(['⚠️ Motor command failed: ' ME.message]);
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
                disp('🛑 Motors stopped and brick cleaned up.');
            catch
            end
            pause(0.2);
            close(hFig);
        end
        clear brick;
        disp('🔌 Disconnected from EV3 safely.');
    end
end
