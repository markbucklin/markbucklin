classdef (CaseInsensitiveProperties, TruncatedProperties) DeferredTask < handle
	%DeferredTask Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	
	% SETTINGS
	properties
		Priority % TODO
	end
	
	% INPUT & OUTPUT
	properties (SetAccess = protected)
		TaskFcnHandle @function_handle
		NumArgsOut = 0
		TaskInput @cell
		TaskOutput @cell
		ErrorOutput
		IsFinished = false
		QueuedTaskInput @cell
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
		function obj = DeferredTask( taskFcnHandle, numArgsOut, varargin)
			
			% CONSTRUCT INTERNAL TIMERS (JAVA)
			obj.JavaTimerObj = handle(com.mathworks.timer.TimerTask);
			obj.MatlabTimerObj = timer.wrapJavaTimerObjs( obj.JavaTimerObj );
			
			% ASSIGN INPUT ARGUMENTS TO PROPERTIES (IF PROVIDED)
			if (nargin > 0)
				obj.TaskFcnHandle = taskFcnHandle;				
				if (nargin > 1)
					obj.NumArgsOut = numArgsOut;
				end				
			end
			
			% CONFIGURE TIMER FOR SINGLE DEFERRED EXECUTION OF TASK FUNCTION
			setupMatlabTimer(obj)			
			
			% 			if (nargin > 0) && (~isempty(taskFcnHandle))
			
			% 			end
			
		end
		function schedule(obj, taskFcnHandle, numArgsOut, varargin) % todo: rename dispatch
			%		>> schedule(obj, taskFcnHandle, numArgsOut, varargin{:})
			%		>> schedule(obj)
				
			% ASSIGN LOCAL VARIABLES
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
			timerObj = obj.MatlabTimerObj; % todo: check empty				
			
			% QUEUE DATA IF TIMER IS ALREADY RUNNING						
			if isRunning(obj) % ~obj.IsFinished %strcmpi(timerObj.Running, 'on')				
				obj.QueuedTaskInput = [obj.QueuedTaskInput, taskInput];
				nextTaskFcn = @runTaskFcn;
				timerObj.StopFcn = @queueNextTask;
			else
				timerObj.TimerFcn = @runTaskFcn;
				start(timerObj)
				
				% unnecessary????
				obj.TaskInput = taskInput;
				obj.NumArgsOut = numArgsOut;
				obj.TaskFcnHandle = taskFcnHandle;
				
			end
			
			
			
			function runTaskFcn(src,~)
				if src.TasksExecuted >= 1
					if numArgsOut >= 1
						taskOutput = cell(1,numArgsOut);
						[taskOutput{:}] = feval( taskFcnHandle, taskInput{:} );
						setTaskOutput(obj, taskOutput);						
					else
						feval( taskFcnHandle, taskInput{:} );
					end
					notify(obj, 'Finished')
					% todo: attach listener for chaining/queueing tasks
				end				
				
			end
			function queueNextTask(src,~)
				queue = obj.QueuedTaskInput;
				if ~isempty(queue)
					obj.TaskInput = taskInput;
					obj.NumArgsOut = numArgsOut;
					obj.TaskFcnHandle = taskFcnHandle;
					% 					obj.TaskInput = queue{1};
					% obj.TaskInput = taskInput % unnecessary????
					src.TimerFcn = nextTaskFcn;					
					
					% REMOVE FROM QUEUE
					queue(1) = [];					
					obj.QueuedTaskInput = queue;					
					
					% RESTART TIMER
					start(src)
					
				else
					src.StopFcn = '';
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
		function logTaskError(~,src,evnt)
			% todo
			fprintf('An error occurred : src,evnt sent to base workspace\n')
			assignin('base','src',src);
			assignin('base','evnt',evnt);
		end
		function setStateFinished(obj,~,~)
			obj.IsFinished = true;
		end
		function setupMatlabTimer(obj)
			obj.MatlabTimerObj.ExecutionMode = 'fixedDelay';
			obj.MatlabTimerObj.StartDelay = .001;
			obj.MatlabTimerObj.TasksToExecute =  2;
			obj.MatlabTimerObj.Period = .001;
			obj.MatlabTimerObj.BusyMode = 'queue';
			obj.MatlabTimerObj.ErrorFcn = @(src,evnt)logTaskError(obj,src,evnt);
			obj.MatlabTimerObj.StopFcn = @(src,evnt)setStateFinished(obj,src,evnt);
		end
	end
	
	
	
	
	
	
end

% jo = com.mathworks.jmi.Callback
% set(jo,'DelayedCallback', @(varargin)fprintf('time is %f\n',now))
% jo.postCallback
% 
% 
% then = now; 
% set(jo,'DelayedCallback', @(varargin)fprintf('time passed: %f\n',now-then));
% jo.postCallback