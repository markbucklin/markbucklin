classdef (CaseInsensitiveProperties, TruncatedProperties) PipedSystem < rtsci.System
	
	
	
	properties (Nontunable, Logical)
		UseFloatingPoint = true;
	end
	properties (Nontunable)
		Precision = 'single'
	end
	properties (SetAccess = ?rtsci.System)
		InputRange
		OutputRange		
	end
	properties (SetAccess = ?rtsci.System, Nontunable)
		InputDataType
		OutputDataType
		FrameSize
		FrameDimension = 4
		MaxFramesPerStep
		ProcessFcnHandle
	end
	properties (SetAccess = ?rtsci.System)
		LastTimePerFrame
		MeanTimePerFrame
		MinTimePerFrame
		MaxTimePerFrame
	end
	properties(SetAccess = ?rtsci.System)
		NumFramesInputCount = 0
	end
	properties (Nontunable, Access = ?rtsci.System, Hidden)
		PrecisionSet = matlab.system.StringSet({'single','double'})
	end
	
	
	
	
	
	
	
	methods (Access = ?rtsci.System)
		
	end
	methods (Access = ?rtsci.System)
		function F = checkInput(obj, F)
			
			% INPUT DIMENSIONS
			[numRows, numCols, numChans, numFrames] = size(F);
			if isempty(obj.FrameSize)				
				obj.FrameSize = [numRows numCols numChans];
			end
			if ~isempty(obj.MaxFramesPerStep)
				obj.MaxFramesPerStep = numFrames;
			else
				obj.MaxFramesPerStep = max( numFrames, obj.MaxFramesPerStep); %TODO
			end
			
			% RANGE
			fMin = onCpu(obj, min(F(:)));
			fMax = onCpu(obj, max(F(:)));
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
			
			% GPU
			if isempty(obj.UseGpu)
				obj.UseGpu = isa(F,'gpuArray');
			end
			if obj.UseGpu
				if ~isa(F, 'gpuArray')
					F = gpuArray(F);
				end
				% TODO: check if exists on current gpu -> for multigpu
				
			end
			
			% DATA-TYPE
			obj.InputDataType = getClass(obj, F);
			
			if obj.UseFloatingPoint && ~strcmp(obj.InputDataType, obj.Precision)
				F = cast(F, obj.Precision);
			end
			
			% UPDATE FRAME INPUT COUNTER (PREINCREMENTED)
			obj.NumFramesInputCount = obj.NumFramesInputCount + numFrames;
			
			
		end
		function F = checkOutput(obj, F)
			
			% DIMENSIONS/SIZE
			% 			[numRows, numCols, numChans, numFrames] = size(F);
			
			% DATA-TYPE
			if isempty(obj.OutputDataType)
				obj.OutputDataType = getClass(obj, F);
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
			
			% 			% UPDATE FRAME INPUT COUNTER
			% 			obj.NumFramesInputCount = obj.NumFramesInputCount + numFrames
			
		end
	end
	methods (Access = ?rtsci.System)
		function varargout = run(obj, F, varargin)
			numOut = getNumOutputs(obj);
			fcn = obj.ProcessFcnHandle;			
			if ~isempty(fcn)
				if isa(fcn, 'function_handle')
					
					% 					fcnInfo = getcallinfo(fcn); functions(fcn)
					
					% 					in = {F, varargin{:} };
					in = [{F}, varargin{:}];
					out = feval(fcn, in{:});%[F, varargin{:}]
					
				elseif iscell(fcn)
					
				else
					
				end
				varargout = out(1:numOut);
				%TODO
			end
		end
	end
	methods (Access = protected)
		function setupImpl(obj, F)
			
			try
				% Called by Setup(obj, F) or on first call to Step(obj, F)
				
				% INITIALIZATION (STANDARD)
				initialize(obj)
				checkInput(obj, F);
				
				notify(obj, 'Setup')
				
			catch me
				notify(obj, 'Error')
				rethrow(me)%TODO
				% handleError(obj, me)
			end
		end
		function varargout = stepImpl(obj, F, varargin)
			try
								
				F = checkInput(obj, F, varargin{:});
				numOut = min( getNumOutputs(obj), nargout);
				argsOut = cell(1,numOut);
				
				startTic = tic;
				
				[argsOut{1:numOut}] = run(obj, F, varargin{:});
				
				procTime = toc(startTic);
				addBenchmark(obj, procTime, size(obj, 4));
				
				varargout = argsOut;
							
				
				F = checkOutput(obj, F);
				
				
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
	end
	methods (Access = ?rtsci.System)
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















