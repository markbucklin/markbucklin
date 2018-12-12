classdef (CaseInsensitiveProperties, TruncatedProperties) VideoStreamProcessor < ignition.core.Object & matlab.System
% VideoStreamProcessor - Interface to 'matlab.System' type module
	
	
	% ##################################################
	% SETTINGS
	% ##################################################
	properties (Nontunable, Logical)
		UseFloatingPoint = true;
	end
	properties (Nontunable)
		Precision = 'single'
	end
	properties (Logical)
		Enabled = true % todo
	end
	
	% ##################################################
	% INPUT/OUTPUT CHARACTERISTICS
	% ##################################################
	properties (SetAccess = ?ignition.core.Object)
		% 		InputRange
		% 		OutputRange
	end
	properties (SetAccess = ?ignition.core.Object, Nontunable)
		InputDataType
		OutputDataType
		FrameSize
		FrameDimension = 4 % TimeDimension
		MaxFramesPerStep
		NumInputPorts
		NumOutputPorts
		InputPortProps
		OutputPortProps
		MainTaskFcn
	end
	properties (SetAccess = ?ignition.core.Object)
		NumFramesInputCount = 0
		NumFramesOutputCount = 0
	end
	
	% ##################################################
	% PRIVATE/INTERNAL
	% ##################################################
	properties (Nontunable, Access = ?ignition.core.Object, Hidden)
		PrecisionSet = matlab.system.StringSet({'single','double'})
	end
	
	
	
	
	
	methods 
		function obj = VideoStreamProcessor()
			fprintf('VideoStreamProcessor: Constructor\n')
		end
	end
	
	% ##################################################
	% SHARED ROUTINE: INPUT -> MAINTASK -> OUTPUT
	% ##################################################
	methods (Access = ?ignition.core.Object)
		function F = checkInput(obj, F)
						
			% TRANSFER TO GPU IF SPECIFIED
			if isempty(obj.UseGpu)
				obj.UseGpu = isOnGpu(obj, F); %isa(F,'gpuArray');
			end
			if obj.UseGpu
				if ~isa(F, 'gpuArray')
					F = gpuArray(F); % TODO: check if exists on current gpu -> for multigpu
				end				
			end
			
			% DATA-TYPE
			if obj.UseFloatingPoint && ~isa(F, obj.Precision)
				F = cast(F, obj.Precision);
			end
			
		end
		function varargout = runMainTask(obj, varargin)
			% Default method for running main task. Can be used if system defines main task property with
			% function handle, or cell array of function handles.
			
			try
				numOut = getNumOutputs(obj);
				fcn = obj.MainTaskFcn;
				in = varargin;
				% 				in = [{F}, varargin{:}];
				
				if ~isempty(fcn)
					if isa(fcn, 'function_handle')
						% 					fcnInfo = getcallinfo(fcn); functions(fcn)
						out = feval(fcn, in{:});%[F, varargin{:}]
						
					elseif iscell(fcn)
						%TODO
					else
						
					end
					varargout = out(1:numOut);
					%TODO
				end
				
			catch me
				handleError(me)
			end
		end	
	end
	
	% ##################################################
	% MATLAB SYSTEM METHODS (IMPLEMENTATIONS)
	% ##################################################
	methods (Access = protected)		
		function setupImpl(obj, varargin)
			% setupImpl - Called by setup(obj, F) or on first call to step(obj, F)
			
			% FIRE EVENT -> INITIALIZING
			notify(obj, 'Initializing')
			
			try				
				% INITIALIZATION (STANDARD)
				initializeModuleEnvironment() % defined in core Module class only
				initialize(obj) % defined in core Module class or derived class				
				getNumOutputs(obj);
				
			catch me
				handleError(obj, me)
			end
			
			% FIRE EVENT -> READY
			notify(obj, 'Ready')
			
		end
		function validateInputsImpl(obj, varargin)
			
			% CHECK FOR EMPTY INPUT & EXPECT FIRST ARGUMENT IS VIDEO SEGMENT DATA
			if nargin
				F = varargin{1};
			else
				return
			end
			
			% INPUT DATA-TYPE
			obj.InputDataType = ignition.shared.getDataType( F);
			
			% INPUT DATA SIZE/DIMENSIONS
			[numRows,numCols,numChannels] = ignition.shared.getFrameSize(F);
			obj.FrameSize = [numRows,numCols,numChannels];
			
			% GET NUMBER OF FRAMES IN INPUT -> MAX FRAMES-PER-STEP
			numFrames = ignition.shared.getNumFrames(F);			
			obj.MaxFramesPerStep = ignition.shared.initOrUpdate( @max, obj.MaxFramesPerStep, numFrames);
			
			% UPDATE FRAME INPUT COUNTER (PREINCREMENTED)
			obj.NumFramesInputCount = obj.NumFramesInputCount + numFrames;
						
		end
		function varargout = stepImpl(obj, varargin)
			
			% FIRE EVENT -> PROCESSING
			notify(obj, 'Processing')
			
			try							
				% ------------------------------
				% PRE-PROCEDURE TASKS
				% ------------------------------
				if nargin
					F = varargin{1};
				else
					F = [];
				end
				
				% GET NUMBER OF FRAMES IN INPUT
				numFrames = ignition.shared.getNumFrames(F);
				numOut = min( obj.NumOutputPorts, nargout);
				% 				numIn =
				
				% UPDATE FRAME INPUT COUNTER (PREINCREMENTED)
				argsIn = varargin;
				obj.NumFramesInputCount = obj.NumFramesInputCount + numFrames;				
				argsOut = cell(1,numOut);
				
				% ------------------------------
				% RUN MAIN PROCEDURE
				% ------------------------------
				startTic = tic;
				[argsOut{1:numOut}] = runMainTask(obj, argsIn{:});
				addBenchmark(obj.PerformanceMonitorObj, toc(startTic), numFrames);
				
				% ------------------------------
				% POST-PROCEDURE TASKS
				% ------------------------------
				obj.NumFramesOutputCount = obj.NumFramesOutputCount + numFrames;
				varargout = argsOut;
				
			catch me
				handleError(obj, me)
			end
			
			% FIRE EVENT -> READY
			notify(obj, 'Ready')
			
		end
		function resetImpl(obj)
			% resetImpl - Called by reset() only if object is locked, and by setup() after call to
			% setupImpl() method.
			
			% TODO 			notify(obj, 'Reset');
			try
				if obj.UseGpu
					pushGpuPropsBack(obj)
				end
			catch me
				handleError(obj, me)
			end				
			
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
		function numOutputs = getNumOutputsImpl(obj)
			% Returns the number of '__OutputPort' properties set to true -> max number of outputs returned
			if isempty(obj.NumOutputPorts) || isempty(obj.OutputPortProps)
				mobj = metaclass(obj);
				mprop = mobj.PropertyList;
				propNames = {mprop.Name};
				isOutProp = ~cellfun(@isempty, regexp(propNames, '(\w*)OutputPort\>') );
				obj.OutputPortProps = mprop(isOutProp);
				obj.NumOutputPorts = nnz(isOutProp);
			end
			outPortPropNames = {obj.OutputPortProps(:).Name};
			numOutputs = 0;
			k = 0;
			while (k < numel(outPortPropNames))
				k = k + 1;
				if obj.(outPortPropNames{k})
					numOutputs = numOutputs + 1;
				end
			end
		end
		function s = saveObjectImpl(obj)
			s = saveObjectImpl@matlab.System(obj);
			if isLocked(obj)
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			if ~isempty(obj.ChildSystem)
				for k=1:numel(obj.ChildSystem)
					s.ChildSystem{k} = matlab.System.saveObject(obj.ChildSystem{k});
				end
			end
		end
		function loadObjectImpl(obj,s,wasLocked)
			if wasLocked
				% Load child System objects
				if ~isempty(s.ChildSystem)
					for k=1:numel(s.ChildSystem)
						obj.ChildSystem{k} = matlab.System.loadObject(s.ChildSystem{k});
					end
				end
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				% 		 oProps = oProps(~strcmp({oProps.GetAccess},'private'));
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			% Call base class method to load public properties
			loadObjectImpl@matlab.System(obj,s,[]);
		end
	end
	
	
	
	
	
	
end































