function S = getLabeledRegionPropsRunGpuKernel_old(labelMatInput, firstFrameIdx, numCols, labelArea)
% GETLABELEDREGIONPROPSRUNGPUKERNEL - Find region-properties for regions specified using
% label-matrix input
%
%
%
% Description:
% ------------
%		This function uses the gpuArray\arrayfun subfunction mechanism to compute region-properties for
%		each region-of-interest identified in the label-matrix-type input. Unlike the built-in
%		regionprops() function, this function only computes a fixed set of properties. However, this
%		function can operate on multidimensional input, and computation is fast. The traditional
%		properties returned include AREA, BOUNDING-BOX, & CENTROID. Additionally, the function will
%		return the FRAME-IDX associated with each label.
%
%		This function is called from the class-method ignition.PixelLabel>getLabeledRegionProps
%
%
%
% Usage:
% ------------
%
%		Syntax:
%				>> S = getLabeledRegionPropsRunGpuKernel(labelMat);
%				>> S = getLabeledRegionPropsRunGpuKernel(labelMat2d, numCols);
%				>> S = getLabeledRegionPropsRunGpuKernel(labelMat2d, numCols, validLabelArea);
%				>> S = getLabeledRegionPropsRunGpuKernel(labelMat, [], validLabelArea);
%
%
%		Input:
%				labelMat	-	Label-Matrix specifying pixels belonging to each region of interest. May be
%								2D/single-frame, 3D/multi-frame, or 2D/reshaped-multi-frame if second input argument
%								is also provided
%
%				numCols		-	Number of columns in a single frame of input. Used if the label-matrix is
%								actually a multi-frame 3D array but is passed as a 2D reshaped matrix. This option
%								is provided so that the class-method using this function doesn't waste time
%								reshaping the input when it is already in 2D (optional).
%
%				labelArea	-	The area of each numbered label provided in the label-matrix. If another
%								function has already computed the area for each label (i.e. by using accumarray or
%								histcounts to exclude regions over or under some specified limits), this function
%								can use a slightly faster method to determine when to terminate the incremental
%								search for pixels belonging the label computed by each individual thread. If not
%								provided, the function must call the built-in function UNIQUE twice rather than
%								once.
%
%		Output:
%				S			-	Structure containing the region-properties AREA, BOUNDING-BOX, & CENTROID, for
%								each label, along with the reshaped->3D label-matrix, and the FRAME-IDX.
%
%
%
% Notes:
% ------------
%		(TODO: pad to ensure dimensions are multiple of 32)
%		renamed from: FINDCONNECTEDREGIONPROPSRUNGPUKERNEL
%
%
%
% See Also:
%		ignition.PixelLabel, LABELEDREGIONSTATISTICUPDATERUNGPUKERNEL, ignition.StatisticCollector,
%		UPDATESTATISTICSGPU
%
%
%		Reference page in Help browser:
%		<a href="matlab:doc('getLabeledRegionPropsRunGpuKernel')">getLabeledRegionPropsRunGpuKernel</a>
%
%
%
%
%   Copyright 2015 Mark Bucklin




% ----------------------------------------------------
% MANAGE/EXAMINE INPUT
% ----------------------------------------------------
% HANDLE VARIABLE/EMPTY INPUT
if nargin < 4
	labelArea = [];
	if nargin < 3
		numCols = [];
		if nargin < 2
			firstFrameIdx = [];
		end
	end
end
lutSize = 1048576;

% GET DIMENSIONS OF INPUT
numRows = int32(size(labelMatInput,1));

% RESHAPE IF NECESSARY
if ~ismatrix(labelMatInput)
	labelMat2d = reshape(labelMatInput, numRows, [],1);
else
	labelMat2d = labelMatInput;
end
if isempty(numCols)
	numCols = int32(size(labelMatInput,2));
else
	numCols = int32(numCols);
end
if isempty(firstFrameIdx)
	firstFrameIdx = single(1);
else
	firstFrameIdx = single(firstFrameIdx);
end



% ----------------------------------------------------
% INITIALIZE OUTPUT
% ----------------------------------------------------
S.Area = [];
S.BoundingBox = [];
S.Centroid = [];
S.FrameIdx = [];
S.LabelMatrix = reshape( uint16(labelMatInput) , numRows,numCols,[]);



% ----------------------------------------------------
% CONSTRUCT LOOKUP-TABLES FOR EACH LABEL IN INPUT
% ----------------------------------------------------
% FIND ROW/COL INDICES OF LABELED PIXELS
[labelRow,labelCol,labelList] = find(labelMat2d);

% BAIL IF NO LABELS PROVIDED
if isempty(labelRow)
	return
else
	numLabeledPixels = int32(numel(labelRow));
end

% USE REMAINDER TO GET COLUMN IN 3D ARRAY OF MULTIFRAME INPUT
labelFrameIdx = floor( (1./single(numCols)) .* single(labelCol-1));
labelCol = rem(int32(labelCol-1),int32(numCols))+1;

% INITIALIZE LUTs STORE ROW-SUB, COL-SUB, & LABEL
labelRowLut = gpuArray.zeros(lutSize,1,'single');
labelColLut = gpuArray.zeros(lutSize,1,'single');
labelListLut = gpuArray.zeros(lutSize,1,'single');
labelFrameIdxLut = gpuArray.zeros(lutSize,1,'single');

% FILL LUTs WITH SUBSCRIPTS & VALUES FROM FIND-OPERATION
labelRowLut(1:numLabeledPixels) = single(labelRow);
labelColLut(1:numLabeledPixels) = single(labelCol);
labelListLut(1:numLabeledPixels) = single(labelList);
labelFrameIdxLut(1:numLabeledPixels) = single(labelFrameIdx);


% ----------------------------------------------------
% FIND UNIQUE LABELS & INITIALIZATION CONSTANTS FOR THREADS
% ----------------------------------------------------

% [sortedLabelList, sortListIdx] = sort(labelList, 1, 'ascend');
% [uniqueLabelList, uniqueLabelFirstListIdx] = unique(sortedLabelList, 'first');

% FIND UNIQUE OCCURRENCES OF EACH LABEL
[uniqueLabelList, uniqueLabelFirstListIdx] = unique(labelList, 'first');
uniqueLabelList = int32(uniqueLabelList);
uniqueLabelFirstListIdx = int32(uniqueLabelFirstListIdx);

% INITIALIZATION CONSTANTS FOR MIN/MAX & SUM OPERATIONS
xy0min = single(inf);
xy0max = single(0);
xy0sum = single(0);
r0sum = single(0);



% ----------------------------------------------------
% RUN SUBFUNCTION W/ARRAYFUN-> CALL/COMPILE CUDA KERNEL
% ----------------------------------------------------
if isempty(labelArea)
	% (LESS-EFFICIENT METHOD MUST CALL UNIQUE A SECOND TIME)
	[~, uniqueLabelLastListIdx] = unique(labelList, 'last');
		
	% RUN FIRSTIDX -> LASTIDX KERNEL
	[xMin, xMax, yMin, yMax, xSum, ySum, rSum, kIdx] = ...
		arrayfun( @accumulateLabelPropsIdx2IdxKernel, uniqueLabelList, uniqueLabelFirstListIdx, uniqueLabelLastListIdx);
	
else
	% (FASTER METHOD CAN USE PRE-COMPUTED LABEL-AREA PROVIDED WITH INPUT)
	labelArea = uint32(labelArea(:));
	
	% RUN FIRSTIDX -> AREAFILLED KERNEL
	[xMin, xMax, yMin, yMax, xSum, ySum, rSum, kIdx] = ...
		arrayfun( @accumulateLabelPropsUntilAreaKernel, uniqueLabelList, uniqueLabelFirstListIdx, labelArea);
	
end



% ----------------------------------------------------
% EXTRACT OUTPUT & STORE IN 'REGIONPROPS'ESQUE STRUCTURE
% ----------------------------------------------------
% AREA
a = rSum;
S.Area = a;

% BOUNDING-BOX
S.BoundingBox = [xMin, yMin, xMax-xMin, yMax-yMin];

% CENTROID
S.Centroid = bsxfun(@times, [xSum ySum], 1./a);

% FRAME-INDEX
S.FrameIdx = kIdx;

% LABEL-MATRIX (RESHAPED 2D->3D)
S.LabelMatrix = reshape( uint16(labelMat2d) , numRows,numCols,[]);










% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [xmin,xmax,ymin,ymax,xsum,ysum,rsum,kidx] = accumulateLabelPropsIdx2IdxKernel(ulab,ulabidx1,ulabidx2)
		
		% INITIALIZE OUTPUT
		idx = int32(min(max(ulabidx1,1),numLabeledPixels));
		xmin = xy0min;
		ymin = xy0min;
		xmax = xy0max;
		ymax = xy0max;
		xsum = xy0sum;
		ysum = xy0sum;
		rsum = r0sum;
		
		% RETRIEVE FRAME IDX IN LOCAL STACK & ADD TO INITIAL FRAME
		kidx = labelFrameIdxLut(idx) + firstFrameIdx;
				
		% LOOP FROM FIRST TO LAST INDEX FOR CURRENT UNIQUE LABEL
		while (idx <= ulabidx2)
			% CHECK IF ACQUIRED LABEL MATCHES LOCAL LABEL
			islabelmatch = (ulab == labelListLut(idx));
			
			% UPDATE LOCAL LABEL PROPS
			if islabelmatch
				
				% AREA ACCUMULATION
				rsum = rsum + 1;
				
				% COLUMN IDX
				% 				x2d = labelCol(idx);
				% 				x = rem( x2d-1, numCols) + 1;
				x = labelColLut(idx);
				xsum = xsum + x;
				xmin = min( xmin, x);
				xmax = max( xmax, x);
				
				% ROW IDX
				y = labelRowLut(idx);
				ymin = min( ymin, y);
				ymax = max( ymax, y);				
				ysum = ysum + y;				
				
			end
			
			% INCREMENT
			if (idx < numLabeledPixels)
				idx = idx + 1;
			else
				break
			end
			
		end
		
		% RETURN CENTER XY (TODO)
		% cx = xsum/rsum; cy = ysum/rsum;
		
	end

	function [xmin,xmax,ymin,ymax,xsum,ysum,rsum,kidx] = accumulateLabelPropsUntilAreaKernel(ulab,ulabidx1,ulabarea)
		
		% INITIALIZE OUTPUT
		idx = int32(min(max(ulabidx1,1),numLabeledPixels));
		xmin = xy0min;
		ymin = xy0min;
		xmax = xy0max;
		ymax = xy0max;
		xsum = xy0sum;
		ysum = xy0sum;
		rsum = r0sum;
		
		% RETRIEVE FRAME IDX IN LOCAL STACK & ADD TO INITIAL FRAME
		kidx = labelFrameIdxLut(idx) + firstFrameIdx;
				
		% LOOP FROM FIRST TO LAST INDEX FOR CURRENT UNIQUE LABEL
		while (rsum < ulabarea) && (idx <= numLabeledPixels)
			% CHECK IF ACQUIRED LABEL MATCHES LOCAL LABEL
			islabelmatch = (ulab == labelListLut(idx));
			
			% UPDATE LOCAL LABEL PROPS
			if islabelmatch
				
				% AREA ACCUMULATION
				rsum = rsum + 1;
				
				% COLUMN IDX
				% 				x2d = labelCol(idx);
				% 				x = rem( x2d-1, numCols) + 1;
				x = labelColLut(idx);
				xsum = xsum + x;
				xmin = min( xmin, x);
				xmax = max( xmax, x);
				
				% ROW IDX
				y = labelRowLut(idx);
				ymin = min( ymin, y);
				ymax = max( ymax, y);
				ysum = ysum + y;
				
			end
			
			% INCREMENT
			idx = idx + 1;
			
		end
		
		% RETURN CENTER XY (TODO)
		% cx = xsum/rsum; cy = ysum/rsum;
		
	end

end


















