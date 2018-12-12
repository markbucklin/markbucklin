function F = supressRegionPotentialRunGpuKernel( F, minBorderDist, Pedge, maxEdgePotential)


% GET DIMENSIONS OF INPUT
[numRows,numCols,~,~] = size(F);
numRows = int32(numRows);
numCols = int32(numCols);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));

% FILL EMPTIES FOR VARIABLE INPUT
if nargin < 4
	maxEdgePotential = [];
	if nargin < 3
		Pedge = [];
		if nargin < 2
			minBorderDist = [];
		end
	end
end

% DESIGNATE FILL-VALUE FROM DATATYPE OF INPUT
if islogical(F)
	fillVal = false(1, 'like', F);
else % isnumeric(R)
	fillVal = zeros(1, 'like', F);
end

% FILL DEFAULTS
if isempty(minBorderDist)
	minBorderDist = int32(8);
else
	minBorderDist = int32(minBorderDist);
end
if isempty(Pedge)
	Pedge = single(0);
	maxEdgePotential = single(1);
else
	Pedge = single(Pedge);
end
if isempty(maxEdgePotential)
	maxEdgePotential = max(.75*single(mean(max(Pedge))), .1);
else
	maxEdgePotential = single(maxEdgePotential);
end

% RUN KERNEL
F = arrayfun( @suppressRegionEdgePixelsKernel, F, Pedge, maxEdgePotential, rowSubs, colSubs);







% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function r = suppressRegionEdgePixelsKernel(r, p, pmax, y, x)
		
		if (r ~= fillVal)
			
			% FIND DISTANCE TO CLOSEST BORDER
			bd = min(y,x);
			bd = min( bd, numRows-y+1);
			bd = min( bd, numCols-x+1);
			
			% CHECK IF CLOSEST BORDER IS LESS THAN OR EQUAL BORDER DIST DESIGNATED FOR SUPPRESSION
			if (bd <= minBorderDist) || (p > pmax)
				r = fillVal;
			end
		end
		
	end













end



