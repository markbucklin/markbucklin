function [S, M] = updateRegisteredRegionsRunGpuKernel(Sdet, Sreg, seedMap, P0)
% LABELEDREGIONPROPFILTEREDUPDATERUNGPUKERNEL - Update connected-component region-property statistics
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
%				W -			Used as the recursive filter update coefficient -> alpha. To instead compute a pure
%								mean-update set this to 1.
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
%		UPDATESTATISTICSGPU, TEMPORALARFILTERRUNGPUKERNEL, LABELEDREGIONSTATISTICUPDATERUNGPUKERNEL
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
if nargin < 4
	P0 = [];
if nargin < 3
	seedMap = [];
	if nargin < 2
		Sreg = [];
	end
end
end

% CHECK SEED PROBABILITY MAP
if isempty(P0)
	P0 = gpuArray.zeros(size(Sreg.LabelMatrix), 'single');
	P0(seedMap) = 0.5;
end

% CHECK SEED -> REGION-IDX MAP
if isempty(seedMap)
	seedMap = gpuArray.zeros(size(Sreg.LabelMatrix), 'uint16');
	% return?
elseif islogical(seedMap)
	bwSeed = seedMap;
	seedMap = uint16(seedMap);
	seedMap(bwSeed) = Sreg.LabelMatrix(bwSeed);
	if isfield(Sreg, 'SecondaryLabelMatrix')
		ksec=0;
		while ksec < size(Sreg.SecondaryLabelMatrix,3)
			ksec = ksec + 1;
			lm2 = Sreg.SecondaryLabelMatrix(:,:,ksec);
			bwSeed = bwSeed & (seedMap==0);
			seedMap(bwSeed) = lm2(bwSeed);
		end
	end
else
	seedMap = uint16(seedMap);
end

% RETURN IF THERE ARE NOW DETECTED REGIONS TO UPDATE WITH
if (numel(Sdet.Area)<1)
	return
end

% GET SIZE OF LABEL MATRIX (IMAGE) & NUMBER OF NEW LABELS (CONNECTED COMPONENTS)
[numRows,numCols,numFrames] = size(Sdet.LabelMatrix);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));

% GET POPULATION OF REGISTERED & DETECTED (NEW) REGIONS
numDetRegions = int32(size(Sdet.Area,1));
% detIdxSubs = uint16(1:numDetRegions);
% regionRegAvailable = Sreg.Area<1;
% numRegRegions = sum(~regionRegAvailable);
% lastRegIdx = find( ~regionRegAvailable, 1, 'last');
% regIdxSubs = uint16(1:lastRegIdx)';
lutSize = 4096;

% GET REGISTERED REGION SEED ROW/COL SUBSCRIPTS
[seedRowSubs, seedColSubs, regIdx] = find(seedMap);
% seedRowSubs = Sreg.RegionSeedSubs(regIdxSubs,1);
% seedColSubs = Sreg.RegionSeedSubs(regIdxSubs,2);
frameSubs = int32(gpuArray.colon(1, numFrames));


% ----------------------------------------------------
% FILL LUTs WITH REGION-PROPS FROM STRUCTURED INPUT
% ----------------------------------------------------
% A - AREA
Adet = gpuArray.zeros(lutSize,1,'single');
Adet(1:numDetRegions,1) = single(Sdet.Area);

% B - BOUNDING BOX
Bdet = gpuArray.zeros(lutSize,4,'single');
Bdet(1:numDetRegions,:) = single(Sdet.BoundingBox);

% C - CENTROID
Cdet = gpuArray.zeros(lutSize,2,'single');
Cdet(1:numDetRegions,:)  = single(Sdet.Centroid);

% K - FRAME IDX
Kdet = gpuArray.zeros(lutSize,1,'single');
Kdet(1:numDetRegions,:)  = single(Sdet.FrameIdx);

% IDX - LABEL MATRIX
IDXMAPdet = uint16(Sdet.LabelMatrix);

% % A - AREA
% Areg = single(Sreg.Area);
% 
% % B - BOUNDING BOX
% Breg = single(Sreg.BoundingBox);
% 
% % C - CENTROID
% Creg = single(Sreg.Centroid);
% 
% % IDX - LABEL MATRIX
% IDXMAPreg = uint16(Sreg.LabelMatrix);


S = Sreg;



% ----------------------------------------------------
% RUN UPDATE SUBFUNCTION -> CALL/COMPILE CUDA KERNEL
% ----------------------------------------------------
[Qmap, P, regIdx, detIdx] = arrayfun(...
	@seedDetectedRegionKernelFcn, seedRowSubs, seedColSubs, regIdx, frameSubs);

% CONSTRUCTING MAPPING INDEX VARIABLES
if numFrames > 1
	[Pk, pkMaxIdx] = max(P, [],2);
	qRowUpdate = any(Qmap,2);
	qLinIdx = sub2ind(size(Qmap), find(qRowUpdate), pkMaxIdx(qRowUpdate));
	% 	qLinIdx = single(regIdxSubs(qRowUpdate)) + single(lastRegIdx).*(pkMaxIdx(qRowUpdate)-1);
	Qm = qLinIdx;
	Pk = Pk(qRowUpdate);
else
	Pk = P;
	Qm = Qmap;
end
Qr = regIdx(Qm);
Qd = detIdx(Qm);

% CREATE REMAPPING LUT
REGIDXLUT = gpuArray.zeros(65536,1, 'uint16');
REGIDXLUT(Qd+1) = uint16(Qr);

% RE-MAP LABEL MATRIX VALUES TO INSTEAD MAP INTO 'REGISTERED REGIONS' INDICES
IDXMAPdet = arrayfun(@lookup, IDXMAPdet);




% ----------------------------------------------------
% EXTRACT OUTPUT & STORE IN 'REGIONPROPS'ESQUE STRUCTURE
% ----------------------------------------------------
% AREA
S.Area(Qr, :) = Sdet.Area(Qd, :);

% BOUNDING-BOX
S.BoundingBox(Qr, :) = Sdet.BoundingBox(Qd, :);

% CENTROID
S.Centroid(Qr, :) = Sdet.Centroid(Qd, :);

% FRAME-INDEX
% S.FrameIdx(Qr, :) = Sdet.FrameIdx(Qd, :);

% LABEL-INDEX
S.RegionSeedSubs(Qr, :) = Sdet.RegionSeedSubs(Qd, :);
S.RegionSeedIdx(Qr, :) = Sdet.RegionSeedIdx(Qd, :);

detRegIdxMat = max(IDXMAPdet, [], 3);
lmUpdateIdx = find(detRegIdxMat(:) ~= 0);
S.LabelMatrix(lmUpdateIdx) = detRegIdxMat(lmUpdateIdx);

% TODO: secondary idxmat


M.Qr = Qr;
M.Qd = Qd;
M.Qm = Qm;
M.P = P;
M.Pk = Pk;
% M.LabelMatrix = IDXMAPdet;






% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [q, p, ridx, didx] = seedDetectedRegionKernelFcn(seedrow,seedcol,ridx,k)
		
		% RETRIEVE IDX-VALUE FROM DETECTED-REGION LABEL MATRIX @ SEED LOCATION
		didx = IDXMAPdet(seedrow,seedcol,k);
		
		% ---------------------------------------
		% HIT/MISS CHECK SEEDED-PIXEL VALUE
		% ---------------------------------------
		if (didx < 1) || isnan(didx) || isinf(didx)
			
			% 0|NAN|INF: MISS -> SET OUTPUT VARS & RETURN
			q = false;
			p = single(0);
			% 			a = single(nan);
			% 			bx = single(nan);
			% 			by = single(nan);
			% 			dx = single(nan);
			% 			dy = single(nan);
			% 			cx = single(nan);
			% 			cy = single(nan);
			% 			kidx = single(nan);
			return
			
		end
		
		% OTHERWISE: HIT -> CONTINUE FOR FURTHER SCRUTINY
		q = true;
		
		% Y & X FROM ROW/COLUMN SUBSCRIPTS -> FLOAT
		y = single(seedrow);
		x = single(seedcol);
		
		
		% ---------------------------------------
		% CHECK REGION-PROP SIMILARITY
		% ---------------------------------------
		
		% CENTROID SEPARATION
		cx = Cdet(didx,1);
		cy = Cdet(didx,2);
		% 		c = cx + 1i*cy;
		
		% AREA
		a = Adet(didx,1);
		
		% CORNER OF BOUNDING BOX
		bx = Bdet(didx,1);
		by = Bdet(didx,2);
		% 		bbc = bx + 1i*by;
		
		% DIMENSIONS OF BOUNDING-BOX
		dx = Bdet(didx,3);
		dy = Bdet(didx,4);
		% 		bbw = dx + 1i*dy;
		
		% FRAME IDX
		% 		kidx = Kdet(didx,1);
		
		% PROXIMITY TO DETECTED REGION BORDER (NORMALIZED)
		bxn = min( abs(x - bx), abs(bx + dx + 0.5 - x));
		bxn = 2*bxn/dx;
		byn = min( abs(y - by), abs(by + dy + 0.5 - y));
		byn = 2*byn/dy;
		% 		bxyn = bxn + 1i*byn;
		
		% PROXIMITY TO DETECTED REGION CENTROID (NORMALIZED)
		cxn = 2*(cx - x)/dx;
		cyn = 2*(cy - y)/dy;
		% 		cxyn = cxn + 1i*cyn;
		
		% SEED PROBABILITY
		p = max(1 - sqrt(cxn^2 + cyn^2), 0) * sqrt(bxn^2 + byn^2);
		% 		p = max(1 - (abs(cxyn)), 0) * bxn * byn;
		
		if p < .1
			q = false;
		end
		
		
	end
	
	function out = lookup(img)
		% 1-based indexing
		out = REGIDXLUT(int32(img)+int32(1));
		
	end




end




% [Qmap, P, regIdx, detIdx, bbCornerX, bbCornerY, bbWidth, bbHeight, Cx, Cy, roiArea, roiFrameIdx] = ...
% 	arrayfun(	@seedDetectedRegionKernelFcn, seedRowSubs, seedColSubs, regIdxSubs, frameSubs);
% 
% function [q,p, ridx,didx, bx,by,dx,dy,cx,cy,a,kidx] = seedDetectedRegionKernelFcn(seedrow,seedcol,ridx,k)
%
% % ----------------------------------------------------
% % EXTRACT OUTPUT & STORE IN 'REGIONPROPS'ESQUE STRUCTURE
% % ----------------------------------------------------
% % AREA
% S.Area = roiArea(Qmap);
% 
% % BOUNDING-BOX
% S.BoundingBox = [bbCornerX(Qmap), bbCornerY(Qmap), bbWidth(Qmap), bbHeight(Qmap)];
% 
% % CENTROID
% S.Centroid = [Cx(Qmap) Cy(Qmap)];
% 
% % FRAME-INDEX
% S.FrameIdx = roiFrameIdx(Qmap);
% 
% % LABEL-INDEX
% S.RegionSeedSubs = int32(round([Cy(Qmap) Cx(Qmap)]));







% ----------------------------------------------------
% EXTRACT CONCATENATED OUTPUT & STORE OUTPUT IN STRUCTURE
% ----------------------------------------------------
% AREA
% Sreg.MeanArea = Amean;
%
% % MEAN BOUNDING-BOX CORNER
% Sreg.MeanBBoxCorner = Bmean;
%
% % DIMENSIONS (BBOX WIDTH & HEIGHT)
% Sreg.MeanBBoxSize = Dmean;
%
% % MEAN CENTROID
% Sreg.MeanCentroid = Cmean;
%
% % NORMALIZED DISTANCE TO NEAREST BOUNDING-BOX EDGE
% Sreg.MeanBoundaryDist = BDmean;
%
% % CENTROID DISTANCE
% Sreg.MeanCentroidDist = CDmean;
%
% % SEED PROBABILITY
% Sreg.SeedProbability = Pseed;
%
% % COUNT SINCE LAST LABEL
% Sreg.CountSinceLastLabel = Ksince;
%
% % GLOBAL & LABEL COUNTER
% Sreg.LabelCount = N;
% Sreg.FrameCount = single(Ntotal) + numFrames;


% pxNewLabelCount = uint16(sum(logical(LM),3));
