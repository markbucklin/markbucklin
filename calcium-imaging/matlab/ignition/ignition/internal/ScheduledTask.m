classdef (CaseInsensitiveProperties, TruncatedProperties) ScheduledTask < handle
	%ScheduledTask Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	
	% SETTINGS
	properties
		Priority
	end
	
	% INPUT & OUTPUT
	properties (SetAccess = protected)
		TaskFcnHandle @function_handle
		NumArgsOut
		TaskInput @cell
		TaskOutput @cell
		ErrorOutput
		IsFinished = false
	end
	
	% TIMER OBJECTS
	properties (SetAccess = protected)
		MatlabTimerObj
		JavaTimerObj
	end
	
	
	
	
	events
		Finished
	end
	
	
	
	
	methods
		function obj = ScheduledTask( taskFcnHandle, numArgsOut, varargin)
			
			obj.JavaTimerObj = handle(com.mathworks.timer.TimerTask);
			obj.MatlabTimerObj = timer.wrapJavaTimerObjs( obj.JavaTimerObj );
			
			obj.MatlabTimerObj.ExecutionMode = 'fixedDelay';
			obj.MatlabTimerObj.StartDelay = .005;
			obj.MatlabTimerObj.TasksToExecute =  2;
			obj.MatlabTimerObj.Period = .005;
			obj.MatlabTimerObj.BusyMode = 'queue';
			obj.MatlabTimerObj.ErrorFcn = @(src,evnt)logTaskError(obj,src,evnt);
			obj.MatlabTimerObj.StopFcn = @(src,evnt)setStateFinished(obj,src,evnt);
			
			if nargin < 2
				numArgsOut = 0;
				% 			else
				% 				obj.NumArgsOut = numArgsOut;
			end
			if nargin > 0
				schedule(obj, taskFcnHandle, numArgsOut, varargin{:})
			end
			
		end
		function schedule(obj, taskFcnHandle, numArgsOut, varargin)
			
			if nargin < 4
				taskInput = obj.TaskInput;
			else
				taskInput = varargin;
			end
			if (nargin < 3) 
				numArgsOut = obj.NumArgsOut;
				if (nargin < 2)
					taskFcnHandle = obj.TaskFcnHandle;
				end
			end
			% todo: check empty		
			
			
			obj.MatlabTimerObj.TimerFcn = @runTaskFcn;
			start(obj.MatlabTimerObj)
			
			obj.TaskInput = taskInput;
			obj.NumArgsOut = numArgsOut;
			obj.TaskFcnHandle = taskFcnHandle;
			
			function runTaskFcn(src,~)
				if src.TasksExecuted >= 1
					if numArgsOut >= 1
						taskOutput = cell(1,numArgsOut);
						[taskOutput{:}] = feval( taskFcnHandle, taskInput{:} );
						setTaskOutput(obj, taskOutput);
						notify(obj, 'Finished')
					else
						feval( taskFcnHandle, taskInput{:} );
					end
				end
				
				
			end
		end
		function reschedule(obj, varargin)
			% >> reschedule(obj, newInput)
			obj.IsFinished = false;
			if nargin > 1
				schedule(obj, obj.TaskFcnHandle, obj.NumArgsOut, varargin{:});%todo:check cell
			else
				schedule(obj, obj.TaskFcnHandle, obj.NumArgsOut);
			end
				
		end
		function delete(obj)
			try
				delete(obj.MatlabTimerObj)
				dispose(obj.JavaTimerObj)
				delete(obj.JavaTimerObj)
			catch
			end
		end
	end
	methods (Hidden)
		function setTaskOutput(obj, taskOutput)
			obj.TaskOutput = taskOutput;
		end
	end
	methods
		function timerStatus = isRunning(obj)
			tObj = obj.MatlabTimerObj;
			if ~isempty(tObj) && isvalid(tObj)
				timerStatus = strcmpi(tObj.Running, 'on');
			else
				timerStatus = false;
			end
		end
		function deleteTimerObj(obj)
			if ~isempty(obj.MatlabTimerObj) && isvalid(obj.MatlabTimerObj)
				if isRunning(obj)
					stop(obj.MatlabTimerObj)
				end
				delete(obj.MatlabTimerObj);
			end
		end
	end
	methods (Access = protected)
		function logTaskError(~,~,~)
			
		end
		function setStateFinished(obj,~,~)
			obj.IsFinished = true;
		end
	end
	
	
	
	
	
	
end

