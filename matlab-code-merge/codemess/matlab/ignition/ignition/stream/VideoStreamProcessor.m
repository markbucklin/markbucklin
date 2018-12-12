classdef (CaseInsensitiveProperties, TruncatedProperties) VideoStreamProcessor < ignition.system.SystemInterface
	
	
	
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
	properties (SetAccess = ?ignition.system.SystemInterface)
		InputRange
		OutputRange
	end
	properties (SetAccess = ?ignition.system.SystemInterface, Nontunable)
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
	properties (SetAccess = ?ignition.system.SystemInterface)
		NumFramesInputCount = 0
	end
	
	% ##################################################
	% BENCHMARKS
	% ##################################################
	properties (SetAccess = ?ignition.system.SystemInterface)
		LastTimePerFrame
		MeanTimePerFrame
		MinTimePerFrame
		MaxTimePerFrame
	end
	
	% ##################################################
	% PRIVATE/INTERNAL
	% ##################################################
	properties (Nontunable, Access = ?ignition.system.SystemInterface, Hidden)
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
	methods (Access = ?ignition.system.SystemInterface)
		function F = checkInput(obj, F)
			
			if isnumeric(F)
				checkNumericInput(F)
				
			elseif isa(F,'VideoSegment')
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
			obj.InputDataType = getPixelDataType(obj, F);
			
			if obj.UseFloatingPoint && ~strcmp(obj.InputDataType, obj.Precision)
				F = cast(F, obj.Precision);
			end
			
			% UPDATE FRAME INPUT COUNTER (PREINCREMENTED)
			obj.NumFramesInputCount = obj.NumFramesInputCount + numFrames;
			
			
			function checkStructuredInput(fseg)
				
				checkNumericInput(fseg.FrameData)
				% TODO: just pull from props?
				
			end
			function checkNumericInput(f)
				% INPUT DIMENSIONS
				[numRows, numCols, numChans, numFrames] = size(f);
				if isempty(obj.FrameSize)
					obj.FrameSize = [numRows numCols numChans];
				end
				if ~isempty(obj.MaxFramesPerStep)
					obj.MaxFramesPerStep = numFrames;
				else
					obj.MaxFramesPerStep = max( numFrames, obj.MaxFramesPerStep); %TODO
				end
				
				% RANGE
				fMin = onCpu(obj, min(f(:)));
				fMax = onCpu(obj, max(f(:)));
				if ~isempty(obj.InputRange)
					curMin = obj.InputRange(1);
					curMax = obj.InputRange(2);
					obj.InputRange = [ min(fMin, curMin) , max(fMax, curMax) ];
				else
					obj.InputRange = [ fMin, fMax ];
				end
				
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
		function varargout = checkOutput(obj, varargin)
			
			% DIMENSIONS/SIZE
			% 			[numRows, numCols, numChans, numFrames] = size(F);
			
			if nargin > 1
				F = varargin{1};
				
				% DATA-TYPE
				if isempty(obj.OutputDataType)
					obj.OutputDataType = getPixelDataType(obj, F);
				end
				
				% RANGE
				fMin = onCpu(obj, min(F(:)));
				fMax = onCpu(obj, max(F(:)));
				if ~isempty(obj.OutputRange)
					curMin = obj.OutputRange(1);
					curMax = obj.OutputRange(2);
					obj.OutputRange = [ min(fMin, curMin) , max(fMax, curMax) ];
				else
					obj.OutputRange = [ fMin, fMax ];
				end
				
				varargout = varargin;%TODO
			end
			
			% 			% UPDATE FRAME INPUT COUNTER
			% 			obj.NumFramesInputCount = obj.NumFramesInputCount + numFrames
			
		end
	end
	
	% ##################################################
	% MATLAB SYSTEM METHODS
	% ##################################################
	methods (Access = protected)
		function setupImpl(obj, F, varargin) %TODO: just varargin?
			
			fprintf('VideoStreamProcessor: setupImpl()\n')
			
			try
				% Called by Setup(obj, F) or on first call to Step(obj, F)
				
				% INITIALIZATION (STANDARD)
				systemInit(obj) % defined in core SystemInterface class only
				initialize(obj) % defined in core SystemInterface class or derived class
				checkInput(obj, F);
				getNumOutputs(obj);
				
				notify(obj, 'Setup')
				
			catch me
				notify(obj, 'Error')
				rethrow(me)%TODO
				% handleError(obj, me)
			end
		end
		function varargout = stepImpl(obj, F, varargin)
			try
				
				% PRE-PROCEDURE TASKS
				F = checkInput(obj, F, varargin{:});
				numOut = min( getNumOutputs(obj), nargout);
				argsOut = cell(1,numOut);
				
				startTic = tic;
				
				% RUN MAIN PROCEDURE
				[argsOut{1:numOut}] = runMainTask(obj, F, varargin{:});
				
				
				% POST-PROCEDURE TASKS
				procTime = toc(startTic);
				addBenchmark(obj, procTime, getNumFrames(F));
				
				% 				F = checkOutput(obj, F);%TODO
				if ~isempty(argsOut)
					[argsOut{:}] = checkOutput(obj, argsOut{:});%TODO
				end
				
				varargout = argsOut;
				
				notify(obj, 'Step')
				
			catch me
				notify(obj, 'Error')
				rethrow(me)%TODO
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
	end
	
	% ##################################################
	% SHARED HELPER ROUTINES
	% ##################################################
	methods (Access = ?ignition.system.SystemInterface)
		function addBenchmark(obj, Tn, numFrames)
			
			% CONVERT GIVEN TIME TO TIME-PER-FRAME
			tk = Tn/numFrames;
			obj.LastTimePerFrame = tk;
			t0 = obj.MeanTimePerFrame;
			
			if ~isempty(t0)
				% UPDATE MEAN BENCHMARK
				N = obj.NumFramesInputCount;
				
				obj.MeanTimePerFrame = t0  +  (tk - t0).*(numFrames./N);
				
				% UPDATE MAX & MIN BENCHMARK
				obj.MinTimePerFrame = min( tk, obj.MinTimePerFrame);
				obj.MaxTimePerFrame = max( tk, obj.MaxTimePerFrame);
				
			else
				obj.MeanTimePerFrame = tk;
				obj.MinTimePerFrame = tk;
				obj.MaxTimePerFrame = tk;
			end
			
		end
	end
	
	
	
	
	
end















