function stat = labeledRegionStatisticUpdateRunGpuKernel_old(S, stat)
% LABELEDREGIONSTATISTICUPDATERUNGPUKERNEL - Update connected-component region-property statistics
%		for all labeled pixels using GPUARRAY INPUT and CUDA kernel, compiled using ARRAYFUN
%
%
%
% Description:
% ------------
%		Updates complex valued labeled-region statistics associated with each pixel, including minimum,
%		maximum, and mean values for label area, relative distance to top and left edges of
%		bounding-box, relative distances to bottom and right edges of bounding box, and relative
%		distance to the centroid of each pixels assigned label. Unlabeled pixels are not updated. All
%		statistics are complex valued to allow for relative distance to be expressed in the form x+iy
%		(or more accurately dX+i*dY), although the imaginary component of area statistics is currently
%		unused.
%
%		This function is called from the class-method
%		IGNITION.PIXELLABEL>APPLYLABELEDREGIONSTATISTICUPDATE. It follows a call from another
%		IGNITION.PIXELLABEL method to the function FINDCONNECTEDREGIONPROPSRUNGPUKERNEL, which
%		provides the appropriately structured 1st input argument, 'S'.
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
%		The constant variable 'lutSize' is currently hard-coded in (set to 4096) which can be
%		interpreted as the maximum number of labeled regions (connected-components) this function
%		expects to process at any one time. This may need to be increased at some point. Increasing may
%		have detrimental effect on performance, but is so far untested and the change in performance may
%		in fact be negligible. This constant value had to be set to keep Look-up-table-like arrays a
%		consistent size throughout a series of calls (despite a changing number of labels actually
%		input). Otherwise calls to the precompiled CUDA-kernel via arrayfun sporadically results in
%		index-out-of-bounds errors (a nightmare to diagnose/debug initially as individual calls to this
%		function would never seemingly request out-of-bounds index). If increase, is necessary, might as
%		well increase to 65596.
%
%		Benchmarks - 0.75ms/frame
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




% ----------------------------------------------------
% MANAGE/EXAMINE INPUT
% ----------------------------------------------------
% INITIALIZE 2ND INPUT-ARGUMENT TO EMPTY IF NOT PROVIDED (ON FIRST CALL)
if nargin < 2
	stat = [];
end

% RETURN IF EMPTY
if numel(S.Area)<1
	return
end

% GET SIZE OF LABEL MATRIX (IMAGE) & NUMBER OF NEW LABELS (CONNECTED COMPONENTS)
[numRows,numCols,numFrames] = size(S.LabelMatrix);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
numLabels = int32(size(S.Area,1));
lutSize = 4096;



% ----------------------------------------------------
% FILL LUTs WITH REGION-PROPS FROM STRUCTURED INPUT
% ----------------------------------------------------
% A - AREA
A = gpuArray.zeros(lutSize,1,'single');
A(1:numLabels,1) = single(S.Area);

% B - BOUNDING BOX
B = gpuArray.zeros(lutSize,4,'single');
B(1:numLabels,:) = single(S.BoundingBox);

% C - CENTROID
C = gpuArray.zeros(lutSize,2,'single');
C(1:numLabels,:)  = single(S.Centroid);

% LM - LABEL MATRIX
LM = S.LabelMatrix;
pxNewLabelCount = uint16(sum(logical(LM),3));



% ----------------------------------------------------
% EXTRACT VARIABLES FROM I/O STRUCTURE (OR INITIALIZE)
% ----------------------------------------------------
if ~isempty(stat)
	% MEAN OF LABEL AREA
	Amean = stat.MeanArea;
	
	% NORMALIZED DISTANCE TO NEAREST BORDERS OF BOUNDING-BOX (x + iy)
	Bmean = stat.MeanBoundaryDist;
	
	% NORMALIZED DISTANCE FROM CENTROID (x + iy)
	Cmean = stat.MeanCentroidDist;
	
	% DIMENSIONS (WIDTH & HEIGHT) OF BOUNDING BOX (x + iy)
	Dmean = stat.MeanBBoxSize;
	
	% SEED-PROBABILITY (PROBABILITY THAT PIXEL IS REGION-CENTER -> SEED)
	Pseed = stat.SeedProbability;
	
	% COUNT (TIME) SINCE LAST LABEL
	Ksince = stat.CountSinceLastLabel;
	
	% PIXEL-WISE LABEL-COUNTER (INCREMENTS IF PIXEL IS LABELED)
	N = stat.LabelCount;
	
	% GLOBAL COUNTER (SCALAR -> INCREMENTS FOR EVERY FRAME)
	Ntotal = stat.FrameCount;
	
else
	% ----------------------------------------------------
	% INITIALIZE STATISTICS
	% ----------------------------------------------------
	% LABELED REGION AREA
	Amean = gpuArray.zeros(numRows,numCols,1, 'single');
	
	% NORMALIZED DISTANCE TO BORDERS OF BOUNDING-BOX (x + iy)
	Bmean = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	
	% NORMALIZED DISTANCE FROM CENTROID (x + iy)
	Cmean = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	
	% DIMENSIONS (WIDTH & HEIGHT) OF BOUNDING BOX (x + iy)
	Dmean = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	
	% SEED-PROBABILITY
	Pseed = gpuArray.zeros(numRows,numCols,1, 'single');
	
	% COUNT SINCE LAST LABEL
	Ksince = gpuArray.inf(numRows,numCols,1, 'single');
	
	% PIXEL-WISE LABEL-COUNTER (INCREMENTS IF PIXEL IS LABELED)
	N = gpuArray.zeros(numRows,numCols,1, 'single');
	
	% GLOBAL COUNTER (SCALAR -> INCREMENTS FOR EVERY FRAME)
	Ntotal = gpuArray.zeros(1,'single');
	
end



% ----------------------------------------------------
% RUN UPDATE SUBFUNCTION -> CALL/COMPILE CUDA KERNEL
% ----------------------------------------------------
[Amean,Bmean,Cmean,Dmean,Pseed,Ksince,N] = arrayfun(@pixelPropUpdateKernelFcn, rowSubs, colSubs, pxNewLabelCount);



% ----------------------------------------------------
% EXTRACT CONCATENATED OUTPUT & STORE OUTPUT IN STRUCTURE
% ----------------------------------------------------
% AREA
stat.MeanArea = Amean;

% NORMALIZED DISTANCE TO NEAREST BOUNDING-BOX EDGE
stat.MeanBoundaryDist = Bmean;

% CENTROID DISTANCE
stat.MeanCentroidDist = Cmean;

% DIMENSIONS (BBOX WIDTH & HEIGHT)
stat.MeanBBoxSize = Dmean;

% SEED PROBABILITY
stat.SeedProbability = Pseed;

% COUNT SINCE LAST LABEL
stat.CountSinceLastLabel = Ksince;

% GLOBAL & LABEL COUNTER
stat.LabelCount = N;
stat.FrameCount = single(Ntotal) + numFrames;







% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [amean,bmean,cmean,dmean,pseed,ksince,n] = pixelPropUpdateKernelFcn(rowIdx,colIdx,cnt)
		
		% RETRIEVE INITIAL VALUES (& INITIALIZE OUTPUT)
		amean = Amean(rowIdx,colIdx);
		bmean = Bmean(rowIdx,colIdx);
		cmean = Cmean(rowIdx,colIdx);
		dmean = Dmean(rowIdx,colIdx);
		pseed = Pseed(rowIdx,colIdx);
		ksince = Ksince(rowIdx,colIdx);
		
		% RETRIEVE LABEL-COUNT -> NUM PRIOR TIMES CURRENT PIXEL HAS BEEN LABELED
		n = N(rowIdx,colIdx);
		
		% ENABLE EARLY RETURN FOR SILENT PIXELS
		if cnt == 0
			ksince = ksince + numFrames;
			n = n + numFrames;
			return			
		end
		
		% INITIALIZE K
		k = single(0);
		
		% GET X, Y FROM ROW & COLUMN INDICES (CONVERT TO FLOAT)
		y = single(rowIdx);
		x = single(colIdx);
		
		
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR
		% ---------------------------------------
		while k < numFrames
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			
			% GET PIXEL-LABEL (IF ANY) FOR CURRENT FRAME
			m = LM(rowIdx,colIdx,k);
						
			% CHECK IF CURRENT PIXEL IS LABELED			
			if (m >= 1)
				% ---------------------------------------
				% [LABELED] INCRENT LABEL COUNT
				% ---------------------------------------
				n = n + single(1);
				invn = single(1/n);
				
				% ---------------------------------------
				% USE PIXEL LABEL AS LUT -> UPDATE MEAN
				% ---------------------------------------
				% AREA
				a = A(m,1);
				amean = amean + (a - amean)*invn;
				
				% DIMENSIONS OF BOUNDING-BOX
				dx = B(m,3);
				dy = B(m,4);
				d = dx + 1i*dy;
				dmean = dmean + (d - dmean)*invn;
				
				% BORDER PROXIMITY (NORMALIZED)
				bx = 2 * min( abs(x-B(m,1)), abs(B(m,1)+B(m,3)-x)) / dx;
				by = 2 * min( abs(y-B(m,2)), abs(B(m,2)+B(m,4)-y)) / dy;
				b = bx + 1i*by;
				bmean = bmean + (b - bmean)*invn;
				
				% CENTROID PROXIMITY
				cx = (C(m,1) - x) * 2;
				cy = (C(m,2) - y) * 2;
				c = (cx/dx) + 1i*(cy/dy);
				cmean = cmean + (c - cmean)*invn;
				
				% SEED PROBABILITY
				ps = max(1 - (abs(c)*abs(dmean)), 0) * bx * by;
				pseed = pseed + (ps - pseed)*invn;
				
				% COUNT SINCE LAST LABEL -> RESET
				ksince = single(0);
				
			else
				% ---------------------------------------
				% [NOT LABELED] INCREMEMENT COUNT SINCE LAST LABEL
				% ---------------------------------------
				ksince = ksince + single(1);
								
			end
			
			
		end
		
		
	end





end










