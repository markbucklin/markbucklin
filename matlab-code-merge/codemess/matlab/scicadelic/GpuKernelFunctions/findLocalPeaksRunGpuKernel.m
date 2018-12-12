function Qpeak = findLocalPeaksRunGpuKernel(Q, peakRadius, peakMask) % peakMaskInput -> peakMask or peakMinProminence
% FINDLOCALPEAKSRUNGPUKERNEL
%
%
%		Usage:
%
%				>>  T = findLocalPeaksRunGpuKernel(Q, peakRadius, peakMask)
%
%
%
%		Notes:
%				[Benchmarks]			(single frame)
%						Direct-8-Neighbor: 2.6ms
%
%



% ------------------------------------------------------------
% PROCESS INPUT - FILL DEFAULTS
% ------------------------------------------------------------
% GET SIZE OF INPUT
[numRows, numCols, numFrames] = size(Q);

% CONSTRUCT SUBSCRIPTS
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));

% CHECK FOR EMPTY OPTIONAL INPUT ARGUMENTS
if nargin < 3
	peakMask = [];
	if nargin < 2
		peakRadius = [];
	end
	
end

% DEFAULT RADIUS IS 1
if isempty(peakRadius)
	peakRadius = int32(1);
else
	peakRadius = int32(peakRadius);
end

% DEFAULT MASK USES ALL VALUES THAT ARE NON NAN OR -INF
if isempty(peakMask)
	peakMask = true;
end



% ------------------------------------------------------------
% GET MIN/MAX OF INPUT FOR NORMALIZATION 0->1 IN THE KERNEL
% ------------------------------------------------------------
Qmin = min(min(Q));
Qmax = max(max(Q));

% CONVERT A LOGICAL MASK TO A THRESHOLD FALSE->1 TRUE->0
if islogical(peakMask)
	peakThresh = single(~peakMask);
else
	peakThresh = single(peakMask);
end

% ------------------------------------------------------------
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ------------------------------------------------------------
if peakRadius <= 1
	Qpeak = arrayfun( @localPeakKernelDirect8Neighbor, Q, Qmin, Qmax, peakThresh, rowSubs, colSubs, frameSubs);
	
else
	Q = arrayfun( @normalizationKernel, Q, Qmin, Qmax);
	[Qcolmax, Qpeak] = arrayfun( @localColumnMaxKernel, rowSubs, colSubs, frameSubs, peakThresh);
	Qpeak = arrayfun( @adjacentColumnPeakKernel, rowSubs, colSubs, frameSubs, Qpeak);
	
end









% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% DIRECT 8-NEIGHBOR SAMPLING
	function qpeak = localPeakKernelDirect8Neighbor(q, qmin, qmax, qthresh, y, x, t)
		
		% ------------------------------------------------------------
		% ONLY CONTINUE KERNEL FOR VALID (MASKED) PIXELS
		% ------------------------------------------------------------
		if isnan(qthresh) || isinf(qthresh)
			% NUMERIC NAN | INF INPUT
			qpeak = false;
			return
		end
		
		% NORMALIZE Q BETWEEN 0 & 1
		q = (q - qmin) / (qmax - qmin);
		
		% COMPARE Q TO THRESHOLD (OR ~QMASK FOR LOGICAL INPUT)
		if q < qthresh
			qpeak = false;
			return
		end
		
		% ------------------------------------------------------------
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		% ------------------------------------------------------------
		yu = max( 1, y-1);
		yd = min( numRows, y+1);
		xl = max( 1, x-1);
		xr = min( numCols, x+1);
		
		% ------------------------------------------------------------
		% RETRIEVE MAX OF NEIGHBOR VALUES
		% ------------------------------------------------------------
		qneighmax = ...
			max( Q(yd, xr, t), ...
			max( Q(y , xr, t), ...
			max( Q(yu, xr, t), ...
			max( Q(yd, xl, t), ...
			max( Q(y , xl, t), ...
			max( Q(yu, xl, t), ...
			max( Q(yd, x , t), Q(yu, x, t) )))))));
		
		% NORMALIZE Q-NEIGHBOR MAX BETWEEN 0 & 1
		qneighmax = (qneighmax - qmin) / (qmax - qmin);
		
		% ------------------------------------------------------------
		% COMPARE TO CURRENT PIXEL VALUE & RETURN
		% ------------------------------------------------------------
		qpeak = (q > qneighmax);
		
		
	end


% DIRECT 8-NEIGHBOR SAMPLING
	function qnorm = normalizationKernel(q, qmin, qmax)
		
		% NORMALIZE Q BETWEEN 0 & 1
		qnorm = (q - qmin) / (qmax - qmin);
		
	end
	function [qcolmax, qpeak] = localColumnMaxKernel(y, x, t, qthresh)
		
		% ------------------------------------------------------------
		% INITIALIZE ROW-IDX ITERATOR & LIMIT
		% ------------------------------------------------------------
		yk = y - peakRadius - 1;
		ymax = min( y + peakRadius, numRows);
		
		% ------------------------------------------------------------
		% COMPUTE MAX AMONG PIXELS ABOVE & BELOW CURRENT PIXEL
		% ------------------------------------------------------------
		
		% INITIALIZE VARIABLES FOR MAXIMUM OF PIXELS ABOVE & BELOW
		qa = single(-inf);
		qb = single(-inf);
		
		% INITIALIZE SMOOTH-GRADIENT CHECKING VARIABLE
		qg = true;
				
		% ------------------------------------------------------------
		% PIXELS ABOVE
		% ------------------------------------------------------------
		while (yk < y)
			if yk > 0
				% GET PIXEL
				qk = Q( yk, x, t);
				% CHECK GRADIENT (STAY TRUE IF INCREASING)
				qg = qg && (qk > (qa-.1));
				% UPDATE MAX OF PIXELS ABOVE
				qa = max( qa, qk );
			end
			yk = yk + 1;
		end
		
		% ------------------------------------------------------------
		% CURRENT PIXEL
		% ------------------------------------------------------------
		q = Q(yk, x, t);
		yk = yk + 1;
		
		% ------------------------------------------------------------
		% PIXELS BELOW
		% ------------------------------------------------------------
		qkm1 = q;
		while (yk <= ymax)
			% GET PIXEL
			qk = Q( yk, x, t);
			% UPDATE MAX OF PIXELS BELOW
			qb = max( qb, qk );
			% CHECK GRADIENT (STAY TRUE IF DECREASING)
			qg = qg && (qk < (qkm1+.1));
			qkm1 = qk;
			yk = yk + 1;
		end
		
		% ------------------------------------------------------------
		% COMPARE CURRENT PIXEL TO MAX ABOVE, BELOW, & THRESHOLD
		% ------------------------------------------------------------
		qcolmax = max( qa, qb);
		qpeak = (q > qthresh) ...
			&& (q > qcolmax) ...
			&& qg;
		
		% INCLUDE CURRENT PIXEL IN COLUMN-MAX OUTPUT
		qcolmax = max( qcolmax, q);
		
		
	end
	function qpeak = adjacentColumnPeakKernel(y, x, t, qpeak)
		
		% RETURN IF QPEAK IS ALREADY UNDER THRESHOLD
		if ~qpeak
			return
		end
		
		% ------------------------------------------------------------
		% INITIALIZE COL-IDX
		% ------------------------------------------------------------
		xk = x - peakRadius - 1;
		xmax = min( x + peakRadius, numCols);
		
		% INITIALIZE VARIABLES FOR MAXIMUM OF LOCAL COLUMNS LEFT & RIGHT
		qa = single(-inf);
		qb = single(-inf);
		
		% INITIALIZE SMOOTH-GRADIENT CHECKING VARIABLE
		qg = true;
		
		% ------------------------------------------------------------
		% COMPUTE MAX FROM ADJACENT COLUMNS
		% ------------------------------------------------------------
		% LEFT
		while (xk < x)
			if xk > 0
				qk = Qcolmax( y, xk, t);
				qg = qg && (qk > (qa-.1));
				qa = max( qa, qk );
			end
			xk = xk + 1;
		end
		
		% RIGHT
		q = Q(y, xk, t);
		qc = Qcolmax(y, xk, t);
		xk = xk + 1;
		
		% PIXELS BELOW
		qkm1 = qc;
		while (xk <= xmax)
			qk = Qcolmax( y, xk, t);
			qb = max( qb, qk );
			qg = qg && (qk < (qkm1+.1));
			qkm1 = qk;
			xk = xk + 1;
		end
		
		% ------------------------------------------------------------
		% COMPARE CURRENT PIXEL TO LEFT & RIGHT
		% ------------------------------------------------------------
		qpeak = qpeak ...
			&& (q > max(qa,qb) ) ...
			&& qg;
		
	end





end
















