




% properties
OutputType = 'LabelMatrix'
% end

% properties (SetAccess = protected, Hidden)
		OutputTypeSet = matlab.system.StringSet({'LabelMatrix','ConnComp','Mask'})
		OutputTypeIdx
% 	end





% setup
if isempty(obj.OutputTypeIdx)
	obj.OutputTypeIdx = getIndex(obj.OutputTypeSet, obj.OutputType);
end

obj.OutputTypeIdx = getIndex(obj.OutputTypeSet, obj.OutputType);









% function lm = findSegmentedRegions(obj, bwFg)

% LOCAL VARIABLES
[nRows, nCols, N] = size(bwFg);


if (obj.OutputTypeIdx == 2)
	cc = bwconncomp(bwFg, 8);
	obj.ConnComp = cc;
	lm = labelmatrix(cc);
else
	bwFg(:,end,:) = 0;
	lm = reshape(uint32( bwlabel( reshape( bwFg , nRows, nCols*N, 1))), nRows, nCols, N);
end

% RETURN LABEL-MATRIX IN UNSIGNED 16-BIT INTEGER FORMAT, WRAPPED AROUND
if isa(lm, 'uint8')
	lm = uint16(lm);
elseif ~isa(lm, 'uint16')
	if isa(lm, 'gpuArray')
		lm = arrayfun(@wrapUint16, lm);
	else
		if any(any(lm(:,:,end) > 65535))
			lm = uint16(bsxfun(@rem, lm-1, 65535)) + uint16(lm >= 1);
		else
			lm = uint16(lm);
		end
	end
end

% OR RENUMBER LABELS IN EACH FRAME SO EACH FRAME BEGINS AT 1 (gputimeit = .005 for 8 frames)
lm = uint16(bsxfun(@minus, lm, 65535 - max(max( bsxfun(@times,...
	cast(logical(lm), 'like',lm) , 65535-lm))) - 1 ));
% 			lm = min(min( arrayfun(@switchZero2IntMax,lm) , 1),2)) + 1; % 2.5ms

% SEND RESULT TO PROPERTY OUTPUT PORT
obj.LabelMatrix = lm;
obj.Mask = logical(lm);

% MATCH & ACCUMULATE LABELS OVER TIME
if isempty(obj.SegmentationSum)
	obj.SegmentationSum = sum(uint32(logical(lm)),3,'native');
else
	obj.SegmentationSum = obj.SegmentationSum + sum(uint32(logical(lm)),3,'native');
end

% 		end