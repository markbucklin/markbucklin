function stat = labeledRegionStatisticUpdateRunGpuKernel(S, stat)
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
%		SCICADELIC.PIXELLABEL>APPLYLABELEDREGIONSTATISTICUPDATE. It follows a call from another
%		SCICADELIC.PIXELLABEL method to the function FINDCONNECTEDREGIONPROPSRUNGPUKERNEL, which
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
%		scicadelic.PixelLabel, FINDCONNECTEDREGIONPROPSRUNGPUKERNEL, scicadelic.StatisticCollector,
%		STATISTICCOLLECTORRUNGPUKERNEL
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
% MANAGE EMPTY INPUT (ON FIRST CALL)
% ----------------------------------------------------
if nargin < 2
	stat = [];
end
lutSize = 4096;


% ----------------------------------------------------
% EXTRACT COMPONENTS & SIZE-INFO FROM STRUCTURED INPUT
% ----------------------------------------------------
% A - AREA
A = single(S.Area);

% B - BOUNDING BOX
B = single(S.BoundingBox);

% C - CENTROID
C = single(S.Centroid);

% LM - LABEL MATRIX
LM = S.LabelMatrix;
pxNewLabelCount = uint16(sum(logical(LM),3));

% RETURN IF EMPTY
if numel(A)<1
	return
end

% GET SIZE OF LABEL MATRIX (IMAGE) & NUMBER OF NEW LABELS (CONNECTED COMPONENTS)
[numRows,numCols,numFrames] = size(LM);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
numLabels = int32(size(A,1));


% ----------------------------------------------------
% EXTRACT VARIABLES FROM I/O STRUCTURE (OR INITIALIZE)
% ----------------------------------------------------
if ~isempty(stat)
	% MIN/MAX/MEAN OF LABEL AREA
	Amin = stat.MinArea;
	Amax = stat.MaxArea;
	Amean = stat.MeanArea;
	
	% DISTANCE FROM UPPER-LEFT CORNER OF BOUNDING-BOX (x + iy)
	B1min = stat.MinExtent1;
	B1max = stat.MaxExtent1;
	B1mean = stat.MeanExtent1;
	
	% DISTANCE FROM LOWER-RIGHT CORNER OF BOUNDING-BOX (x + iy)
	B2min = stat.MinExtent2;
	B2max = stat.MaxExtent2;
	B2mean = stat.MeanExtent2;
	
	% DISTANCE FROM CENTROID (x + iy)
	Cmin = stat.MinRelativeCentroid;
	Cmax = stat.MaxRelativeCentroid;
	Cmean = stat.MeanRelativeCentroid;
	
	% PIXEL-WISE LABEL-COUNTER (INCREMENTS IF PIXEL IS LABELED)
	Lcount = stat.LabelCount;
	
	% GLOBAL COUNTER (SCALAR -> INCREMENTS FOR EVERY FRAME)
	N = stat.N;
	
else
	% ----------------------------------------------------
	% INITIALIZE STATISTICS (ALL COMPLEX TO FACILITATE CONCATENTATION) -> TODO: check
	% ----------------------------------------------------
	% MIN/MAX/MEAN OF LABEL AREA
	Amin = complex(gpuArray.inf(numRows,numCols,1, 'single'));
	Amax = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	Amean = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	
	% DISTANCE FROM UPPER-LEFT CORNER OF BOUNDING-BOX (x + iy)
	B1min = complex(gpuArray.inf(numRows,numCols,1, 'single'));
	B1max = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	B1mean = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	
	% DISTANCE FROM LOWER-RIGHT CORNER OF BOUNDING-BOX (x + iy)
	B2min = complex(gpuArray.inf(numRows,numCols,1, 'single'));
	B2max = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	B2mean = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	
	% DISTANCE FROM CENTROID (x + iy)
	Cmin = complex(gpuArray.inf(numRows,numCols,1, 'single'));
	Cmax = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	Cmean = complex(gpuArray.zeros(numRows,numCols,1, 'single'));
	
	% PIXEL-WISE LABEL-COUNTER (INCREMENTS IF PIXEL IS LABELED)
	Lcount = gpuArray.zeros(numRows,numCols,1, 'single');
	
	% GLOBAL COUNTER (SCALAR -> INCREMENTS FOR EVERY FRAME)
	N = gpuArray.zeros(1,'single');
		
end


% ----------------------------------------------------
% CONCATENATE FOR PARALLEL EXECUTION WHILE PRESERVING CODE SIMPLICITY
% ----------------------------------------------------
% PRIOR OUTPUT - MATRICES FOR PIXEL STATISTICS [RxCx4] (SLICED ALONG 3RD DIM)
ABCmin = cat(3, Amin, B1min, B2min, Cmin);
ABCmax = cat(3, Amax, B1max, B2max, Cmax);
ABCmean = cat(3, Amean, B1mean, B2mean, Cmean);

% CURRENT INPUT - LISTS OF REGION PROPS FOR EACH LABEL [Lx4] (SLICED ALONG 2ND DIM)
ABC = complex(gpuArray.zeros(lutSize,4,'single'));

% KEEP ABC CONSISTENT SIZE SO IT CAN BE USED AS AN UPDATEABLE LUT
ABC(1:numLabels,1) = complex(A);
ABC(1:numLabels,2) = B(:,1) + 1i*B(:,2);
ABC(1:numLabels,3) = (B(:,1)+B(:,3)-1) + 1i*(B(:,2)+B(:,4)-1);
ABC(1:numLabels,4) = C(:,1) + 1i*C(:,2);

% ENCODE THE SLICE EACH KERNEL SHOULD WORK ON IN [1x1x4] VECTOR
abcKernelCommandIdx = gpuArray(int32(reshape([1 2 3 4], 1, 1, 4)));


% ----------------------------------------------------
% RUN UPDATE SUBFUNCTION -> CALL/COMPILE CUDA KERNEL
% ----------------------------------------------------
[abcMin,abcMax,abcMean] = arrayfun(@statUpdateKernelFcn, rowSubs, colSubs, abcKernelCommandIdx, pxNewLabelCount);


% ----------------------------------------------------
% EXTRACT CONCATENATED OUTPUT & STORE OUTPUT IN STRUCTURE
% ----------------------------------------------------
% AREA
stat.MinArea = abcMin(:,:,1);
stat.MaxArea = abcMax(:,:,1);
stat.MeanArea = abcMean(:,:,1);

% BOUNDING-BOX-UL
stat.MinExtent1 = abcMin(:,:,2);
stat.MaxExtent1 = abcMax(:,:,2);
stat.MeanExtent1 = abcMean(:,:,2);

% BOUNDING-BOX-DR
stat.MinExtent2 = abcMin(:,:,3);
stat.MaxExtent2 = abcMax(:,:,3);
stat.MeanExtent2 = abcMean(:,:,3);

% CENTROID
stat.MinRelativeCentroid = abcMin(:,:,4);
stat.MaxRelativeCentroid = abcMax(:,:,4);
stat.MeanRelativeCentroid = abcMean(:,:,4);

% GLOBAL & LABEL COUNTER
stat.LabelCount = Lcount + single(pxNewLabelCount);
stat.N = single(N) + numFrames;

% TODO: regularize Lcount with a neighborhood non-linear averaging filter







% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [abcmin,abcmax,abcmean] = statUpdateKernelFcn(y,x,kerncmd,chunklcnt)
		
		% RETRIEVE INITIAL VALUES (& INITIALIZE OUTPUT)
		abcmin = ABCmin(y,x,kerncmd);
		abcmax = ABCmax(y,x,kerncmd);
		abcmean = ABCmean(y,x,kerncmd);
		
		% ENABLE EARLY RETURN FOR SILENT PIXELS
		if chunklcnt == 0
			return
		end
		
		% INITIALIZE N, K
		n = single(N);% unnused? todo
		k = single(0);
		
		% REPRESENT CURRENT PIXEL POSITION IN COMPLEX FORM (x+iy)
		px = single(x) + 1i*single(y);
		
		% RETRIEVE LABEL-COUNT -> NUM PRIOR TIMES CURRENT PIXEL HAS BEEN LABELED
		lcnt = Lcount(y,x);
		
		% ---------------------------------------
		% LOOP THROUGH SEQUENTIAL FRAMES FOR 1-BY-1-UPDATE
		% ---------------------------------------
		while k < numFrames
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1;
			
			% CHECK IF CURRENT PIXEL IS LABELED
			lidx = LM(y,x,k);
			if (lidx >= 1) && (lidx <= numLabels)
				% INCRENT LABEL COUNT
				lcnt = lcnt + 1;
				
				% USE LABEL MATRIX AS LOOKUP-TABLE INTO ABC
				abc = single(ABC(lidx, kerncmd));
				
				% MEASURE DISTANCE RELATIVE TO CURRENT PIXEL-POSITION (EXCEPT AREA)
				if (kerncmd>1)
					
					% DISPLACEMENT FROM REGION CENTROID & BOUNDING-BOX LIMITS
					abc = single(abc - px);
					
					% BORDER DISTANCE -> ABSOLUTE VALUES ONLY	(ASSUME PIXEL IS INSIDE)
					if (kerncmd<4)
						abs(real(abc)) + 1i*abs(imag(abc));
						
					end
				end
				
				% UPDATE MIN
				abcmin = min(abcmin, abc);
				
				% UPDATE MAX
				abcmax = max(abcmax, abc);
								
				% UPDATE MEAN
				d = abc - abcmean;
				dk = d/lcnt;
				abcmean = abcmean + dk;
				
			else
				% AVOIDING INDEX OUT OF BOUNDS... (removeable?? todo)
				break
				
			end
			
			
		end
		
		
	end









end







