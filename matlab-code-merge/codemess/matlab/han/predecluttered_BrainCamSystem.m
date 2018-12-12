classdef BrainCamSystem < SubSystem
  
  
  
  
  properties % OBLIGATORY
	 experimentSyncObj
	 trialSyncObj
	 frameSyncObj
  end
  properties
	 autoSyncTrialTime
	 autoSyncTimerObj
	 numRewardsGiven
	 numRewardsMissed = 0;
	 rewardPulseObj
	 clockPulseObj
	 clkCounterName = 'ctr0'
	 clockRate = 25;
	 rewardCondition ='false' %= 'obj. > 100';
	 punishPulseObj
	 cameraObj
  end
  properties (Hidden)
	 lastError
  end
  
  
  
  
  events
	 ExperimentStart
	 ExperimentStop
	 NewTrial
	 NewStimulus
	 FrameAcquired
  end
  
  
  
  methods
	 function obj = BrainCamSystem(varargin)
		if nargin > 1
		  for k = 1:2:length(varargin)
			 obj.(varargin{k}) = varargin{k+1};
		  end
		end
		obj.defineDefaults()
		obj.checkProperties()
		obj.updateExperimentName()
		obj.createSystemComponents()
	 end
	 function defineDefaults(obj)
		persistent instancenum
		if isempty(instancenum)
		  instancenum = 1;
		else
		  instancenum = instancenum+1;
		end
		obj.defineDefaults@SubSystem;
		obj.default.autoSyncTrialTime = 6;
		obj.default.autoSaveFrequency = 1;
	 end
	 function checkProperties(obj)
		obj.savedDataFiles = VideoFile.empty(1,0);
		obj.currentDataFileSet = VideoFile.empty(1,0);
		obj.checkProperties@SubSystem;
	 end
  end
  methods % Requiired by SubSystem
	 function createSystemComponents(obj)
		% CREATE CAMERA
		obj.cameraObj =  Camera(...
		  'camAdaptor', 'hamamatsu',...
		  'videoFormat',  'MONO16_BIN2x2_1024x1024_FastMode');%,...
		% 		  'triggerConfiguration', 'manual');
		setup(obj.cameraObj);
		% 		trigconfig = obj.cameraObj.queryTriggerConfiguration();
		trigconfig = struct(...
		  'TriggerType','hardware',...
		  'TriggerCondition','RisingEdge',...
		  'TriggerSource','SynchronousReadoutTrigger');
		obj.cameraObj.triggerConfiguration = trigconfig;
		start(obj.cameraObj);
		if isempty(obj.experimentSyncObj) || ~isvalid(obj.experimentSyncObj)
		  obj.experimentSyncObj = obj;
		end
		if isempty(obj.trialSyncObj) || ~isvalid(obj.trialSyncObj)
		  if logical(obj.autoSyncTrialTime)
			 % A
			 obj.autoSyncTimerObj = timer(...
				'ExecutionMode','fixedRate',...
				'BusyMode','queue',...
				'Period',obj.autoSyncTrialTime,...
				'StartFcn',@(src,evnt)autoSyncTimerFcn(obj,src,evnt),...
				'TimerFcn',@(src,evnt)autoSyncTimerFcn(obj,src,evnt));
		  end
		  obj.trialSyncObj = obj;
		end
		if isempty(obj.frameSyncObj)
		  obj.frameSyncObj = obj.cameraObj;
		end
		% SETUP OUTPUTS USING NI-DAQ SESSION INTERFACE
		% REWARD-PULSE
		% 		  obj.rewardPulseObj = NiPulseOutput(...
		% 			 'pulseTime',.250,...
		% 			 'activeHigh',true,...
		% 			 'portNumber',0,...
		% 			 'lineNumber',0);
		% 		  obj.rewardPulseObj.setup();
		
		
		
		
		% CLOCK
		obj.clockPulseObj = getGlobalFrameClock();
		% 		  dev = daq.getDevices;
		% 		  devName = dev(1).ID;
		% 		  obj.clockPulseObj = daq.createSession('ni');
		% 		  ch = obj.clockPulseObj.addCounterOutputChannel(...
		% 			 devName,obj.clkCounterName,'PulseGeneration');
		% 		  obj.clockPulseObj.Rate = obj.clockRate;
		% 		  ch.Frequency = obj.clockRate;
		% 		  obj.clockPulseObj.IsContinuous = false;
		% 		  ch.InitialDelay = 0;
		% 		  ch.DutyCycle = .80;
		% 		  obj.clockPulseObj = NiPulseOutput(...
		% 			 'pulseTime',.005,...
		% 			 'activeHigh',true,...
		% 			 'portNumber',0,...
		% 			 'lineNumber',3);
		% 		  obj.clockPulseObj.setup();
		
		
		% Reward Variables
		obj.numRewardsGiven = 0;
		obj.numRewardsMissed = 0;
		obj.frameSyncListener.Enabled = false;
	 end
	 function start(obj)
		obj.updateExperimentName()
		fprintf('STARTING VRSYSTEM:\n\tSession-Path: %s\n',...
		  obj.sessionPath);
		if ~isdir(obj.sessionPath)
		  mkdir(obj.sessionPath)
		end
		if isempty(obj.frameSyncListener)
		  warning('BrainCamSystem:start:NoFrameSyncListener',...
			 'The Behavior-Control sysem is not connected to a camera, and will not record data every frame');
		else
		  obj.frameSyncListener.Enabled = true;
		end
		obj.trialStateListener.Enabled = true;
		obj.experimentStateListener.Enabled = true;
		if ~isempty(obj.clockPulseObj)
		  set(obj.cameraObj.videoInputObj, 'FramesAcquiredFcn', @(src,~)flushdata()); % TODO:
		  obj.clockPulseObj.startBackground();
		end
		obj.ready = true;
		fprintf('BrainCamSystem ready... waiting for ExperimentStart event from Virmen\n');
	 end
	 % 	 function trigger(obj)
	 % 		if ~isready(obj)
	 % 		  obj.start();
	 % 		end
	 % 		@(src,evnt)frameAcquiredFcn(obj,src,evnt)
	 % 		if ~isempty(obj.clockPulseObj)
	 % 		  obj.clockPulseObj.startBackground();
	 % 		end
	 % 		obj.trialStateListener.Enabled = true;
	 % 		fprintf('Experiment Started\n');
	 % 		obj.experimentRunning = true;
	 % 		if ~isempty(obj.currentDataFileSet)
	 % 		  obj.currentDataFileSet = VideoFile.empty(1,0);
	 % 		  obj.nDataFiles = 0;
	 % 		end
	 % 		if logical(obj.autoSyncTrialTime) && ~isempty(obj.autoSyncTimerObj)
	 % 		  start(obj.autoSyncTimerObj);
	 % 		  disp('autoSyncTimer started')
	 % 		end
		% 		obj.startPulseObj.sendPulse();
		% 	 end
	 function stop(obj)
		if ~isempty(obj.clockPulseObj)
		  obj.clockPulseObj.stop();
		end
		if ~isempty(obj.frameSyncListener)
		  obj.frameSyncListener.Enabled = false;
		end
		obj.trialStateListener.Enabled = false;
		obj.experimentStateListener.Enabled = false;
		if obj.experimentRunning
		  obj.experimentRunning = false;
		  if ~isempty(obj.currentDataFile) ...
				&& isopen(obj.currentDataFile) ...
				&& ~issaved(obj.currentDataFile)
			 obj.saveDataFile;
			 obj.currentDataFile = VideoFile.empty(1,0);
		  end
		  obj.saveDataSet();
		  obj.clearDataSet();
		  if logical(obj.autoSyncTrialTime) && ~isempty(obj.autoSyncTimerObj)
			 obj.autoSyncTimerObj.stop();
		  end
		  fprintf('Experiment Stopped\n');
		end
	 end
	 function experimentStateChangeFcn(obj,~,evnt)
		fprintf('BrainCamSystem: Received ExperimentStateChange event\n')
		switch evnt.EventName
		  case 'ExperimentStart'
			 if ~obj.experimentRunning
				obj.updateExperimentName();
				obj.trigger();
				% 				obj.startPulseObj.sendPulse();
			 end
		  case 'ExperimentStop'
			 obj.stop();
		end
	 end
	 function trialStateChangeFcn(obj,~,~)
		fprintf('BrainCamSystem: Received TrialStateChange event\n')
		persistent trial_number;
		if isempty(trial_number)
		  trial_number = 1;
		end
		try
		  if ~isempty(obj.currentDataFile)
			 obj.currentDataFile.experimentName = obj.currentExperimentName;
			 if ~isempty(obj.currentDataFile.trialNumber)
				% previous data-file -> save it
				obj.saveDataFile();
				% exits after creating new (blank) currentDataFile
				% for next trial
				trial_number = trial_number + 1;
			 end
		  end
		  % prepare next DataFile with info for next trial
		  % (or minute of recording)
		  obj.currentDataFile.trialNumber = trial_number;
		  obj.currentDataFile.experimentName = obj.currentExperimentName;
		  fprintf('Start of Trial: %i\n',trialnumber);
		catch me
		  obj.lastError = me;
		end
	 end
	 function frameAcquiredFcn(obj,~,evnt)
		try
		  obj.framesAcquired = obj.framesAcquired + 1;
		  if ~isempty(obj.clockPulseObj)
			 obj.clockPulseObj.sendPulse()
		  end
		  if isempty(obj.currentDataFile)
			 % called on first frame
			 obj.currentDataFile = VideoFile(...
				'rootPath',obj.currentDataSetPath,...
				'experimentName',obj.currentExperimentName);%changed rootPath from sessionPath
		  end
		  % Get Info Structure (about 32 bytes=3.5 MBytes/hr)
		  info.FrameNumber = obj.framesAcquired;
		  % 		  info.NumRewardsGiven = obj.numRewardsGiven;
		  % 		  info.NumTrialsMissed = obj.numRewardsMissed;
		  % 		  info.World = evnt.World;
		  % 		  info.Dt = evnt.Dt;
		  % 		  info.Xpos = evnt.Xpos;
		  % 		  info.Ypos = evnt.Ypos;
		  % 		  info.Zpos = evnt.Zpos;
		  % 		  info.ViewAngle = evnt.ViewAngle;
		  % 		  info.ForwardVelocity = evnt.ForwardVelocity;
		  % 		  info.RotationalVelocity = evnt.RotationalVelocity;
		  %       info.Velocity = evnt.Velocity;
		  info.Time = evnt.Time;
		  data = evnt.Data;
		  % may need to check frame number?
		  if isclosed(obj.currentDataFile)
			 if ~issaved(obj.currentDataFile)
				obj.saveDataFile;
				% if file closes somehow, it will save on the next frame and open a new file
				% e.g. if someone access data while it's open, it will close... ?
			 end
			 obj.currentDataFile = VideoFile(...
				'rootPath',obj.currentDataSetPath,...
				'experimentName',obj.currentExperimentName);
		  end
		  addFrame2File(obj.currentDataFile,data,info);
		catch me
		  obj.lastError = me;
		end
		% REWARD GOOD BEHAVIOR
		try
		  rewardEvaluated = eval(obj.rewardCondition);
		catch
		  rewardEvaluated = obj.rewardCondition;
		end
		if rewardEvaluated
		  obj.rewardPulseObj.sendPulse();
		  obj.numRewardsGiven = obj.numRewardsGiven + 1;
		  fprintf('NumRewards %g\n',obj.numRewardsGiven)
		  % NewTrial event moved instead to end of delay period in
		  % runtimeCodeFun
		  %                 notify(obj,'NewTrial');
		end
	 end
	 function autoSyncTimerFcn(obj,~,~)
		obj.numRewardsMissed = obj.numRewardsMissed + 1;
		notify(obj,'NewTrial')
	 end
  end
  methods % SET
	 function set.experimentSyncObj(obj,bhv)
		if ~isempty(obj.experimentStateListener)
		  obj.experimentStateListener.Enabled = false;
		end
		obj.experimentSyncObj = bhv;
		obj.experimentStateListener = addlistener(obj.experimentSyncObj,...
		  'ExperimentStart',@(src,evnt)experimentStateChangeFcn(obj,src,evnt));
		addlistener(obj.experimentSyncObj,...
		  'ExperimentStop',@(src,evnt)experimentStateChangeFcn(obj,src,evnt));
		obj.experimentStateListener.Enabled = true;
	 end
	 function set.trialSyncObj(obj,bhv)
		obj.trialSyncObj = bhv;
		if ~isempty(obj.trialStateListener)
		  obj.trialStateListener.Enabled = false;
		end
		obj.trialStateListener = addlistener(obj.trialSyncObj,...
		  'NewTrial',@(src,evnt)trialStateChangeFcn(obj,src,evnt));
		obj.trialStateListener.Enabled = false;
		
	 end
	 function set.frameSyncObj(obj,cam)
		if ~isempty(obj.frameSyncListener)
		  obj.frameSyncListener.Enabled = false;
		end
		obj.frameSyncObj = cam;
		% Define Listener
		obj.frameSyncListener = addlistener(obj.frameSyncObj,...
		  'FrameAcquired',@(src,evnt)frameAcquiredFcn(obj,src,evnt));
		obj.frameSyncListener.Enabled = false;
	 end
  end
  methods
	 function delete(obj)
		try
		  obj.saveDataSet();
		  delete(obj.clockPulseObj);
		  % 		  delete(obj.startPulseObj);
		  % 		  delete(obj.rewardPulseObj);
		catch me
		  disp(me.message)
		end
	 end
  end
  
end

