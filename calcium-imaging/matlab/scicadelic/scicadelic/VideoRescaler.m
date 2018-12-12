classdef (CaseInsensitiveProperties = true) VideoRescaler < scicadelic.SciCaDelicSystem
	% Implemented by Mark Bucklin 6/12/2014
	%
	
	
	properties
		UpperSaturationLimit = .9995
		LowerSaturationLimit = .05
	end
	properties (SetAccess = protected)
	end
	
	
	
	
	
	
	methods
		function obj = VideoRescaler(varargin)
			setProperties(obj,nargin,varargin{:});
			obj = parseConstructorInput(obj,varargin(:));
		end
		function addSampleData(obj, sampleData)
			obj.preSample = cat(3, obj.preSample, sampleData);
			obj.InputRange = double([min(sampleData(:)) max(sampleData(:))]);
		end
	end
	methods (Access = protected)
		function setupImpl(obj, data)
			% Check-It: Check the input to this file, which should be passed using GETDATASAMPLE
			
			
			% ------------------------------------------------------------------------------------------
			% DEFINE DEFAULT FUNCTION PARAMETERS
			% ------------------------------------------------------------------------------------------
			obj.default.UpperSaturationLimit = 99.95;
			obj.default.LowerSaturationLimit = 5;
			obj.default.OutputDataType = class(data);
			
			%
			obj.OutputRange = double([0 intmax(obj.OutputDataType)]);
			getSaturatedRange(obj, [obj.LowerSaturationLimit obj.UpperSaturationLimit]);
		end
		function data8 = stepImpl(obj, data)
			obj = setStatus(obj,0, 'Rescaling Video');
			N = obj.nFrames;
			intScaleCoeff = double(obj.outputRange(2) - obj.outputRange(1));
			satRange = double(obj.InputRange);
			satScale = double(satRange(2) - satRange(1));
			inClass = class(data);
			outClass = obj.OutputDataType;
			
			% TODO: Chunk the data up or distribute it using PCT
			scaleTo8 = @(X) uint8( single(X-satRange(1)) ./ (satScale/255));
			if strcmpi(outClass,'uint8')
				data8 = scaleTo8(data);
			else
				for k=1:N
					obj = setStatus(obj, k/N);
					data(:,:,k) = gather(cast( mat2gray(gpuArray(data(:,:,k)), satRange) .* intScaleCoeff, outClass));
				end
			end
			obj = setStatus(obj,inf);
			obj = finalize(obj);
		end
	end
	methods (Access = protected)
		function getSaturatedRange(obj)
			
			saturationPercentiles = [obj.LowerSaturationLimit obj.UpperSaturationLimit];
			
			if any(saturationPercentiles > 1)
				saturationPercentiles = saturationPercentiles/100;
			end
			if isa(obj.preSample, 'gpuArray')
				datatype = classUnderlying(obj.preSample);
				ongpu = true;
			else
				datatype = class(obj.preSample);
				ongpu = false;
			end
			if obj.UseGpu && ~ongpu
				X = gpuArray(obj.preSample);
			else
				X = obj.preSample;
			end
			nSampleFrames = size(X,max(3,ndims(X)));
			nPixelsPerFrame = numel(X)/nSampleFrames;
			
			try
				satLims = stretchlim(X, saturationPercentiles);
				satRange = double(max(satLims,[],2))' .* double(intmax(datatype));
			catch me
				warning(me.message)
				targetPixOver = round((1-saturationPercentiles(2)) * nPixelsPerFrame);
				targetPixUnder = round(saturationPercentiles(1) * nPixelsPerFrame);
				maxIntensity = max(X(:));
				minIntensity = min(X(:));
				if isa(X, 'integer')
					initialStep = ceil(intmax(class(X))/64);
					minStep = ceil(initialStep/64);
				else
					initialStep = 1/1000;
					minStep = 1/10000;
				end
				pixOver = 0;
				step = initialStep;
				while step > minStep
					if pixOver > targetPixOver
						break
					end
					pixOver = nnz(X(:) >= maxIntensity-step);
					if pixOver < targetPixOver
						maxIntensity = maxIntensity - step;
					else
						step = step/2;
						pixOver = pixOver-step/2;
						maxIntensity = maxIntensity - step;
					end
				end
				step = initialStep;
				pixUnder = 0;
				while step > minStep
					if pixUnder > targetPixOver
						break
					end
					pixUnder = nnz(X(:) <= minIntensity-step);
					if pixUnder < targetPixUnder
						minIntensity = minIntensity + step;
					else
						step = step/2;
						pixUnder = pixUnder-step/2;
						minIntensity = minIntensity + step;
					end
				end
				satRange = [minIntensity maxIntensity];
			end
			if isa(satRange,'gpuArray')
				obj.InputRange = gather(satRange);
			else
				obj.InputRange = satRange;
			end
		end
	end
	
	
	
	
end