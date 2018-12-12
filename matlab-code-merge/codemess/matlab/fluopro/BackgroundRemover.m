classdef BackgroundRemover < FluoProFunction
	
	
	
	
	properties
		morphCloseDiskRadius = 1
		preSubtractionOffset = 1024
		bgSource = 'min'
	end
	properties (Constant)
		bgSourceOptions = {'min','mean','median','pctile'}
	end
	properties (SetAccess = protected)
		background
		fmin
		fmean
		fmax
		minval
	end
	
	
	
	
	methods
		function obj = BackgroundRemover(varargin)
			obj = getSettableProperties(obj);
			obj = parseConstructorInput(obj,varargin(:));
		end
		
		function obj = initialize(obj)
			[obj, sampleData] = getDataSample(obj,obj.data);
			obj.preSample = sampleData;
			
			obj.fmin = min(obj.data,[],3);
			obj.fmax = max(obj.data,[],3);
			obj.minval = min(obj.fmin(:));
			% obj.fstd = std(single(obj.data),1,3);
			% mfstd = mean(obj.fstd(obj.fstd > median(obj.fstd(:))));
			% obj.scaleval = 65535/mean(obj.fmax(obj.fmax > 2*mean2(obj.fmax)));
			if isempty(obj.bgSource)
				obj.bgSource = 'min';
			end
			switch obj.bgSource
				case 'min'
					obj.background = imclose(obj.fmin, strel('disk',obj.morphCloseDiskRadius));
				case 'mean'
					obj.fmean = single(mean(obj.data,3));
					obj.background = imclose(obj.fmean, strel('disk',obj.morphCloseDiskRadius));
				case 'median'
					%TODO
				case 'pctile'
					%TODO
			end
			obj.background = cast(obj.background,'like',obj.data);
			obj.preSubtractionOffset = cast(obj.preSubtractionOffset,'like',obj.data);
		end
		
		function obj = run(obj)
			
			
			
			% fkmean = single(mean(mean(obj.data,1),2));
			% difscale = (65535 - fkmean/2) ./ single(getNearMax(obj.data));
			% 			N = size(obj.data,3);%TODO:hardcoded
			
			obj.data = bsxfun( @minus, obj.data + obj.preSubtractionOffset, obj.background);
			
			obj = finalize(obj);
		end
		
		
	end
	
	
	
	
	
	
	
	
	
	
	
end