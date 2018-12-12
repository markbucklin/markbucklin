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
	end
	
	% 	% ##################################################
	% 	% BENCHMARKS
	% 	% ##################################################
	% 	properties (SetAccess = ?ignition.core.Object)
	% 		LastTimePerFrame
	% 		MeanTimePerFrame
	% 		MinTimePerFrame
	% 		MaxTimePerFrame
	% 		NumFramesBenchmarkedCount = 0
	% 	end
	
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
			
			if isnumeric(F)
				checkNumericInput(F)
				
			elseif isa(F,'ignition.core.type.VideoBaseType')
				checkStructuredInput(F)
				
			end
			
			% GPU
			if isempty(obj.UseGpu)
				obj.UseGpu = isOnGpu(obj, F); %isa(F,'gpuArray');
			end
			if obj.UseGpu
				if ~isa(F, 'gpuArray')
					F = gpuArray(F);
				end
				% TODO: check if exists on current gpu -> for multigpu
				
			end
			
			% DATA-TYPE
			obj.InputDataType = ignition.shared.getDataType( F);
			
			if obj.UseFloatingPoint && ~strcmp(obj.InputDataType, obj.Precision)
				F = cast(F, obj.Precision);
			end
			
			% UPDATE FRAME INPUT COUNTER (PREINCREMENTED)
			obj.NumFramesInputCount = obj.NumFramesInputCount + numFrames;
			
			
			function checkStructuredInput(fseg)
				
				obj.FrameSize = getFrameSize(fseg);
				obj.MaxFramesPerStep = ignition.shared.initOrUpdate( @max, obj.MaxFramesPerStep, fseg.NumFrames);
				% 				checkNumericInput(fseg.FrameData)
				% TODO: just pull from props?
				
			end
			function checkNumericInput(f)
				% INPUT DIMENSIONS
				[numRows, numCols, numChans, numFrames] = size(f);
				if isempty(obj.FrameSize)
					obj.FrameSize = [numRows numCols numChans];
				end
				obj.MaxFramesPerStep = ignition.shared.initOrUpdate( @max, obj.MaxFramesPerStep, numFrames);
				% 				if ~isempty(obj.MaxFramesPerStep)
				% 					obj.MaxFramesPerStep = numFrames;
				% 				else
				% 					obj.MaxFramesPerStep = max( numFrames, obj.MaxFramesPerStep); %TODO
				% 				end
				
				% RANGE
				% 				fMin = ignition.shared.onCpu( min(f(:)));
				% 				fMax = ignition.shared.onCpu( max(f(:)));
				% 				if ~isempty(obj.InputRange)
				% 					curMin = obj.InputRange(1);
				% 					curMax = obj.InputRange(2);
				% 					obj.InputRange = [ min(fMin, curMin) , max(fMax, curMax) ];
				% 				else
				% 					obj.InputRange = [ fMin, fMax ];
				% 				end
				
				% 			if ismethod(obj, 'processData')
				% 				fprintf('superclass processdata call from checkInput\n')
				% 				output = processData(obj, data);
				% 				obj.OutputDataType = getClass(obj, output);
				
				
			end
		end
		function varargout = runMainTask(obj, F, varargin)
			% Default method for running main task. Can be used if system defines main task property with
			% function handle, or cell array of function handles.
			
			try
				numOut = getNumOutputs(obj);
				fcn = obj.MainTaskFcn;
				in = [{F}, varargin{:}];
				
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
	% MATLAB SYSTEM METHODS
	% ##################################################
	methods (Access = protected)
		function validateInputsImpl(obj, varargin)
			%TODO
		end
		function setupImpl(obj, F, varargin) %TODO: just varargin?
			
			fprintf('VideoStreamProcessor: setupImpl()\n')
			notify(obj, 'Initializing')
			
			try
				% Called by Setup(obj, F) or on first call to Step(obj, F)
				
				% INITIALIZATION (STANDARD)
				initializeModuleEnvironment() % defined in core Module class only
				initialize(obj) % defined in core Module class or derived class
				checkInput(obj, F);
				getNumOutputs(obj);
				
				notify(obj, 'Ready')
				
			catch me
				% 				notify(obj, 'Error')
				% 				rethrow(me)%TODO
				handleError(obj, me)
			end
		end
		function varargout = stepImpl(obj, F, varargin)
			try
				notify(obj, 'Processing')
				
				% PRE-PROCEDURE TASKS
				F = checkInput(obj, F, varargin{:});
				numOut = min( getNumOutputs(obj), nargout);
				argsOut = cell(1,numOut);
				
				startTic = tic;
				
				% RUN MAIN PROCEDURE
				[argsOut{1:numOut}] = runMainTask(obj, F, varargin{:});
				
				
				% POST-PROCEDURE TASKS
				procTime = toc(startTic);
				addBenchmark(obj.PerformanceMonitorObj, procTime, getNumFrames(F));
				
				% 				F = checkOutput(obj, F);%TODO
				if ~isempty(argsOut)
					[argsOut{:}] = checkOutput(obj, argsOut{:});%TODO
				end
				
				varargout = argsOut;
				
				notify(obj, 'Ready')
				
			catch me
				handleError(obj, me)
				% 				notify(obj, 'Error')
				% 				rethrow(me)%TODO
			end
		end
		function resetImpl(obj)
			
			notify(obj, 'Reset');
			
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
		% TODO: check that these are functional
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















