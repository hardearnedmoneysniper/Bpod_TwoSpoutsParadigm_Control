% This protocol is a starting point for a lick left or right task.
% Author Wuyang Zhang @Westlake 

function Lick_Left_or_Right

    global BpodSystem

    timestamps = []; % to record the time of each choice
    % initialize
    S = BpodSystem.ProtocolSettings; 
    if isempty(fieldnames(S))  
        S.GUI.RewardAmount = 0.1; % 每次奖励的时间（秒）
        S.GUI.CueDuration = 30;   % Sound cue持续时间（秒）
        S.GUI.InterTrialInterval = 5; % 每次trial之间的间隔时间（秒）
    end

    % HiFi模块用于播放声音cue
    BpodSystem.assertModule('HiFi', 1); % The second argument (1) indicates that the HiFi module must be paired with its USB serial port
    H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1);   % The argument is the name of the HiFi module's USB serial port (e.g. COM3)
    H.load(1, GenerateSineWave(192000, 8000, S.GUI.CueDuration) * .6); %8000Hz正弦波 高频声音刺激，小鼠对高频声音敏感
                                                                 % .6  控制音量，大了的话，可以调小
    %% Main Loop
    for currentTrial = 1:5000    % 5000次不用改，防止数量不够
        S = BpodParameterGUI('sync', S); 
        leftRewardPort = 'Port1';
        rightRewardPort = 'Port3';
        rewardTime = S.GUI.RewardAmount; 
        cueDuration = S.GUI.CueDuration;
        interTrialInterval = S.GUI.InterTrialInterval;

        % define
        sma = NewStateMatrix();
       

        % Sound cue状态   30s声音刺激cue    Port1 and Port3 一直通电，0~255可以调整通电电压。
        sma = AddState(sma, 'Name', 'CueOn', ...
            'Timer', cueDuration, ...
            'StateChangeConditions', {'Port1In', 'LeftChosen', 'Port3In', 'RightChosen', 'Tup', 'NoResponse'}, ...
            'OutputActions', {'HiFi1', ['P' 0], leftRewardPort, 255, rightRewardPort, 255});

        % 左水嘴Port1被选择，给水奖励0.1S并结束cue
        sma = AddState(sma, 'Name', 'LeftChosen', ...
            'Timer', rewardTime, ...
            'StateChangeConditions', {'Tup', 'InterTrial'}, ...
            'OutputActions', {leftRewardPort, 255});
        
        % 右水嘴Port3被选择，给水奖励0.1s并结束cue
        sma = AddState(sma, 'Name', 'RightChosen', ...
            'Timer', rewardTime, ...
            'StateChangeConditions', {'Tup', 'InterTrial'}, ...
            'OutputActions', {rightRewardPort, 255});
        
        % NoResponse状态：cue持续时间结束而未选择任何水嘴
        sma = AddState(sma, 'Name', 'NoResponse', ...
            'Timer', 0, ...
            'StateChangeConditions', {'Tup', 'InterTrial'}, ...
            'OutputActions', {});

        % InterTrial状态5s：等待下一个trial
        sma = AddState(sma, 'Name', 'InterTrial', ...
            'Timer', interTrialInterval, ...
            'StateChangeConditions', {'Tup', 'CueOn'}, ...
            'OutputActions', {});

        % 传送数据
        SendStateMachine(sma);
        RawEvents = RunStateMachine; 

        % 保存数据
        if ~isempty(fieldnames(RawEvents))% If you didn't stop the session manually mid-trial
            BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);% Adds raw events to a human-readable data struct
            BpodSystem.Data.TrialSettings(currentTrial) = S;% Adds the settings used for the current trial to the Data struct
            SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
       
         
        end


        % count
         choices = []; % 记录选择
         leftChoiceCount = 0;  % 选择左水嘴（1）的计数
         rightChoiceCount = 0; % 选择右水嘴（2）的计数
         noChoiceCount = 0;    % 没有选择（0）的计数


        % 获取当前trial的选择，记录选择的水嘴
        if isfield(RawEvents, 'Port1In') && ~isempty(RawEvents.Port1In) % 如果Port1被选择
            choices = [choices; 1]; % 选择左水嘴显示1
        elseif isfield(RawEvents, 'Port3In') && ~isempty(RawEvents.Port3In) % 如果Port3被选择
            choices = [choices; 2]; % 选择右水嘴显示2
        else
            choices = [choices; 0]; % 0是没有选择
        end

        timestamps = [timestamps; datetime('now')]; % time info

        % plot
        figure;
        hold on;

        % Subplot 1: Scatter Plot (选择的情况)
        subplot(1, 2, 1);
        scatter(1:currentTrial, choices, 'filled', 'MarkerFaceColor', [0.2, 0.6, 1]);  %[0.2, 0.6, 1] light blue
        xlabel('Trial Number','FontSize',12);
        ylabel('Water Spout Chosen','FontSize',12);
        ylim([0 3]);
        xlim([0, currentTrial]);
        title('Real-time Water Spout Choices','FontSize',12);

        % Subplot 2: Bar Plot (选择次数)
        subplot(1, 2, 2);
        noChoiceCount = length(find(choices == 0));
        leftChoiceCount = length(find(choices == 1));
        rightChoiceCount = length(find(choices == 2));
        hBar = bar([0, 1, 2], [noChoiceCount, leftChoiceCount, rightChoiceCount],'FaceColor', [169/255, 169/255, 169/255]);

        % add label
        text(0, noChoiceCount, num2str(noChoiceCount), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
        text(1, leftChoiceCount, num2str(leftChoiceCount), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
        text(2, rightChoiceCount, num2str(rightChoiceCount), 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');

        xlabel('Choice (0=No Choice, 1=Left, 2=Right)','FontSize',12);
        ylabel('Count','FontSize',12);
        xlim([-0.5, 2.5]);
        ylim([0, currentTrial]);


        drawnow;


        % %--- This final block of code is necessary for the Bpod console's pause and stop buttons to work
        HandlePauseCondition;
        if BpodSystem.Status.BeingUsed == 0
            return
        end
    end
end
