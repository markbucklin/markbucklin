function [neighborRowSubs, neighborColSubs] = getNeighborSubs(radialDisplacement)

if nargin < 1
	radialDisplacement = 1;
end

neighborDisplacement = ...
	int32(bsxfun(@times, ...
	[ -1 0 1 -1 1 -1 0 1 ; -1 -1 -1 0 0 1 1 1]', ...
	double(reshape(radialDisplacement,1,1,[]))));

numNeighbors = numel(neighborDisplacement)/2;
neighborSubs = int32(reshape(gpuArray.colon(1,numNeighbors), 1, 1, numNeighbors));
neighborRowSubs = int32(reshape(neighborDisplacement(:,1,:), 1, 1, numNeighbors));
neighborColSubs = int32(reshape(neighborDisplacement(:,2,:), 1, 1, numNeighbors));
