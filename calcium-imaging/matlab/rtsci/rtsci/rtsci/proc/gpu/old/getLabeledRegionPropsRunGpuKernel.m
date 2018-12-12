function S = getLabeledRegionPropsRunGpuKernel(labelMatInput, firstFrameIdx, numCols)
% GETLABELEDREGIONPROPSRUNGPUKERNEL - Find region-properties for regions specified using
% label-matrix input -> was attempting to avoid using the function UNIQUE or SORT
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
%		This function is called from the class-method rtsci.PixelLabel>getLabeledRegionProps
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
%		For 16 frames input this function exceeds 7x builtin regionprops function
%
%
%
% See Also:
%		rtsci.PixelLabel, LABELEDREGIONSTATISTICUPDATERUNGPUKERNEL, rtsci.StatisticCollector,
%		UPDATESTATISTICSGPU
%
%
%		Reference page in Help browser:
%		<a href="matlab:doc('getLabeledRegionPropsRunGpuKernel')">getLabeledRegionPropsRunGpuKernel</a>
%
%
%
%
%   Mark Bucklin
%		7/30/2016




% ----------------------------------------------------
% MANAGE/EXAMINE INPUT
% ----------------------------------------------------
% HANDLE VARIABLE/EMPTY INPUT
if nargin < 3
	numCols = [];
	if nargin < 2
		firstFrameIdx = [];
	end
end
lutSize = 1048576; % numpixels?

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
S.RegionSeedIdx = [];
S.RegionSeedSubs = [];
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



% ----------------------------------------------------
% FIND TRANSITIONS IN UNSORTED LABEL-LIST
% ----------------------------------------------------
[sortedLabelList, sortListIdx] = sort(labelList, 1, 'ascend');
transitionIdx = find(diff(sortedLabelList));
blockStart = int32(cat(1, 1, transitionIdx + 1));
blockStop = int32(cat(1, transitionIdx, numel(labelRow)));
blockLabel = sortedLabelList(blockStart);



% ----------------------------------------------------
% INITIALIZATION CONSTANTS FOR THREADS
% ----------------------------------------------------
% INITIALIZE LUTs STORE ROW-SUB, COL-SUB, & LABEL
labelRowLut = gpuArray.zeros(lutSize,1,'single');
labelColLut = gpuArray.zeros(lutSize,1,'single');
labelFrameIdxLut = gpuArray.zeros(lutSize,1,'single');

% FILL LUTs WITH SUBSCRIPTS & VALUES FROM FIND-OPERATION
labelRowLut(1:numLabeledPixels) = single(labelRow(sortListIdx));
labelColLut(1:numLabeledPixels) = single(labelCol(sortListIdx));
labelFrameIdxLut(1:numLabeledPixels) = single(labelFrameIdx(sortListIdx));

% INITIALIZATION CONSTANTS FOR MIN/MAX & SUM OPERATIONS
xy0min = single(inf);
xy0max = single(0);
xy0sum = single(0);
roiarea0 = single(0);



% ----------------------------------------------------
% RUN SUBFUNCTION W/ARRAYFUN-> CALL/COMPILE CUDA KERNEL
% ----------------------------------------------------
[bbCornerX, bbCornerY, bbWidth, bbHeight, Cx, Cy, roiArea, roiFrameIdx] = ...
	arrayfun( @accumulateLabelPropsIdx2IdxKernel, blockStart, blockStop);



% ----------------------------------------------------
% EXTRACT OUTPUT & STORE IN 'REGIONPROPS'ESQUE STRUCTURE
% ----------------------------------------------------
% AREA
S.Area = roiArea;

% BOUNDING-BOX
S.BoundingBox = [bbCornerX, bbCornerY, bbWidth, bbHeight];

% CENTROID
S.Centroid = [Cx Cy];

% FRAME-INDEX
S.FrameIdx = roiFrameIdx;

% LABEL-INDEX
seedRowSubs = round(Cy);
seedColSubs = round(Cx);
seedIdx = single((seedColSubs-1)).*single(numRows) + single(seedRowSubs);
S.RegionSeedSubs = int32([seedRowSubs seedColSubs]);
S.RegionSeedIdx = int32(seedIdx);

% LABEL-MATRIX (RESHAPED 2D->3D)
S.LabelMatrix = reshape( uint16(labelMat2d) , numRows,numCols,[]);










% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [bbx,bby,bbw,bbh,cx,cy,roiarea,kidx] = accumulateLabelPropsIdx2IdxKernel(ulabidx1,ulabidx2)
		
		% INITIALIZE OUTPUT
		idx = ulabidx1;
		xmin = xy0min;
		ymin = xy0min;
		xmax = xy0max;
		ymax = xy0max;
		xsum = xy0sum;
		ysum = xy0sum;
		roiarea = roiarea0;
		
		% RETRIEVE FRAME IDX IN LOCAL STACK & ADD TO INITIAL FRAME
		kidx = labelFrameIdxLut(idx) ;
		framecol2d0 = single(numCols) * (kidx);
		kidx = kidx + firstFrameIdx;
		
		% LOOP FROM FIRST TO LAST INDEX FOR CURRENT UNIQUE LABEL
		while (idx <= ulabidx2)
			
			% AREA ACCUMULATION
			roiarea = roiarea + 1; % m00 = m00 + qLut(idx);
			
			% COLUMN IDX
			x2d = labelColLut(idx);
			x = x2d - framecol2d0;
			xsum = xsum + x;
			xmin = min( xmin, x);
			xmax = max( xmax, x);
			
			% ROW IDX
			y = labelRowLut(idx);
			ymin = min( ymin, y);
			ymax = max( ymax, y);
			ysum = ysum + y;
			
			% INCREMENT
			idx = idx + 1;
			
		end
		
		% RETURN CENTER XY		
		cx = xsum/roiarea;
		cy = ysum/roiarea;
		
		% RETURN UPPER-LEFT CORNER & DIMENSIONS OF BOUNDING BOX
		bbx = xmin - .5;
		bby = ymin - .5;
		bbw = xmax - xmin + 1;
		bbh = ymax - ymin + 1;
		
	end

end


















