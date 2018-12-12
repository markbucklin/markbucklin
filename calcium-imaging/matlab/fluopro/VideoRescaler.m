classdef (CaseInsensitiveProperties = true) VideoRescaler < FluoProFunction
	% Implemented by Mark Bucklin 6/12/2014
	%
	
	
	properties
		upperSaturationLimit = .9995
		lowerSaturationLimit = .05
		outputDataType
	end
	properties (SetAccess = protected)		
		% 		inputRange
		outputRange
	end
	
	
	
	
	
	
	methods
		function obj = VideoRescaler(varargin)
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
			% DEFINE DEFAULT FUNCTION PARAMETERS
			% ------------------------------------------------------------------------------------------			
			obj.default.upperSaturationLimit = 99.995;
			obj.default.lowerSaturationLimit = 5;
			obj.default.outputDataType = class(obj.data);
			obj.useGpu = true;
			obj = checkOptions(obj);
			% 			obj.inputRange = double([min(sampleData(:)) max(sampleData(:))]);
			obj.outputRange = double([0 intmax(obj.outputDataType)]);			
			obj = getSaturatedRange(obj, [obj.lowerSaturationLimit obj.upperSaturationLimit]);			
		end
		function obj = run(obj)
			obj = setStatus(obj,0, 'Rescaling Video');
			N = obj.nFrames;
			intScaleCoeff = double(obj.outputRange(2) - obj.outputRange(1));
			satRange = double(obj.saturatedRange);
			satScale = double(satRange(2) - satRange(1));
			inClass = class(obj.data);
			outClass = obj.outputDataType;
			
			% TODO: Chunk the data up or distribute it using PCT
			scaleTo8 = @(X) uint8( single(X-satRange(1)) ./ (satScale/255));
			if strcmpi(outClass,'uint8')
				obj.data = scaleTo8(obj.data);
			else
				for k=1:N
					obj = setStatus(obj, k/N);
					obj.data(:,:,k) = gather(cast( mat2gray(gpuArray(obj.data(:,:,k)), satRange) .* intScaleCoeff, outClass));
				end
			end
			obj = setStatus(obj,inf);
			obj = finalize(obj);			
		end
	end
	
	
	
	
	
end