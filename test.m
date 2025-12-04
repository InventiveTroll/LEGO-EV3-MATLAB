function test()

    try
        brick = ConnectBrick('ACCESOR');
        brick.beep();
        disp('Connected to EV3 Brick!');
    catch ERR
        error('Could not connect to EV3 brick: %s', ERR.message);
    end

    % Parameters
    speed = 50;             
    distanceThreshold = 60;  
    checkPause = 0.3;        
    turnDuration = 0.9;       
    backupDuration = 0.5;     
    speedIncrement = 10;

    global key;
    running = true;
    InitKeyboard();

    lastCheck = tic;
    auto = false;
    forkliftOpen = true;
    rideDone = false;
    hasPassenger = false;
    lastDistanceCheck = 0;

    %brick.SetColorMode(3, 2);
    %pastColor = -1;
    %color = brick.ColorCode(3);
    brick.SetColorMode(3, 4);
    pastColor = brick.ColorRGB(3);
    color = brick.ColorRGB(3)

    while running

        % manual
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
                    disp('Forklift lifting up...');
                    brick.MoveMotor('B', -40);
                    pause(0.4);
                    brick.StopMotor('B', 'Brake');

                case 'l'
                    disp('Forklift lowering down...');
                    brick.MoveMotor('B', 40);
                    pause(0.4);
                    brick.StopMotor('B', 'Brake');
                case '1'
                    if (forkliftOpen)
                        forkliftOpen = false;
                        brick.ResetMotorAngle('B');
                        disp('Forklift grabbing');
                        brick.MoveMotorAngleAbs('B', 50, 180*18);
                        brick.WaitForMotor('B');
                    else
                        forkliftOpen = true;
                        brick.ResetMotorAngle('B');
                        disp('Forklift letting go');
                        brick.MoveMotorAngleAbs('B', 50, -180*18);
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
                    disp('Closing...');
                    stopAndCleanup();
                    return;

                case 'a'
                    auto = ~auto;
                    if auto
                        brick.beep();
                        disp('Auto');
                    else
                        brick.beep();
                        pause(0.2);
                        brick.beep();
                        disp('Manual');
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

        if auto
            if toc(lastCheck) > checkPause
                lastCheck = tic;
                try
                    dist = brick.UltrasonicDist(1);
                    touch1 = brick.TouchPressed(2);
                    touch2 = brick.TouchPressed(4);
                    %color = brick.ColorCode(3);
                    color = brick.ColorRGB(3);
                    disp(color);
                catch
                    dist = 999;
                end

                if color == 5 && color ~= pastColor
                    disp('Red detected - Stopping');
                    brick.StopMotor('AD', 'Brake');
                    pastColor = color;
                    brick.beep();
                    pause(1);
                    continue;
                end

                if color == 4 && color ~= pastColor
                    disp('Yellow detected');
                    if ~rideDone
                        disp('Ride in progress, cannot stop');
                        pastColor = color;
                        continue;
                    else 
                        brick.StopMotor('AD', 'Brake');
                        pastColor = color;
                        brick.beep();
                        auto = false;
                        continue;
                    end
                     
                end

                if color == 2 && color ~= pastColor
                    disp('Blue detected');
                    brick.StopMotor('AD', 'Brake');
                    pastColor = color;
                    brick.beep();
                    brick.beep();
                    pause(1);
                    if (~hasPassenger)
                        disp('No passenger inside, setting to manual mode to pick up passenger');
                        auto = false;
                        hasPassenger = true;
                        if (~forkliftOpen)
                            forkliftOpen = true;
                            brick.ResetMotorAngle('B');
                            disp('Forklift opening to pick up passenger');
                            brick.MoveMotorAngleAbs('B', 50, -180*18);
                            brick.WaitForMotor('B');
                        end
                    end
                    continue;
                end

                if color == 3 && color ~= pastColor
                    disp('Green detected');
                    brick.StopMotor('AD', 'Brake');
                    pastColor = color;
                    brick.beep();
                    brick.beep();
                    brick.beep();
                    disp(hasPassenger);
                    if hasPassenger
                        disp('Dropping off passenger...');
                        hasPassenger = false;
                        if (~forkliftOpen)
                            disp('Turning 180 degrees');
                            brick.StopMotor('AD', 'Brake');
                            brick.MoveMotor('A', -speed);
                            brick.MoveMotor('D', speed);
                            pause(turnDuration * 2);
                            brick.StopMotor('AD', 'Brake');
                            pause(0.2);
                            lastDistanceCheck = brick.UltrasonicDist(1);

                            % Open forklift to drop off passenger
                            brick.ResetMotorAngle('B');
                            disp('Forklift dropping off passenger');
                            brick.MoveMotorAngleAbs('B', 50, -180*18);
                            brick.WaitForMotor('B');
                            pause(0.5);
                            brick.MoveMotor('A', -speed);
                            brick.MoveMotor('D', -speed);
                            pause(0.5); % Move forward a bit to clear the drop-off zone
                            hasPassenger = false;
                            rideDone = true;
                        end
                    end
                    pause(1);
                    continue;
                end
    
                if dist > distanceThreshold
                    disp(['Opening detected (' num2str(dist) ' cm)']);
                    brick.StopMotor('AD', 'Brake');
                    brick.beep();
                    pause(0.2);
    
                    % Try turning right first
                    brick.StopMotor('AD', 'Brake');
                    brick.MoveMotor('A', -speed);
                    brick.MoveMotor('D', -speed);
                    pause(1); % Move forward a bit into the opening
                    brick.StopMotor('AD', 'Brake');
                    pause(0.2);

                    brick.MoveMotor('A', speed);
                    brick.MoveMotor('D', -speed);
                    pause(turnDuration);
                    brick.StopMotor('AD', 'Brake');
                    pause(0.2);

                    brick.MoveMotor('A', -speed);
                    brick.MoveMotor('D', -speed);

                    pause(1); % Move forward a bit to clear the intersection and prevent repeated turning
                    lastDistanceCheck = brick.UltrasonicDist(1);
                else
                    if touch1 && touch2
                        pause(0.5); % Make sure robot is pushed up against the wall

                        % Back up first
                        brick.MoveMotor('A', speed);
                        brick.MoveMotor('D', speed);
                        pause(backupDuration);
                        brick.StopMotor('AD', 'Brake');
                        pause(0.2);

                        % Turn left
                        brick.MoveMotor('A', -speed);
                        brick.MoveMotor('D', speed);
                        pause(turnDuration);
                        brick.StopMotor('AD', 'Brake');
                        pause(0.2);

                        lastDistanceCheck = brick.UltrasonicDist(1);
                    else 
                        if ((touch1 && abs(dist - lastDistanceCheck ) < 0.1)  || (touch2 && abs(dist - lastDistanceCheck ) < 0.1))
                            % turn 180 degrees if stuck
                            disp('Stuck detected - Turning 180 degrees');
                            brick.StopMotor('AD', 'Brake');
                            brick.MoveMotor('A', -speed);
                            brick.MoveMotor('D', speed);
                            pause(turnDuration * 2);
                            brick.StopMotor('AD', 'Brake');
                            pause(0.2);
                            lastDistanceCheck = brick.UltrasonicDist(1);
                        else
                            % Path clear, move forward
                        disp([dist, lastDistanceCheck]);

                        % Adjust motors to make vehicle move straighter
                        if (dist < 5)
                            % move away from wall
                            brick.MoveMotor('A', -speed - 10);
                                brick.MoveMotor('D', -speed + 10);
                                pause(1);
                                lastDistanceCheck = dist;
                        end

                        if (dist - lastDistanceCheck) > 1
                            brick.StopMotor('AD', 'Brake');
                            % Moving away from wall, turn slightly towards it
                            brick.MoveMotor('A', -speed + 10);
                            brick.MoveMotor('D', -speed - 10);
                            pause(1);
                            lastDistanceCheck = dist;
                        else 
                            if (lastDistanceCheck - dist) > 1
                                brick.StopMotor('AD', 'Brake');
                                % Moving towards wall, turn slightly away from it
                                brick.MoveMotor('A', -speed - 10);
                                brick.MoveMotor('D', -speed + 10);
                                pause(1);
                                lastDistanceCheck = dist;
                            end
                        end
                        brick.MoveMotor('A', -speed);
                        brick.MoveMotor('D', -speed);
                    end
                        end
                        
                end

                pastColor = color;
            end
        end

        pause(0.05);
    end
    
    function stopAndCleanup()
        brick.StopAllMotors();
        brick.beep();
        disp('Motors stopped and brick cleaned up');
        clear brick;
        disp('Disconnected from EV3');
        CloseKeyboard();
    end
end



