function [R, Q] = findLocalPeakSpreadValueRunGpuKernel(P, Q0, peakRadius, threshHigh, threshLow) % peakMaskInput -> peakMask or peakMinProminence
% FINDLOCALPEAKSPREADVALUERUNGPUKERNEL
%
%
%		Usage:
%
%				>>  [R,Q] = findLocalPeaksRunGpuKernel(P, peakRadius, peakMinThresh)
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
[numRows, numCols, numFrames] = size(P);

% CONSTRUCT SUBSCRIPTS
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));

% CHECK FOR EMPTY OPTIONAL INPUT ARGUMENTS
if nargin < 5
	threshLow = [];
	if nargin < 4
		threshHigh = [];
		if nargin < 3
			peakRadius = [];
			if nargin < 2
				Q0 = [];
			end
		end
	end
end

% ------------------------------------------------------------
% FILL DEFAULTS
% ------------------------------------------------------------
if isempty(peakRadius)
	% DEFAULT RADIUS IS 3
	peakRadius = int32(3);
else
	peakRadius = int32(peakRadius);
end
if isempty(Q0)
	Q0  = gpuArray.zeros(size(P), 'int32');% uint16?
else
	Q0 = int32(Q0);
end

% DEFAULT THRESH .675
if isempty(threshHigh)
	threshHigh = single(.675);
end
if isempty(threshLow)
	threshLow = single(threshHigh/2);
end



% ------------------------------------------------------------
% GET MIN/MAX OF INPUT FOR NORMALIZATION 0->1 IN THE KERNEL
% ------------------------------------------------------------
Pmin = min(min(P));
Pmax = max(max(P));



% ------------------------------------------------------------
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ------------------------------------------------------------
if peakRadius <= 1
	R = arrayfun( @localPeakKernelDirect8Neighbor, P, Q0, Pmin, Pmax, rowSubs, colSubs, frameSubs);
	
else
	P = arrayfun( @normalizationKernel, P, Pmin, Pmax);
	[Pcolmax, R, Q] = arrayfun( @localColumnMaxKernel, rowSubs, colSubs, frameSubs);
	[R,Q] = arrayfun( @adjacentColumnPeakKernel, rowSubs, colSubs, frameSubs, R);
	
end









% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ------------------------------------------------------------
% DIRECT 8-NEIGHBOR SAMPLING
% ------------------------------------------------------------
	function [r,q] = localPeakKernelDirect8Neighbor(p, q0, pmin, pmax, y, x, t)
		
		% ------------------------------------------------------------
		% ONLY CONTINUE KERNEL FOR VALID (MASKED) PIXELS
		% ------------------------------------------------------------
		
		% INITIALIZE Q
		q = int32(0);
		
		% NUMERIC NAN | INF INPUT
		if isnan(p) || isinf(p)			
			r = false;			
			return
		end
		
		% NORMALIZE Q BETWEEN 0 & 1
		p = (p - pmin) / (pmax - pmin);
		
		% COMPARE Q TO THRESHOLD
		if (p < threshHigh)
			r = false;
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
		pneighmax = ...
			max( P(yd, xr, t), ...
			max( P(y , xr, t), ...
			max( P(yu, xr, t), ...
			max( P(yd, xl, t), ...
			max( P(y , xl, t), ...
			max( P(yu, xl, t), ...
			max( P(yd, x , t), P(yu, x, t) )))))));
		
		% NORMALIZE P-NEIGHBOR MAX BETWEEN 0 & 1
		pneighmax = (pneighmax - pmin) / (pmax - pmin);
						
		% ------------------------------------------------------------
		% COMPARE TO CURRENT PIXEL VALUE & RETURN
		% ------------------------------------------------------------
		r = (p > pneighmax);
		
		% IF ANY NEIGHBORS ARE ABOVE THRESHOLD USE GIVEN THRESHOLD
		if (pneighmax >= threshLow) && (pneighmax >= threshHigh)
			q = q0;
		end
		
		
	end


% ------------------------------------------------------------
% 2-STEP SHARED MAX SAMPLING (STILL REDUNDANT)
% ------------------------------------------------------------
	function qnorm = normalizationKernel(q, qmin, qmax)
		
		% NORMALIZE Q BETWEEN 0 & 1
		qnorm = (q - qmin) / (qmax - qmin);
		
	end
	function [pcolmax, r, q] = localColumnMaxKernel(y, x, t)
		
		% ------------------------------------------------------------
		% INITIALIZE ROW-IDX ITERATOR & LIMIT
		% ------------------------------------------------------------
		yk = y - peakRadius - 1;
		ymax = min( y + peakRadius, numRows);
		
		% ------------------------------------------------------------
		% COMPUTE MAX AMONG PIXELS ABOVE & BELOW CURRENT PIXEL
		% ------------------------------------------------------------
		
		% INITIALIZE VARIABLES FOR MAXIMUM OF PIXELS ABOVE & BELOW
		pa = single(-inf);
		pb = single(-inf);
		
		% INITIALIZE SMOOTH-GRADIENT CHECKING VARIABLE
		pg = true;
				
		% ------------------------------------------------------------
		% PIXELS ABOVE
		% ------------------------------------------------------------
		while (yk < y)
			if yk > 0
				% GET PIXEL
				pk = P( yk, x, t);
				% CHECK GRADIENT (STAY TRUE IF INCREASING)
				pg = pg && (pk > (pa-.1));
				% UPDATE MAX OF PIXELS ABOVE
				pa = max( pa, pk );
			end
			yk = yk + 1;
		end
		
		% ------------------------------------------------------------
		% CURRENT PIXEL
		% ------------------------------------------------------------
		p = P(yk, x, t);
		yk = yk + 1;
		
		% ------------------------------------------------------------
		% PIXELS BELOW
		% ------------------------------------------------------------
		pkm1 = p;
		while (yk <= ymax)
			% GET PIXEL
			pk = P( yk, x, t);
			% UPDATE MAX OF PIXELS BELOW
			pb = max( pb, pk );
			% CHECK GRADIENT (STAY TRUE IF DECREASING)
			pg = pg && (pk < (pkm1+.1));
			pkm1 = pk;
			yk = yk + 1;
		end
		
		% ------------------------------------------------------------
		% COMPARE CURRENT PIXEL TO MAX ABOVE, BELOW, & THRESHOLD
		% ------------------------------------------------------------
		pcolmax = max( pa, pb);
		r = (p > threshHigh) ...
			&& (p > pcolmax) ...
			&& pg;
		
		% INCLUDE CURRENT PIXEL IN COLUMN-MAX OUTPUT
		pcolmax = max( pcolmax, p);
		
		% IF ANY NEIGHBORS ARE ABOVE THRESHOLD USE GIVEN THRESHOLD
		if (p >= threshLow) && (pcolmax >= threshHigh)
			q = Q0(y,x);
		else
			q = int32(0);
		end
		
	end
	function [r,q] = adjacentColumnPeakKernel(y, x, t, r)
		
		% RETURN IF QPEAK IS ALREADY UNDER THRESHOLD
		q = Q(y,x);
		if ~r			
			return
		end
		
		% ------------------------------------------------------------
		% INITIALIZE COL-IDX
		% ------------------------------------------------------------
		xk = x - peakRadius - 1;
		xmax = min( x + peakRadius, numCols);
		
		% INITIALIZE VARIABLES FOR MAXIMUM OF LOCAL COLUMNS LEFT & RIGHT
		pa = single(-inf);
		pb = single(-inf);
		
		% INITIALIZE SMOOTH-GRADIENT CHECKING VARIABLE
		pg = true;
		
		% ------------------------------------------------------------
		% COMPUTE MAX FROM ADJACENT COLUMNS
		% ------------------------------------------------------------
		% LEFT
		while (xk < x)
			if xk > 0
				pk = Pcolmax( y, xk, t);
				pg = pg && (pk > (pa-.1));
				pa = max( pa, pk );
			end
			xk = xk + 1;
		end
		
		% RIGHT
		p = P(y, xk, t);
		pc = Pcolmax(y, xk, t);
		xk = xk + 1;
		
		% PIXELS BELOW
		pkm1 = pc;
		while (xk <= xmax)
			pk = Pcolmax( y, xk, t);
			pb = max( pb, pk );
			pg = pg && (pk < (pkm1+.1));
			pkm1 = pk;
			xk = xk + 1;
		end
		
		% ------------------------------------------------------------
		% COMPARE CURRENT PIXEL TO LEFT & RIGHT
		% ------------------------------------------------------------
		padjmax = max(pa,pb);
		r = r ...
			&& (p > padjmax ) ...
			&& pg;
		
		% IF ANY NEIGHBORS ARE ABOVE THRESHOLD USE GIVEN THRESHOLD
		if (p >= threshLow) && (padjmax >= threshHigh)
			q = Q0(y,x);
		end
		
	end





end
















