function P = updateFeatureProbabilityRunGpuKernel(R, P)
% updateFeatureProbabilityRunGpuKernel



[numRows,numCols,numFrames,numChannels] = size(R);
rowSubs = single(gpuArray.colon(1,numRows)');
colSubs = single(gpuArray.colon(1,numCols));
frameSubs = single(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  single(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));

% INITIALIZE FEATURE PROBABILITY STRUCTURE IF NECESSARY
if nargin < 2
	P.PotentialRegionCount = zeros(numRows,numCols,1,'single','gpuArray');
	P.CondensedRegionCount = zeros(numRows,numCols,1,'single','gpuArray');
	P.DilatedRegionCount = zeros(numRows,numCols,1,'single','gpuArray');
	P.OuterEdgeCount = zeros(numRows,numCols,1,'single','gpuArray');
	P.InnerEdgeCount = zeros(numRows,numCols,1,'single','gpuArray');
end

% PULL VARIABLES FROM FEATURE PROBABILITY STRUCTURE
Npr = P.PotentialRegionCount;
Ncr = P.CondensedRegionCount;
Ndr = P.DilatedRegionCount;
Noe = P.OuterEdgeCount;
Nie = P.InnerEdgeCount;

% CONSTRUCT NEIGHBOR INDEXING VARIABLES
radialDisplacement = 1;
neighborDisplacement = ...
	single(bsxfun(@times, ...
	[ -1 0 1 -1 1 -1 0 1 ; -1 -1 -1 0 0 1 1 1]', ...
	double(reshape(radialDisplacement,1,1,[]))));
numNeighbors = numel(neighborDisplacement)/2;
neighborSubs = single(reshape(gpuArray.colon(1,numNeighbors), 1, 1, numNeighbors));
neighborRowSubs = single(reshape(neighborDisplacement(:,1,:), 1, 1, numNeighbors));
neighborColSubs = single(reshape(neighborDisplacement(:,2,:), 1, 1, numNeighbors));


% RESAMPLE/INTERPOLATE IMAGE USING BICUBIC INTERPOLATION ON GPU
Fq = arrayfun(@bicubicImageResampleKernel, rowSubs, colSubs, frameSubs, chanSubs, uy, ux);

% RECAST OUTPUT TO SAME DATATYPE AS INPUT
F = cast(Fq, 'like', F);









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
				
				fa = single(Q(rowIdx, colIdx, k, chanIdx));
				fb = single(Q(neighborRowIdx, neighborColIdx, k, chanIdx));
				
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
