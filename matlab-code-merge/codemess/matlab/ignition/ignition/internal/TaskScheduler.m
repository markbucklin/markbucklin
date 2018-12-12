classdef (CaseInsensitiveProperties, TruncatedProperties) TaskScheduler < timer
	%TASKSCHEDULER Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	
	properties (SetAccess = protected)
		TimerObj
		TaskFcn
		TaskInput
		TaskOutput
		NumTaskOutputs
		Priority
	end
	
	
	
	
	
	
	
	methods
		function obj = TaskScheduler()
			
			
		end
	end
	methods
		function createTimerObj(obj)
			% 			if nargin < 1
			% 				t = timer;
			% 			end
			% 			set(t, ...
			% 				'ExecutionMode', 'fixedDelay',...
			% 				'Period', framePeriod, ...
			% 				'StartDelay', framePeriod,...
			% 				'TimerFcn', @playNextFrame, ...
			% 				'BusyMode', 'drop',...
			% 				'ErrorFcn', @(src,envt) delete(src));%,...
			
			
			
% 			jobject = handle(com.mathworks.timer.TimerTask); 
% 			obj.TimerObj = timer.wrapJavaTimerObjs(jobject);
			
			obj.TimerObj = timer(...
				'ExecutionMode', 'singleShot',...				
				'TimerFcn', @(src,evnt)executeTask(obj,src,evnt), ...				
				'ErrorFcn', @sendErrorToBase);
			
			% 			'StopFcn', @deleteTimer, ...
			% 			tCreate = tic;
			
			% 			function deleteTimer(src, ~)
			% 				delete(src)
			% 			end
			function sendErrorToBase(src,evnt)
				fprintf('An error occurred : src,evnt sent to base workspace\n')
				assignin('base','src',src);
				assignin('base','evnt',evnt);
			end
			
		end
		function timerStatus = isRunning(obj)
			frameTimer = obj.TimerObj;
			if ~isempty(frameTimer) && isvalid(frameTimer)
				timerStatus = strcmpi(frameTimer.Running, 'on');
			else
				timerStatus = false;
			end
		end
		function deleteTimerObj(obj)
			if ~isempty(obj.TimerObj) && isvalid(obj.TimerObj)
				if isRunning(obj)
					stop(obj.TimerObj)
				end
				delete(obj.TimerObj);
			end
		end
	end
	methods
		function executeTaskFcn(obj, src, evnt)
			
			% tExecuteStart = tic;
			
			numOut = obj.NumTaskOutputs;
			fcn = obj.TaskFcn;
			argsIn = obj.TaskInput;
			obj.TaskOutput = feval( fcn, numOut, argsIn);
			
			
				
		end
	end
	
	
	
	
	
	
end

