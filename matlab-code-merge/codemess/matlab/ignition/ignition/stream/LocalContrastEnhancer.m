classdef (CaseInsensitiveProperties = true) LocalContrastEnhancer < ignition.core.VideoStreamProcessor
	% LocalContrastEnhancer
	
	
	
	
	
	
	% USER SETTINGS
	properties (Nontunable) % new
		LpFilterSigma = 12 %16 % 25
		LpFilterSize
	end
	properties (Nontunable)
		% 		BackgroundFrameSpan = 1 % TODO:remove?
		MaxNumberTrainingFrames = 32
	end
	
	% STATES
	properties (DiscreteState)
		CurrentFrameIdx
		% 		CurrentNumBufferedFrames %TODO: remove?
	end
	properties (SetAccess = ?ignition.core.Object, Logical)
		LimLocked
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = ?ignition.core.Object, Nontunable, Hidden) % new-nontunable, old-hidden
		LpFilterFcn@function_handle
		FloatingPointType = 'single'
	end
	properties (SetAccess = ?ignition.core.Object, Hidden)
		LpCoefficients
		LpFrameComponent
		ScalarLogBaseline	  	  % io
		ScaleIn
		BaselineIn
		ScaleOut
		BaselineOut
	end
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = LocalContrastEnhancer(varargin)
			setProperties(obj,nargin,varargin{:});
			obj.CanUseInteractive = true;
			obj.Default.FloatingPointType = 'single';
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods (Access = protected)
		function setupImpl(obj, data)
			% INITIALIZATION
			fillDefaults(obj)
			checkInput(obj, data)
			constructDomainTransferFunctions(obj)
			% FILTER-METHOD
			constructLocalLowPassFilter(obj)
			% BASELINE
			tuneScalarBaseline(obj, data);
			
			obj.CurrentFrameIdx = 0;
			obj.TuningImageDataSet = [];
			if ~isempty(obj.GpuRetrievedProps)
				pushGpuPropsBack(obj)
			end
		end
		function data = stepImpl(obj,data)
			
			if isempty(obj.CurrentFrameIdx)
				setup(obj,data)
			end
			
			% LOCAL VARIABLES
			n = obj.CurrentFrameIdx;
			inputNumFrames = size(data,3);
			
			if ~obj.LimLocked
				if obj.CurrentFrameIdx >= obj.MaxNumberTrainingFrames
					lockLimits(obj)
				else
					tuneLimitScalingFactors(obj, data)
					constructDomainTransferFunctions(obj)
				end
			end
			
			% RUN HOMOMORPHIC-FILTER FUNCTION
			data = processData(obj, data);
			
			% UPDATE NUMBER OF BUFFERED FRAMES
			% 			obj.CurrentNumBufferedFrames = min(obj.CurrentFrameIdx, obj.BackgroundFrameSpan);%TODO:remove?
			obj.CurrentFrameIdx = obj.CurrentFrameIdx + inputNumFrames;
			
		end
		function resetImpl(obj)
			% 			preBufferedFrames = obj.CurrentNumBufferedFrames;
			% INITIALIZE/RESET ALL DESCRETE-STATE PROPERTIES
			dStates = obj.getDiscreteState;
			fn = fields(dStates);
			for m = 1:numel(fn)
				dStates.(fn{m}) = 0;
			end
			% 			if ~isempty(preBufferedFrames)
			% 				obj.CurrentNumBufferedFrames = min(preBufferedFrames, obj.BackgroundFrameSpan);
			% 			end
			obj.LimLocked = false;
			constructDomainTransferFunctions(obj)
			
			
		end
		function releaseImpl(obj)
			% 			obj.LimLocked = false;
			fetchPropsFromGpu(obj)
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
	
	% RUN-TIME HELPER FUNCTIONS
	methods (Access = protected, Hidden)
		function data = processData(obj, data)
			% 			nf = obj.CurrentNumBufferedFrames;
			if ismatrix(data)
				inputNumFrames = 1;
			else
				inputNumFrames = size(data,ndims(data));
			end
			
			% CONVERT TO LOG-DOMAIN
			imGray = toLogFcn(obj,data);
			
			% GET LOW-FREQUENCY COMPONENT (TO SUBTRACT)
			% 			if (obj.BackgroundFrameSpan == 1) || (nf <1)
			try
				lpfilt = obj.LpFilterFcn;
				lpComponent = lpfilt(imGray);
			catch me
				getError(me)
				lpComponent = lpFilt(imGray);
				
				for k=1:inputNumFrames
					lpComponent(:,:,k) = lpfilt(imGray(:,:,k));
				end
			end
			% 			else% TEMPORAL SMOOTHING OF BACKGROUND
			% 				lpComponent = obj.LpFrameComponent;
			% 				nt = nf / (nf + 1);
			% 				na = 1/(nf + 1);
			% 				lpComponent = lpComponent*nt + feval(obj.LpFilterFcn, imGray).*na;
			% 			end
			
			% SUBTRACT LOW-FREQUENCY COMPONENT IN LOG-DOMAIN
			imGray = imGray - lpComponent + obj.ScalarLogBaseline;
			
			% CONVERT BACK TO IMAGE DOMAIN
			data = fromLogFcn(obj,imGray);
			
			if inputNumFrames <= 1
				obj.LpFrameComponent = lpComponent;
			else
				obj.LpFrameComponent = mean(lpComponent,3);
			end
		end
		function data = toLogFcn(obj, data)
			data = log1p( min(max( obj.ScaleIn.*( cast( data, obj.FloatingPointType) - obj.BaselineIn), eps), 1));
		end
		function data = fromLogFcn(obj, data)
			% Fh = exp( G - Gl + io) - 1;  where G = Gh + Gl - io
			data = cast(obj.ScaleOut.*min(max(  expm1(data),  eps),1) + obj.BaselineOut, obj.OutputDataType);
		end
	end
	methods
		function lockLimits(obj)
			obj.LimLocked = true;
		end
	end
	
	% TUNING
	methods (Hidden)
		function tuneInteractive(obj)
			% INITIALIZATION (THISCLASS METHODS)
			constructDomainTransferFunctions(obj)
			constructLocalLowPassFilter(obj)
			tuneScalarBaseline(obj, obj.TuningImageDataSet);
			lockLimits(obj)
			
			% STEP 1: LOW-FREQUENCY COMPONENT - GAUSSIAN WINDOW SIGMA
			k = 1;
			pname = 'LpFilterSigma';
			obj.TuningStep(k).ParameterName = pname;
			x = obj.(pname);
			if isempty(x)
				x = obj.Default.(pname);
			end
			obj.TuningStep(k).ParameterDomain = [1:x, x+1:10*x];
			obj.TuningStep(k).ParameterIdx = ceil(x);
			obj.TuningStep(k).Function = @testContrastEnhancer;
			obj.TuningStep(k).CompleteStep = true;
			
			% SET UP TUNING WINDOW
			createTuningFigure(obj);			%TODO: can also use for automated tuning?
			
		end
		function tuneAutomated(obj)
			constructDomainTransferFunctions(obj)
			constructLocalLowPassFilter(obj)
			tuneScalarBaseline(obj, obj.TuningImageDataSet);
			lockLimits(obj)
			obj.TuningImageDataSet = [];
		end
		function F = testContrastEnhancer(obj, F)
			% CHECK WHETHER A NEW BUFFER NEEDS TO BE COMPUTED (e.g. change of  PRECEDING PARAMETERS)
			lpSigma = obj.lpFilterSigma;
			persistent lastLpSigma
			if isempty(lastLpSigma)
				lastLpSigma = 0;
			end
			if obj.UseGpu && ~isa(F, 'gpuArray')
				F = gpuArray(F);
			end
			if (lpSigma ~= lastLpSigma)
				obj.LpFilterSigma = lpSigma;
				obj.LpFilterSize = [];
				constructLocalLowPassFilter(obj)
			end
			
			% CALL NORMAL "RUN-TIME" HOMOMORPHIC FILTER METHOD
			F = processData(obj, F);
			
		end
	end
	
	% INITIALIZATION HELPER METHODS
	methods (Access = protected, Hidden)
		function constructDomainTransferFunctions(obj)
			% MANAGE DATATYPES
			fptype = obj.FloatingPointType;
			
			% NORMALIZE INPUT TO  0<F<1  RANGE THEN ->  G = LOG(F+1)
			Si = cast( 1/obj.InputScale, fptype);
			Bi = cast(obj.InputOffset, fptype);
			if obj.UseGpu
				Si = gpuArray(Si);
				Bi = gpuArray(Bi);
			end
			obj.ScaleIn = Si;
			obj.BaselineIn = Bi;
			
			% EXPAND RESULT BACK TO RANGE OF OUTPUT AFTER <-  Fh = EXP(G - Gl + io) - 1
			So = cast( obj.OutputScale, fptype);
			Bo = cast(obj.OutputOffset, fptype);
			if obj.UseGpu
				So = gpuArray(So);
				Bo = gpuArray(Bo);
			end
			obj.ScaleOut = So;
			obj.BaselineOut = Bo;
		end
		function tuneScalarBaseline(obj, data)
			maxTrainingSamples = 50;
			N = size(data,3);
			if (N > maxTrainingSamples)
				data = data(:,:,fix(linspace(1,N,maxTrainingSamples)));
				N = maxTrainingSamples;
			end
			if (N == 1) && (~isempty(obj.LpFrameComponent))
				imLowPass = obj.LpFrameComponent;
				imGray = toLogFcn(obj, data);
				io = max(double(imLowPass(:) - imGray(:)));
				% 				io = mean(imLowPass(imLowPass<median(imLowPass(:))));
			else
				io = .1;
				for k=1:N
					imInt = ignition.shared.onGpu( data(:,:,k));
					if ~isempty(obj.ScaleIn)
						imGray = toLogFcn(obj, imInt);
					else
						imGray =  log1p((double(imInt)-obj.InputOffset)./obj.InputScale);
					end
					if ~isempty(obj.LpFilterFcn)
						try
							imLowPass = feval(obj.LpFilterFcn, imGray);
						catch me
							msg = getError(me);
							imLowPass = imfilter( imGray, obj.LpCoefficients, 'replicate');
						end
					else
						imLowPass = imfilter( imGray, obj.LpCoefficients, 'replicate');
					end
					% 					ioNew = mean(imLowPass(imLowPass<median(imLowPass(:))));
					
					io = max(io, max(imLowPass(:) - imGray(:)));
				end
			end
			if isempty(obj.ScalarLogBaseline)
				obj.ScalarLogBaseline = io;
			else
				obj.ScalarLogBaseline = max( io, obj.ScalarLogBaseline);
			end
		end
		function constructLocalLowPassFilter(obj)
			% DEFINE FILTER PROPERTIES
			maxFilterSize = min(obj.FrameSize(1:2));
			maxSigma = floor((maxFilterSize -1)/4);
			if isempty(obj.LpFilterSigma)
				obj.LpFilterSigma = floor(1/8 * maxSigma);
			end
			if isempty(obj.LpFilterSize)
				obj.LpFilterSize = 2*ceil(2 * obj.LpFilterSigma)+1;
			end
			imSize = obj.FrameSize;
			sigma = obj.LpFilterSigma;
			hSize = obj.LpFilterSize;
			
			sigma3 = [sigma sigma 1];
			hsize3 = [hSize hSize 1];
			obj.LpFilterFcn = @(f) imgaussfilt3( f, sigma3,...
				'FilterSize', hsize3,...
				'Padding', 'replicate',...
				'FilterDomain', 'spatial');
			
			% 			obj.LpFilterFcn = @(f) gaussFiltFrameStack(f, sigma);
			
			% 			[cfcn, H] = constructLowPassFilter(obj, imSize, sigma, hSize);
			
			% 			obj.LpFilterFcn = cfcn;
			% 			obj.LpCoefficients = H;
			
		end
	end
	
	
	
	
	
	
end





















