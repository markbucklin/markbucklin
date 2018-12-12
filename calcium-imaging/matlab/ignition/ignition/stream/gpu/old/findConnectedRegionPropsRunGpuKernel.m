function S = findConnectedRegionPropsRunGpuKernel(labelMatInput, numCols, labelArea)
% LABELEDREGIONSTATISTICUPDATERUNGPUKERNEL - Update connected-component region-property statistics
%		for all labeled pixels using GPUARRAY INPUT and CUDA kernel, compiled using ARRAYFUN
%
%   ============>>> renamed to getLabeledRegionPropsRunGpuKernel()
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
%				>> stat = labeledRegionStatisticUpdateRunGpuKernel(S);
%				>> stat = labeledRegionStatisticUpdateRunGpuKernel(S, stat);
%
%
%		Input:
%				S -			Structure with the fields: 'Area', 'BoundingBox', 'Centroid', & 'LabelMatrix'. Given
%								as output from the function FINDCONNECTEDREGIONPROPSRUNGPUKERNEL.
%
%				stat -	Structure holding statistics and counters calculated during prior calls to this
%								function. This argument should be omitted or left empty (i.e. []) for the initial
%								call to this function. The function will appropriately initialize this input/output
%								structure. All subsequent calls should provide here as input the structure returned
%								as output from the previous call.
%
%		Output:
%				stat -	Updated (and initialized) structure with identical format and dimension as input
%								described above containing regions-prop stats relative to each labeled pixel.
%
%
%
% Notes:
% ------------
%		(TODO: pad to ensure dimensions are multiple of 32)
%
%
%
% See Also:
%		ignition.PixelLabel, FINDCONNECTEDREGIONPROPSRUNGPUKERNEL, ignition.StatisticCollector,
%		UPDATESTATISTICSGPU
%
%
%		Reference page in Help browser:
%		<a href="matlab:doc('labeledRegionStatisticUpdateRunGpuKernel')">labeledRegionStatisticUpdateRunGpuKernel</a>
%
%
%
%
%   Copyright 2015 Mark Bucklin


% 
% 




% ----------------------------------------------------
% MANAGE/EXAMINE INPUT
% ----------------------------------------------------
% HANDLE VARIABLE/EMPTY INPUT
if nargin < 2
	numCols = [];
	if nargin < 3
		labelArea = [];
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

% INITIALIZE OUTPUT
S.Area = [];
S.BoundingBox = [];
S.Centroid = [];
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
	numLabels = int32(numel(labelRow));
end

% USE REMAINDER TO GET COLUMN IN 3D ARRAY OF MULTIFRAME INPUT
labelCol = rem(int32(labelCol-1),int32(numCols))+1;

% INITIALIZE LUTs STORE ROW-SUB, COL-SUB, & LABEL
labelRowLut = gpuArray.zeros(lutSize,1,'single');
labelColLut = gpuArray.zeros(lutSize,1,'single');
labelListLut = gpuArray.zeros(lutSize,1,'single');

% FILL LUTs WITH SUBSCRIPTS & VALUES FROM FIND-OPERATION
numLabeledPixels = numel(labelRow);
labelRowLut(1:numLabeledPixels) = single(labelRow);
labelColLut(1:numLabeledPixels) = single(labelCol);
labelListLut(1:numLabeledPixels) = single(labelList);



% ----------------------------------------------------
% FIND UNIQUE LABELS & INITIALIZATION CONSTANTS FOR THREADS
% ----------------------------------------------------
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
	[xMin, xMax, yMin, yMax, xSum, ySum, rSum] = ...
		arrayfun( @accumulateLabelPropsIdx2IdxKernel, uniqueLabelList, uniqueLabelFirstListIdx, uniqueLabelLastListIdx);
	
else
	% (FASTER METHOD CAN USE PRE-COMPUTED LABEL-AREA PROVIDED WITH INPUT)
	labelArea = uint32(labelArea(:));
	
	% RUN FIRSTIDX -> AREAFILLED KERNEL
	[xMin, xMax, yMin, yMax, xSum, ySum, rSum] = ...
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

% LABEL-MATRIX (RESHAPED 2D->3D)
S.LabelMatrix = reshape( uint16(labelMat2d) , numRows,numCols,[]);










% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [xmin,xmax,ymin,ymax,xsum,ysum,rsum] = accumulateLabelPropsIdx2IdxKernel(ulab,ulabidx1,ulabidx2)
		
		% INITIALIZE OUTPUT
		idx = int32(min(max(ulabidx1,1),numLabels));
		xmin = xy0min;
		ymin = xy0min;
		xmax = xy0max;
		ymax = xy0max;
		xsum = xy0sum;
		ysum = xy0sum;
		rsum = r0sum;
				
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
			if (idx < numLabels)
				idx = idx + 1;
			else
				break
			end
			
		end
		
		% RETURN CENTER XY (TODO)
		% cx = xsum/rsum; cy = ysum/rsum;
		
	end

	function [xmin,xmax,ymin,ymax,xsum,ysum,rsum] = accumulateLabelPropsUntilAreaKernel(ulab,ulabidx1,ulabarea)
		
		% INITIALIZE OUTPUT
		idx = int32(min(max(ulabidx1,1),numLabels));
		xmin = xy0min;
		ymin = xy0min;
		xmax = xy0max;
		ymax = xy0max;
		xsum = xy0sum;
		ysum = xy0sum;
		rsum = r0sum;
				
		% LOOP FROM FIRST TO LAST INDEX FOR CURRENT UNIQUE LABEL
		while (rsum < ulabarea) && (idx <= numLabels)
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


















