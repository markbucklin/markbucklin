
classdef BaselineRemover < FluoProFunction
	
	
	
	properties
		activitySmoothingFilterSize = 51
	end
	properties (SetAccess = protected)
		baselineOffset
		activityImage
		cellMask
		cellPixNum
		cellBaseline
		neuropilMask
		neuropilPixNum
		neuropilBaseline
	end
	
	
	
	
	
	
	methods
		function obj = BaselineRemover(varargin)	
			obj = getSettableProperties(obj);
			obj = parseConstructorInput(obj,varargin(:));
		end
		
		function obj = initialize(obj)
			[obj, sampleData] = getDataSample(obj,obj.data);
			obj.preSample = sampleData;
			% SEPARATE ACTIVE CELLULAR AREAS FROM BACKGROUND (NEUROPIL)
			obj.activityImage = imfilter(range(obj.data,3), fspecial('average',obj.activitySmoothingFilterSize), 'replicate');
			obj.neuropilMask = double(obj.activityImage) < mean2(obj.activityImage);
			obj.neuropilPixNum = nnz(obj.neuropilMask(:));
			obj.cellMask = ~obj.neuropilMask;
			obj.cellPixNum = nnz(obj.cellMask(:));
		end
		
		function obj = run(obj)						
			obj.neuropilBaseline = sum(sum(bsxfun(@times, obj.data, cast(obj.neuropilMask,'like',obj.data)), 1), 2) ./ obj.neuropilPixNum; %average of pixels in mask
			obj.cellBaseline = sum(sum(bsxfun(@times, obj.data, cast(obj.cellMask,'like',obj.data)), 1), 2) ./ obj.cellPixNum;
			
			% % REMOVE BASELINE SHIFTS BETWEEN FRAMES (TODO: untested, maybe move to subtractBaseline)
			% obj.data = cast( exp( bsxfun(@minus,...
			%    log(single(obj.data)+1) + log(obj.baseline+1) ,...
			%    log(single(neuropilBaseline)+1))) - 1, 'like', obj.data) ;
			% fprintf('\t Post-Baseline-Removal range: %i\n',range(obj.data(:)))
			if isempty(obj.baselineOffset)
				obj.baselineOffset = median(obj.neuropilBaseline);
			end
			
			obj.data = cast( bsxfun(@minus,...
				single(obj.data), single(obj.neuropilBaseline)) + obj.baselineOffset, ...
				'like', obj.data);
			
			
			% 			% SCALE TO FULL RANGE OF INPUT (UINT16)
			% 			if nargin < 2
			% 				obj.scaleval = 65535/double(1.1*getNearMax(obj.data));%TODO:hardcoded
			% 			end
			% 			obj.data = obj.data*obj.scaleval;
			
			% 			fprintf('\t Output MINIMUM: %i\n',min(obj.data(:)))
			% 			fprintf('\t Output MAXIMUM: %i\n',max(obj.data(:)))
			% 			fprintf('\t Output RANGE: %i\n',range(obj.data(:)))
			% 			fprintf('\t Output MEAN: %i\n',mean(obj.data(:)))
			
			% if nargin >= 2
			%    lastFrame = obj.connectingFrame(neuropilMask);
			%    firstFrameMedfilt = median(data(:,:,1:8), 3);
			%    firstFrame = data(:,:,1);
			%    firstFrame = firstFrame(neuropilMask);
			%    interFileDif = single(firstFrame) - single(lastFrame);
			%    %    fileRange = range(data,3);
			%    %    baselineShift = double(mode(interFileDif(fileRange < median(fileRange(:)))));
			%    baselineShift = round(mean(interFileDif(:)));
			%    fprintf('\t->Applying baseline-shift: %3.3g\n',-baselineShift)
			%    data = data - cast(baselineShift,'like',data);
			% end
			% obj.connectingFrame = data(:,:,end);
			% obj.connectingFrameMedfilt = median(data(:,:,end-7:end), 3);
			obj = finalize(obj);
		end
		
		
	end
	
	
	
	
	
	
	
	
	
	
	
end