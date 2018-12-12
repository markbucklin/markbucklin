classdef HomomorphicLocalContrastEnhancerFP < FluoProFunction
	% HOMOMORPHICLOCALCONTRASTENHANCERFP
	% Implemented by Mark Bucklin 6/12/2014
	%
	% FROM WIKIPEDIA ENTRY ON HOMOMORPHIC FILTERING
	% Homomorphic filtering is a generalized technique for signal and image
	% processing, involving a nonlinear mapping to a different domain in which
	% linear filter techniques are applied, followed by mapping back to the
	% original domain. This concept was developed in the 1960s by Thomas
	% Stockham, Alan V. Oppenheim, and Ronald W. Schafer at MIT.
	%
	% Homomorphic filter is sometimes used for image enhancement. It
	% simultaneously normalizes the brightness across an image and increases
	% contrast. Here homomorphic filtering is used to remove multiplicative
	% noise. Illumination and reflectance are not separable, but their
	% approximate locations in the frequency domain may be located. Since
	% illumination and reflectance combine multiplicatively, the components are
	% made additive by taking the logarithm of the image intensity, so that
	% these multiplicative components of the image can be separated linearly in
	% the frequency domain. Illumination variations can be thought of as a
	% multiplicative noise, and can be reduced by filtering in the log domain.
	%
	% To make the illumination of an image more even, the high-frequency
	% components are increased and low-frequency components are decreased,
	% because the high-frequency components are assumed to represent mostly the
	% reflectance in the scene (the amount of light reflected off the object in
	% the scene), whereas the low-frequency components are assumed to represent
	% mostly the illumination in the scene. That is, high-pass filtering is
	% used to suppress low frequencies and amplify high frequencies, in the
	% log-intensity domain.[1]
	%
	% More info HERE: http://www.cs.sfu.ca/~stella/papers/blairthesis/main/node35.html
	% DEFINE PARAMETERS and PROCESS INPUT
	% gpu = gpuDevice(1);
	% CONSTRUCT HIGH-PASS (or Low-Pass) FILTER
	
	
	properties
		lpFilterSigma = 30
		lpFilterSize
		outputDataType = 'uint16'
		inputRange
		outputRange
		backgroundFrameSpan = 1200			% set to inf to use a static time-averaged background		
	end
	properties (SetAccess = protected)
		logIlluminationBaseline
		staticBackground
	end
	
	
	
	
	
	
	methods
		function obj = HomomorphicLocalContrastEnhancerFP(varargin)			
			obj = getSettableProperties(obj);
			obj = parseConstructorInput(obj,varargin(:));			
			obj.canUseGpu = true;
			obj.canUsePct = false;
		end
		function obj = initialize(obj)
			% Check-It: Check the input to this file, which should be passed using GETDATASAMPLE
			[obj, sampleData] = getDataSample(obj,obj.data);
			obj.preSample = sampleData;
			% ------------------------------------------------------------------------------------------
			% DATA-DESCRIPTION VARIABLES
			% ------------------------------------------------------------------------------------------
			sz = size(sampleData);
			inputDataType = class(sampleData);			
			% ------------------------------------------------------------------------------------------
			% DEFINE DEFAULT FUNCTION PARAMETERS
			% ------------------------------------------------------------------------------------------			
			obj.default.lpFilterSigma = (1/20) * min(sz(1:2));
			obj.default.lpFilterSize = ceil(2 * obj.lpFilterSigma + 1);
			obj.default.outputDataType = inputDataType;
			obj.default.inputRange = double([min(sampleData(:))  max(sampleData(:))]);
			obj.default.outputRange = double([0 intmax(obj.outputDataType)]);
			obj.default.backgroundFrameSpan = 1200;
			obj = checkOptions(obj);
		end
		function obj = run(obj)
			sz = size(obj.data);
			N = sz(3);
			% ------------------------------------------------------------------------------------------
			% GET CONSISTENT RANGE FOR CONVERSION TO FLOATING POINT INTENSITY IMAGE
			% ------------------------------------------------------------------------------------------
			inputScale = double(obj.inputRange(2) - obj.inputRange(1));
			inputOffset = double(obj.inputRange(1));
			outputScale = obj.outputRange(2) - obj.outputRange(1);
			outputOffset = obj.outputRange(1);
			bgUseMovingAvg = obj.backgroundFrameSpan > 1;
			maxNf = obj.backgroundFrameSpan;
			nf=0;
			
			% ------------------------------------------------------------------------------------------
			% CONSTRUCT LOW-PASS GAUSSIAN FILTER
			% ------------------------------------------------------------------------------------------
			if obj.useGpu
				hLP = gpuArray(fspecial('gaussian',obj.lpFilterSize, obj.lpFilterSigma));
			else
				hLP = fspecial('gaussian', obj.lpFilterSize, obj.lpFilterSigma);
			end
			
			% ------------------------------------------------------------------------------------------
			% USE A CONSISTENT ILLUMINATION BASELINE
			% ------------------------------------------------------------------------------------------
			if isempty(obj.logIlluminationBaseline)
				io = [];
			else
				io = obj.logIlluminationBaseline;
			end
			if obj.backgroundFrameSpan > obj.nFrames && ~obj.useGpu
				% APPLY THE FILTER TO ENTIRE VIDEO AT ONCE
				imGray =  (single(obj.data)-inputOffset)./inputScale;
				imGray = log1p(imGray);
				imLp = mean(imfilter(imGray, hLP, 'replicate'),3);
				io = mean(imLp(imLp<median(imLp(:))));
				imGray = expm1( bsxfun(@minus, imGray , imLp + io));
				imGray = imGray .* outputScale  + outputOffset;
				obj.data = cast(imGray, obj.outputDataType);
			else
				% ------------------------------------------------------------------------------------------
				% FILTER TO EACH FRAME INDIVIDUALLY
				% ------------------------------------------------------------------------------------------
				obj = setStatus(obj,0,'Correcting Illumination using Homomorphic Filter');
				%TODO: non-sequential
				% 			if ~obj.isSequential
				for k=1:N
					% ------------------------------------------------------------------------------------------
					% SCALE INPUT TO [0,1] BASED INTENSITY IMAGES
					% ------------------------------------------------------------------------------------------
					if obj.useGpu
						%TODO: profile using mat2gray(obj.data(:,:,k), obj.inputRange);
						imGray =  (single(gpuArray(obj.data(:,:,k)))-inputOffset)./inputScale;
					else
						imGray =  (double(obj.data(:,:,k))-inputOffset)./inputScale;
					end
					
					% ------------------------------------------------------------------------------------------
					% LOWPASS-FILTERED IMAGE (IN LOG-DOMAIN) REPRESENTS UNEVEN ILLUMINATION
					% ------------------------------------------------------------------------------------------
					imGray = log1p(imGray); % log(imGray + 1);
					if ~bgUseMovingAvg || k==1
						imLp = imfilter( imGray, hLP, 'replicate');
					else% TEMPORAL SMOOTHING OF BACKGROUND
						nt = nf / (nf + 1);
						na = 1/(nf + 1);
						imLp = imLp*nt + imfilter( imGray, hLP, 'replicate')*na;
					end
					nf = min(nf + 1, maxNf);
					if isempty(io)
						io = mean(imLp(imLp<median(imLp(:))));
					end
					
					% ------------------------------------------------------------------------------------------
					% SUBTRACT LOW-FREQUENCY "ILLUMINATION" COMPONENT
					% ------------------------------------------------------------------------------------------
					imGray = expm1( imGray - imLp + io); % exp( imGray - imLp + io) - 1;
					
					% ------------------------------------------------------------------------------------------
					% RESCALE AND CONVERT BACK TO ORIGINAL DATATYPE
					% ------------------------------------------------------------------------------------------
					imGray = imGray .* outputScale  + outputOffset;
					if obj.useGpu
						obj.data(:,:,k) = gather(cast(imGray, obj.outputDataType));
					else
						obj.data(:,:,k) = cast(imGray, obj.outputDataType);
					end
				end
			end
			
			% ------------------------------------------------------------------------------------------
			% SAVE ILLUMINATION BASELINE
			% ------------------------------------------------------------------------------------------
			obj.logIlluminationBaseline = io;
			% TODO: alternative function for applying same filter to all frames simultaneously
			obj = finalize(obj);
		end
	end
	
	
	
	
end






















% CLEAN UP LOW-END (SATURATE TO ZERO OR 100)
% 	  im(im<obj.outputRange(1)) = obj.outputRange(1);
% fcnParameterNames = {...
%    'sigma',...
%    'filtSize',...
%    'outputDataType',...
%    'consistent'};