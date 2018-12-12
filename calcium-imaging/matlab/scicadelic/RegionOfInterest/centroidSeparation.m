function varargout = centroidSeparation(r1, r2) % 2ms
% Calculates the EUCLIDEAN DISTANCE between ROIs. Output depends on number of arguments. For
% one output argument the hypotenuse between centroids is returned, while for two output
% arguments the y-distance and x-distance are returned in two separate matrices. Usage
% examples are below: >> csep = centroidSeparation( roi(1:100) )			--> returns [100x100]
% matrix >> [simmat.cy,simmat.cx] = centroidSeparation(roi(1:100),roi(1:100)) --> 2
% [100x100]matrices >> csep = centroidSeparation(roi(1), roi(2:101)) --> returns [100x1]
% vector
if nargin < 2
	r2 = r1;
end
if numel(r1) > 1 || numel(r2) > 1
	oCxy = cat(1,r1.Centroid);
	rCxy = cat(1,r2.Centroid);
	rCxy = rCxy';
	xdist = single(bsxfun(@minus, oCxy(:,1), rCxy(1,:)));
	ydist = single(bsxfun(@minus, oCxy(:,2), rCxy(2,:)));
	if nargout <= 1
		pixDist = bsxfun(@hypot, xdist, ydist);
	end
else
	if isempty(r1.Centroid) || isempty(r2.Centroid)
		varargout{1:nargout} = inf;
		return
	end
	xdist = single(r1.Centroid(1) - r2.Centroid(1));
	ydist = single(r1.Centroid(2) - r2.Centroid(2));
	if nargout <= 1
		pixDist = hypot( xdist, ydist);
	end
end
if nargout <= 1
	sz = size(pixDist);
	% Convert to COLUMN VECTOR for a 1xK Query
	if (sz(1) == 1)
		pixDist = pixDist(:);
	end
	varargout{1} = pixDist;
elseif nargout == 2
	if (size(xdist,1) == 1) || (size(ydist,1) == 1)
		xdist = xdist(:);
		ydist = ydist(:);
	end
	varargout{1} = ydist;
	varargout{2} = xdist;
end
end