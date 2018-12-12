classdef (CaseInsensitiveProperties, TruncatedProperties) StreamTask < handle
	%StreamTask Reference to properties of current computational environment
	%   TODO:Details
	
	
	
	
	% SETTINGS
	properties
		Priority %todo
	end
	properties (SetAccess = immutable)
		Name = ''
	end
	properties
		Enabled @logical scalar = true % todo
	end
	
	% FUNCTION HANDLES
	properties (SetAccess = protected)
		ConfigurationFcn @function_handle
		InitializationFcn @function_handle
		MainTaskFcn @function_handle
	end
	
	% INPUT/OUTPUT
	properties (SetAccess = protected)
		Configuration @struct
		State
		NumInputChannels = 0
		NumOutputChannels = 0
		TaskInput @cell
		TaskOutput @cell
		StreamInputBuffer @ignition.core.Buffer
		StreamOutputBuffer @ignition.core.Buffer
		ErrorOutput
		IsFinished = false
	end
	
	
	
	events
		Finished
	end
	
	
	
	
	methods
		function obj = StreamTask( taskFcnHandle, numArgsOut, varargin)
			
			% ASSIGN INPUT ARGUMENTS TO PROPERTIES (IF PROVIDED)
			if (nargin > 0)
				obj.MainTaskFcn = taskFcnHandle;				
				if (nargin > 1)
					obj.NumOutputChannels = numArgsOut;
				end				
			end
			
			
		end
		function configure(obj, taskFcnHandle, numArgsOut, varargin)
			%		>> schedule(obj, taskFcnHandle, numArgsOut, varargin{:})
			%		>> schedule(obj)
			if nargin < 4
				taskInput = obj.TaskInput;
			else
				taskInput = varargin;
			end
			if (nargin < 3) 
				numArgsOut = obj.NumOutputChannels;
				if (nargin < 2)
					taskFcnHandle = obj.MainTaskFcn;
				end
			end
			
			obj.TaskInput = taskInput;
			obj.NumOutputChannels = numArgsOut;
			obj.MainTaskFcn = taskFcnHandle;
			
				
		end
		function reschedule(obj, varargin)
			% >> reschedule(obj, newInput)
			obj.IsFinished = false;
			if nargin > 1
				schedule(obj, obj.MainTaskFcn, obj.NumOutputChannels, varargin{:});%todo:check cell
			else
				schedule(obj, obj.MainTaskFcn, obj.NumOutputChannels);
			end
				
		end
		function delete(obj)
			try
				notify(obj, 'Finished')
			catch
			end
		end
	end
	methods (Hidden)
		function setTaskOutput(obj, taskOutput)
			obj.TaskOutput = taskOutput;
		end
	end
	methods (Access = protected)
		function logTaskError(~,src,evnt)
			% todo
			fprintf('An error occurred : src,evnt sent to base workspace\n')
			assignin('base','src',src);
			assignin('base','evnt',evnt);
		end
	end
	
	
	
	
	
	
end

