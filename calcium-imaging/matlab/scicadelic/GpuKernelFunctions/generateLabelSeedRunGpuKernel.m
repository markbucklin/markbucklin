function [Rbw,Sbw,Snew] = generateLabelSeedRunGpuKernel(Qk, R0, S0, T)
%
% BENCHMARK: ~ 1.6 ms/frame/displacement (tested with 16 frame chunk)



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames, numChannels] = size(Qk);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs = reshape(int32(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);
if nargin < 4
	T = [];
	if nargin < 3
		S0 = [];
		if nargin < 2
			R0 = [];
		end
	end
end
if isempty(T)
	T = 0;
end
neighborDisplacement = int32([ -1 0 1 -1 1 -1 0 1 ; -1 -1 -1 0 0 1 1 1]');
numNeighbors = numel(neighborDisplacement)/2;
neighborSubs = int32(reshape(gpuArray.colon(1,numNeighbors), 1, 1, numNeighbors));
neighborRowSubs = int32(reshape(neighborDisplacement(:,1,:), 1, 1, numNeighbors));
neighborColSubs = int32(reshape(neighborDisplacement(:,2,:), 1, 1, numNeighbors));


% Q -> R
Rbw = Qk > .25;
Rbw = reshape(...
	bwmorph(bwmorph(bwmorph( ...
	reshape(Rbw, numRows,[],1), ...
	'clean'), 'majority'),'fill'), ...
	numRows,numCols,[]);

% R -> S
Sbw = reshape(...
	bwmorph( ...
	reshape(Rbw,numRows,[],1),'shrink', inf), ...
	numRows,numCols,[]);

% 
if isempty(S0)
	S0 = false(numRows,numCols,'gpuArray');	
end

if isempty(R0)
	R0 = false(numRows,numCols,'gpuArray');
end

% NOT QUITE RIGHT YET, NEED TO STRAIGHTEN OUT STORAGE MATRICES... LABEL VS LOGICAL


% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
[NPMI, Hab, Pa8, Pb8, Pab] = arrayfun( @pointwiseMutualInformationKernel,...
	S0, rowSubs, colSubs, neighborSubs, neighborRowSubs, neighborColSubs, chanSubs);


N = N + single(numFrames);
Pa = mean(Pa8,3);
Pb = mean(Pb8,3);
% Pb = min(Pb8,[],3);

R0.N = N;
R0.a = Pa;
R0.b = Pb;
R0.ab = Pab;








% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [npmi,hab,pa,pb,pab] = pointwiseMutualInformationKernel(qmin0, rowIdx, colIdx, neigIdx, dRow, dCol, chanIdx)
		
		% NEIGHBOR SUBSCRIPTS
		% 		neighborRowIdx = max(1,min(numRows, rowIdx + dRow));
		% 		neighborColIdx = max(1,min(numCols, colIdx + dCol));
		neighborRowIdx = rowIdx + dRow;
		neighborColIdx = colIdx + dCol;
		
		if (neighborRowIdx > 0) && (neighborColIdx > 0) && (neighborRowIdx <= numRows) && (neighborColIdx <= numCols)
			
			% GET CURRENT CENTRAL PIXEL PROBABILITY
			pa = single(Pa(rowIdx, colIdx, 1, chanIdx))*carryOverCoeff;
			
			% GET NEIGHBOR-PIXEL PROBABILITY
			pb = single(Pb(neighborRowIdx, neighborColIdx, 1, chanIdx))*carryOverCoeff;
			
			% GET JOINT PROBABILITY WITH NEIGHBOR-PIXEL
			pab = single(Pab(rowIdx, colIdx, neigIdx, chanIdx))*carryOverCoeff^2;
			
			% TURN PRIOR PROBABILITIES INTO SUMS
			n = single(N);
			% 			if n>16
			% 				n = n*carryOverCoeff;
			% 			end
			sa = pa * n;
			sb = pb * n;
			sna = n - sa;
			snb = n - sb;
			sab = pab * n;
			
			% UPDATE POINT-WISE PROBABILITIES RELATIVE TO CENTER-DERIVED THRESHOLD
			k = single(0);
			while k < numFrames
				k = k + 1;
				
				fa = single(Qk(rowIdx, colIdx, k, chanIdx));
				fb = single(Qk(neighborRowIdx, neighborColIdx, k, chanIdx));
				
				% 				qmin = max( max( fa/2, fb/2), qmin0); % SYMMETRIC
				qmin = max( fa/4, qmin0); % ASYMMETRIC
				
				a = fa >= qmin;
				b = fb >= qmin;
				
				sa = sa + single( a );
				sb = sb + single( b );
				sna = sna + single( ~a );
				snb = snb + single( ~b );
				sab = sab + single( a & b );
				
				n = n + 1;
				
			end
			
			% INDIVIDUAL PROBABILITIES
			pa = sa/n;
			pb = sb/n;
			pna = sna/n;
			pnb = snb/n;
			
			% JOINT PROBABILITY
			pab = sab/n;
			
			% MUTUAL INFORMATION
			pmi = log2(pab/(pa*pb));
			npmi = pmi/-log2(pab);
			
			% CHECK THAT COMPUTED PMI IS VALID
			if isnan(pmi) || isnan(npmi)
				pmi = single(0);
				npmi = single(0);
			elseif isinf(pmi) || isinf(npmi)
				pmi = sign(pmi);
				npmi = sign(pmi);
			end
			
			% JOINT ENTROPY ->(try ratio of individual entropies)
			c = eps(pa);
			ha = - ( pa*log2(pa+c) + pna*log2(pna+c) );
			hb = - ( pb*log2(pb+c) + pnb*log2(pnb+c) );
			hab = ha + hb - pmi;
			
		else
			% SET EDGES/OUT-OF-BOUNDS TO ZEROs
			npmi = single(0);
			hab = single(0);
			pa = single(0);
			pb = single(0);
			pab = single(0);
			
		end
		
		
	end







end













