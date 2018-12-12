classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		DataflowProcessor < ignition.core.Task
% 		DataflowProcessor < ignition.core.Object & handle & matlab.mixin.CustomDisplay
	
	
	
	
	
	% CONFIGURATION
	properties
	end
		
	% CONTROL
	properties
	end
	
	% STATE
	properties
	end
	
	% COMMON CONTROL
	properties
		Priority = 0
		Enabled = false
		NextExecutionDeadline @double %todo -> use class that supports scheduling + type(hard/soft)
		DispatchType @ignition.core.FunctionDispatchType
	end
	
	% IO
	properties (SetAccess = protected)
		InputStream
		OutputStream
	end
	
	properties (SetAccess = protected) % Hidden
		ConfigureTask @ignition.core.Task
		IsConfigured = false
		InitializeTask @ignition.core.Task
		IsInitialized = false
	end
	properties (SetAccess = protected) % Hidden
		TaskList @ignition.core.Task
		LinkList @ignition.core.tasks.TaskLink
		TaskData @struct
		TaskConfiguration @struct
		ConfigurationInterface
		ControlInterface
		StateInterface
	end
	
	% todo -> 
	%		PerformanceMonitorObj
	
	
	
	
	
	
	
	methods
		function obj = DataflowProcessor( varargin )
			
			% CALL TASK CONSTRUCTOR						
			%fcn = @(f)write(streamOut, f);			
			%fcn = @()execute(obj);
			fcn = @noop; % @ignition.shared.nullFcn;
			argsIn = [{fcn} , varargin];
			obj = obj@ignition.core.Task(argsIn{:});
			
			% IO STREAMS
			streamOut = ignition.core.FrameBuffer;			
			obj.OutputStream = streamOut;			
			
			% INITIALIZE WITH DEFAULT CONFIGURATION
			if isempty(obj.TaskConfiguration)
				obj.TaskConfiguration = getStructFromPropGroup(obj, 'configuration');
			end
			
			import ignition.core.TaskInterface
			obj.ConfigurationInterface = TaskInterface.buildFromObjectPropertyGroup(obj,'configuration');
			obj.ControlInterface = TaskInterface.buildFromObjectPropertyGroup(obj,'control');
			obj.StateInterface = TaskInterface.buildFromObjectPropertyGroup(obj,'state');
			
		end
		function attachInputStream(obj, streamIn)
			%streamIn = ignition.core.FrameBuffer;
			%obj.InputStream = streamIn;
			if isempty(obj.InputStream)
				obj.InputStream = streamIn;
			else
				obj.InputStream = [obj.InputStream ; streamIn];
			end
		end
	end
	
	methods
		function configure(obj)
			% Runs a 'ConfigureTask' adhering to the format:
			%			>> config = myconfigfcn( val1, val2, ...)
			
			% 			% INITIALIZE TO EMPTY STRUCTURE
			% 			config = struct.empty();
			%
			% 			% RUN SPECIFIC CONFIGURE-FUNCTION
			% 			if ~isempty(obj.ConfigureTask)
			% 				argsIn = [ {obj.ConfigureTask} , getConfigurationValues(obj)];
			% 				config = feval( argsIn{:} );
			% 				obj.TaskConfiguration = config;
			% 			end
			%
			% 			% UPDATE PROPERTY VALUES BY COPYING FROM STRUCTURE
			% 			fillPropsFromStruct(obj, config);
			if ~isempty(obj.ConfigureTask)
				execute(obj.ConfigureTask)
				out = obj.ConfigureTask.Output;
				for k=1:numel(out)
					data = out.Data;
					if isstruct(data)
						try
							fillPropsFromStruct(obj, data);
						catch
						end
					end
				end
			end
			obj.IsConfigured = true;
			
		end
		function initialize(obj)
			% Runs an 'InitializeTask' adhering to the format:
			%			>> taskData = myinitfcn( config, in1, in2, ...)
			% where config is also updated and copied into the cached/shared
			
			% 			% INITIALIZE TO EMPTY STRUCTURE
			% 			initTaskData = struct.empty();
			%
			% 			% RUN SPECIFIC CONFIGURE-FUNCTION
			% 			if ~isempty(obj.InitializeTask)
			% 				argsIn = [ {obj.InitializeTask} , obj.TaskConfiguration , varargin{:}]; %obj.InputArguments];
			% 				initTaskData = feval( argsIn{:} );
			% 				obj.TaskData = initTaskData;
			% 			end
			%
			% 			% UPDATE PROPERTY VALUES BY COPYING FROM STRUCTURE
			% 			fillPropsFromStruct(obj, initTaskData);
			if ~obj.IsConfigured
				configure(obj)
			end				
			if ~isempty(obj.InitializeTask)
				execute(obj.InitializeTask)
				out = obj.InitializeTask.Output;
				for k=1:numel(out)
					data = out.Data;
					if isstruct(data)
						try
							fillPropsFromStruct(obj, data);
						catch
						end
					end
				end
			end
			obj.IsInitialized = true;
		end
		function execute(obj)
			if ~obj.IsInitialized
				initialize(obj)
			end
			if ~isempty(obj.TaskList)
				execute(obj.TaskList)
			end
			
		end
	end
	
	
	methods
		function delete(obj)
			tryDelete(obj.TaskList)
			tryDelete(obj.ConfigurationInterface)
			tryDelete(obj.ControlInterface)
			tryDelete(obj.StateInterface)
			tryDelete(obj.OutputStream)
						
			function tryDelete(o)
				try
					delete(o)
				catch
				end					
			end
		end
	end
	
	
	
	methods (Access = protected)		
		function configVals = getConfigurationValues(obj)
			% configVals = getConfigurationValues(obj)
			% Return the values stored in properties labeled 'CONFIGURATION' in cell array
			configVals = {};
			s = getStructFromPropGroup(obj, 'configuration');
			if ~isempty(s)
				configVals = struct2cell(s);
			end
		end
		function me = handleError(obj, me)
			% 		function logTaskError(~,src,evnt)
			% todo
			
			% todo: handleError(obj, futureObj)
			
			% 			fprintf('An error occurred : src,evnt sent to base workspace\n')
			% 			assignin('base','src',src);
			% 			assignin('base','evnt',evnt);
			notify(obj, 'Error')
			rethrow(me); %TODO
		end
	end
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
end





function noop()
end



