function [Iy,Ix,Isym] = mapInformationTopologyRunGpuKernel(PMI)
%computeInformationSymmetryScoreRunGpuKernel
%
% BENCHMARK: ~  ms/frame/displacement (tested with 16 frame chunk)



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numDisplacements, numChannels] = size(PMI);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
% displacementSubs = int32(reshape(gpuArray.colon(1, numDisplacements), 1,1,numDisplacements));
chanSubs = reshape(int32(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);
% if nargin < 2
% 	neighborDisplacement = [];
% end
% if isempty(neighborDisplacement)
% 	neighborDisplacement = int32([ -1 0 1 -1 1 -1 0 1 ; -1 -1 -1 0 0 1 1 1]');
% else
% 	neighborDisplacement = ...
% 		int32(bsxfun(@times, ...
% 		[ -1 0 1 -1 1 -1 0 1 ; -1 -1 -1 0 0 1 1 1]', ...
% 		double(reshape(neighborDisplacement,1,1,[]))));
% end
numRings = numDisplacements/8;
ringSubs = int32(reshape(gpuArray.colon(0,numRings-1), 1, 1, numRings));
dirUvec = single([ ...
	.25   , .25 ;...
	0     , .5  ;...
	-.25  , .25 ;...
	.5    , 0   ]);
% 	.7071 , .7071 ;...
% 	0     , 1     ;...
% 	-.7071, .7071 ;...
% 	1     , 0     ]);



% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
[Iy,Ix,Isym] = arrayfun( @informationSymmetryKernel, rowSubs, colSubs, ringSubs, chanSubs);












% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function [iy,ix,isym] = informationSymmetryKernel(rowIdx, colIdx, ringIdx, chanIdx)
		
		
		
		% INITIALIZE INFORMATION VECTOR ADDITION & INFORMATION MAGNITUDE
		iy = single(0);
		ix = single(0);
		isym = single(0);
		
		% COMPARE DIRECTIONALLY OPPOSITE NEIGHBORS
		for kdir = 0:3
			idxa = 8*ringIdx + kdir + 1;
			idxb = 8*ringIdx - kdir + 8;
			uy = dirUvec(kdir+1, 1);
			ux = dirUvec(kdir+1, 2);
			ia = single(PMI(rowIdx, colIdx, idxa, chanIdx));
			ib = single(PMI(rowIdx, colIdx, idxb, chanIdx));
			ir = ib - ia;
			iy = iy + uy*ir;
			ix = ix + ux*ir;
			dsym = (1-abs(ir)) * (ia+ib)/2;
			
			if ~isnan(dsym)
				isym = isym + dsym;
			end
			
		end
		isym = isym/4;
		
		
	end







end








% dsym = max(ia,ib) - (abs(ir) / (max(ia,ib));
% 				dsym = (1 - ((max(ia,ib)-min(ia,ib))/max(.1,max(ia,ib))));


% 				isym = isym + abs(ia + ib)/(abs(ir)+1);
% 				dsym = .25*(1 - (abs(ir)/max(abs(ia),abs(ib))));
% 				dsym = (ia+ib) - (abs(ir) / max(1,abs(ia)+abs(ib)));

% 				dsym = (ia+ib) - (abs(ir) / max(1,ia+ib)); % gives good cellular uniformity but with cell-2-cell heterogeneity in value




% 				isym = isym + .125*((abs(ia)+abs(ib))/max(abs(ia),abs(ib)));
% 				isym = isym + abs(ia) + abs(ib);




