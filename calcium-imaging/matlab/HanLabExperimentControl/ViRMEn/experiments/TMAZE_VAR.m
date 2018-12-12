function code = TMAZE_VAR
% TMAZE_VAR   Code for the ViRMEn experiment TMAZE_VAR.
%   code = TMAZE_VAR   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT



% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)

%% MOVE WINDOW ONTO PROJECTOR SCREEN (will need to be changed for different set ups)
	vr.window.TopMost = false;
	vr.window.WindowState = System.Windows.Forms.FormWindowState.Normal;
	% screen sizes and setups)
	
%% SET UP VARIABLES
vr.vrSystem.numRewardsGiven = 0;
vr.vrSystem.numTrialsMissed = 0;
vr.currentSide = 'r'; %set default to right side


vr.floor_width = eval(vr.exper.variables.floor_width);%check value of floor_width
vr.percentage = eval(vr.exper.variables.percentage);
vr.decision_length = eval(vr.exper.variables.floor_width)*3.5...
    + eval(vr.exper.variables.floor_width)*3.5*eval(vr.exper.variables.percentage);
%vr.decision_length = eval(vr.exper.variables.decision_length);%check value of decision_length
    %when changing decision length, change the percentage in the GUI, and
    %then change the value of decision length (e.g. floor_width*3.5...+1)
    %and then hit undo. If you only change the percentage, nothing will happen. Decision length
    %only evaulates itself when it is changed. 

vr.soundNumber = false; % beep condition

%% REWARD CONDITIONS
vr.eligible = false;
vr.vrSystem.numRewardsGiven = 0;
vr.vrSystem.rewardCondition = 'obj.distanceFromTarget < 0';

%% ATTEMPT TO CLEAR ANY PREVIOUS HARDWARE CONNECTIONS
daq.reset
instrreset
fclose('all');

%% AUTOMATIC FILE NAMING 

try %data recording/file saving

disp('Initializing...')
% Data recording interfaces (and File Naming)
persistent instancenum
	if isempty(instancenum)
		instancenum = 1;
	else
		instancenum = instancenum+1;
	end
	global CURRENT_EXPERIMENT_NAME
	if isempty(CURRENT_EXPERIMENT_NAME)
		CURRENT_EXPERIMENT_NAME = sprintf('MOUSE99_%g',instancenum);
	else
		expNameRoot = strtok(CURRENT_EXPERIMENT_NAME,'_');
		CURRENT_EXPERIMENT_NAME = sprintf('%s_%g',expNameRoot,instancenum);
	end
name = inputdlg('Name this experiment, please','Experiment Name',1,{CURRENT_EXPERIMENT_NAME});
name = name{1};
CURRENT_EXPERIMENT_NAME = name;
catch me 
	disp(me.message)
	disp(me.stack(1))
end

%% VRSYSTEM FOR DATA SAVING AND MOVEMENT INTERFACE
try
vr.vrSystem = VrSystem(...
	'rewardCondition','true',...
	'autoSyncTrialTime',autoSyncTrialTime,...
	'currentExperimentName',name);
% Set VrSystem('rewardCondition') to false so reward can be handled in the runtimeCodeFunction
vr.vrSystem.rewardCondition = 'obj.distanceFromTarget < 0';

% Enable Experiment and Trial State Listeners
vr.vrSystem.start();  
fprintf('VrSystem intialized\n');

% Movement interface
vr.movementInterface = VrMovementInterface;
vr.movementInterface.start();

% Initialize RAW VELOCITY for recording direct optical sensor input
vr.vrSystem.rawVelocity = zeros(5,4);
vr.vrSystem.forwardVelocity = 0;

% Begin data-recording systems
fprintf('Sending ExperimentStart notification...\n');
notify(vr.vrSystem,'ExperimentStart');


win = vr.window;
ogl = vr.oglControl;
assignin('base','win',win);
assignin('base','ogl',ogl);

catch me
disp(me.message)
disp(stack(1))
end


% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)

%% CHOOSE SIDE WITH KEYBOARD
if ~isnan(vr.keyPressed) && ~isempty(str2double(vr.keyPressed))
    vr.currentSide = vr.keyPressed;
    disp(vr.currentSide)
end

%% REWARD ELIGIBLE
if vr.eligible == true
    vr.vrSystem.numRewardsGiven = vr.vrSystem.numRewardsGiven + 1;
    vr.vrSystem.rewardCondition = 'obj.distanceFromeTarget<0';
    disp('reward(s)')
    disp(vr.numRewardsGiven)
    vr.rewardEligible = false;
	vr.vrSystem.rewardPulseObj.sendPulse();
%     notify(vr.vrSystem, 'FrameAcquired',vrMsg(vr))
else
    vr.vrSystem.rewardCondition = false;
end

%% WHICH SOUND PLAYS
if (vr.position(2)<(vr.floor_width*3.5/7)&&(vr.soundNumber == 0))
	if (strcmp(vr.currentSide,'l'))
		sound(8*sin(linspace(100,500,1000)),9000);
	elseif (strcmp(vr.currentSide,'r'))
		 sound(8*sin(linspace(100,500,1000)),5000);
	end
    disp ('beep')
    vr.soundNumber = true;
end

%% TELEPORT BACK FROM THE LEFT TARGET ZONE
if(vr.position(1)>(-vr.floor_width*3.5))&&(vr.position(1)<(-vr.floor_width*3.5 + vr.floor_width*3.5/7))...
    vr.position(1)=0;
    vr.position(2)=(vr.floor_width*3.5/21);
    vr.position(4)=0;
    vr.dp(:)=0;
    vr.soundNumber = false;
    if strcmp(vr.currentSide,'l')
       disp('correct')
       vr.eligible = true;
    else
        vr.vrSystem.numTrialsMissed = vr.vrSystem.numTrialsMissed + 1;
        disp('wrong')
    end 
end
    
%% TELEPORT BACK FROM THE RIGHT TARGET ZONE
if(vr.position(1)>(vr.floor_width*3.5 - vr.floor_width*3.5/7))&&(vr.position(1)<(vr.floor_width*3.5))...
    vr.position(1)=0;
    vr.position(2)=(vr.floor_width*3.5/21);
    vr.position(4)=0;
    vr.dp(:)=0;
    vr.soundNumber = false;
    if strcmp(vr.currentSide,'r')
        disp('correct')
       vr.eligible = true;
    else
        vr.vrSystem.numTrialsMissed = vr.vrSystem.numTrialsMissed + 1;
        disp('wrong')
    end
end

%% NOTIFY VRSYSTEM TO SAVE DATA
try
	notify(vr.vrSystem,'FrameAcquired',vrMsg(vr))
catch me	
end


% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)
disp(['The animal recieved ' num2str(vr.vrSystem.numRewardsGiven) ' rewards.'])
disp(['The animal went to the incorrect side ' num2str(vr.vrSystem.numTrialsMissed) ' times.'])
disp(['The choice was changed ' num2str(vr.keyPressed(1)) ' times.'])