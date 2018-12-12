function [Iab, Hab, P] = neighborMutualInformationRunGpuKernel(Q, P, Qmin, neighborDisplacement)
%
%



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames, numChannels] = size(Q);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs = reshape(int32(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);
if nargin < 4
	neighborDisplacement = [];
	if nargin < 3
		Qmin = [];
		if nargin < 2
			P = [];
		end
	end
end
if isempty(neighborDisplacement)
	neighborDisplacement = int32([ -1 0 1 -1 1 -1 0 1 ; -1 -1 -1 0 0 1 1 1]');
else
	neighborDisplacement = ...
		int32(bsxfun(@times, ...
		[ -1 0 1 -1 1 -1 0 1 ; -1 -1 -1 0 0 1 1 1]', ...
		double(reshape(neighborDisplacement,1,1,[]))));
end
% numNeighbors = size(neighborDisplacement,1);
numNeighbors = numel(neighborDisplacement)/2;
neighborSubs = int32(reshape(gpuArray.colon(1,numNeighbors), 1, 1, numNeighbors));
neighborRowSubs = int32(reshape(neighborDisplacement(:,1,:), 1, 1, numNeighbors));
neighborColSubs = int32(reshape(neighborDisplacement(:,2,:), 1, 1, numNeighbors));

if isempty(Qmin)
	Qmin = gpuArray.zeros(numRows,numCols, 'single') + 1/8;
else
	Qmin = single(Qmin);
end
if isempty(P)
	N = gpuArray.zeros(1,'single');
	Pa = gpuArray.zeros(numRows,numCols, 'single');
	Pb = gpuArray.zeros(numRows,numCols, 'single');
	Pab = gpuArray.zeros(numRows,numCols,numNeighbors, 'single');
	Panb = gpuArray.zeros(numRows,numCols,numNeighbors, 'single');
	Pnab = gpuArray.zeros(numRows,numCols,numNeighbors, 'single');
	Pnanb = gpuArray.zeros(numRows,numCols,numNeighbors, 'single');
else
	N = P.N;
	Pa = P.a;
	Pb = P.b;
	Pab = P.ab;
	Panb = P.anb;
	Pnab = P.nab;
	Pnanb = P.nanb;
end



% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
[Iab, Hab, Pa8, Pb8, Pab, Panb, Pnab, Pnanb] = arrayfun( @neighborMutualInformationKernel,...
	Qmin, rowSubs, colSubs, neighborSubs, neighborRowSubs, neighborColSubs, chanSubs);


N = N + single(numFrames);
Pa = min(Pa8,[],3);
Pb = min(Pb8,[],3);

P.N = N;
P.a = Pa;
P.b = Pb;
P.ab = Pab;
P.anb = Panb;
P.nab = Pnab;
P.nanb = Pnanb;








% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [iab,hab,pa,pb,pab,panb,pnab,pnanb] = neighborMutualInformationKernel(qmin0, rowIdx, colIdx, neighborIdx, dRow, dCol, chanIdx)
		
		% NEIGHBOR SUBSCRIPTS
		% 		dRow = int32(neighborDisplacement(neighborIdx,1));
		% 		dCol = int32(neighborDisplacement(neighborIdx,2));
		neighborRowIdx = rowIdx + dRow;
		neighborColIdx = colIdx + dCol;
		
		if (neighborRowIdx > 0) && (neighborColIdx > 0) && (neighborRowIdx <= numRows) && (neighborColIdx <= numCols)
			
			% GET CURRENT CENTRAL PIXEL PROBABILITY
			pa = single(Pa(rowIdx, colIdx, 1, chanIdx));
			
			% GET NEIGHBOR-PIXEL PROBABILITY
			pb = single(Pa(neighborRowIdx, neighborColIdx, 1, chanIdx));
			
			% GET JOINT PROBABILITY WITH NEIGHBOR-PIXEL
			pab = single(Pab(neighborRowIdx, neighborColIdx, neighborIdx, chanIdx));
			panb = single(Panb(neighborRowIdx, neighborColIdx, neighborIdx, chanIdx));
			pnab = single(Pnab(neighborRowIdx, neighborColIdx, neighborIdx, chanIdx));
			pnanb = single(Pnanb(neighborRowIdx, neighborColIdx, neighborIdx, chanIdx));
			
			% TURN PRIOR PROBABILITIES INTO SUMS
			n = single(N);
			sa = pa * n;
			sb = pb * n;
			sna = n - sa;
			snb = n - sb;
			sab = pab * n;
			snab = pnab * n;
			sanb = panb * n;
			snanb = pnanb * n;
			
			% UPDATE POINT-WISE PROBABILITIES RELATIVE TO CENTER-DERIVED THRESHOLD
			k = single(0);
			% 		fmin = single(fmin0);
			while k < numFrames
				k = k + 1;
				
				fa = single(Q(rowIdx, colIdx, k, chanIdx));
				fb = single(Q(neighborRowIdx, neighborColIdx, k, chanIdx));
				
				qmin = max( max( fa/2, fb/2), qmin0);
				
				a = fa >= qmin;
				b = fb >= qmin;
				
				sa = sa + single( a );
				sb = sb + single( b );
				sna = sna + single( ~a );
				snb = snb + single( ~b );
				sab = sab + single( a & b );
				snab = snab + single( ~a & b );
				sanb = sanb + single( a & ~b );
				snanb = snanb + single(~a & ~b );
				
				n = n + 1;
				
			end
			
			% INDIVIDUAL PROBABILITIES
			pa = sa/n;
			pb = sb/n;
			pna = sna/n;
			pnb = snb/n;
			
			% JOINT
			pab = sab/n;
			pnab = snab/n;
			panb = sanb/n;
			pnanb = snanb/n;
			
			% MUTUAL INFORMATION
			c = eps(pa);
			ha = - (pa*log2(pa+c) + pna*log2(pna+c));
			hb = - (pb*log2(pb+c) + pnb*log2(pnb+c));
			hab = - (0 ...
				+ pab*log2(pab+c) ...
				+ pnab*log2(pnab+c) ...
				+ panb*log2(panb+c) ...
				+ pnanb*log2(pnanb+c));
			
			iab = pab * log2(pab/(pa*pb)+c) ...
				+ pnab * log2(pnab/(pna*pb)+c) ...
				+ panb * log2(panb/(pa*pnb)+c) ...
				+ pnanb * log2(pnanb/(pna*pnb)+c);
			if isnan(iab)
				iab = single(0);
			end
			
		else
			iab = single(0);
			hab = single(0);
			pa = single(0);
			pb = single(0);
			pab = single(0);
			pnab = single(0);
			panb = single(0);
			pnanb = single(0);
			
			
		end
		% todo: include not-a not-b, or use histogram
		
		
		
	end







end























% 		neighborRowIdx = min(numRows, max(1, rowIdx + dRow));
% 		neighborColIdx = min(numCols, max(1, colIdx + dCol));
