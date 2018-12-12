function varargout = edgeSeparation(r1, r2) % 2ms
% Calculates the DISTANCE between ROI LIMITS, returning a single matrix 2D or 3D matrix with
% the last dimension carrying distances ordered TOP,BOTTOM,LEFT,RIGHT. If more than one output
% argument is given, the edge-Displacement is broken up by edge as demonstrated below.
%
% USAGE:
%		>> limDist = edgeSeparation(obj(1:100))		--> returns [100x100x4] matrix
% 	>> limDist = edgeSeparation(obj(1),obj(1:100))			-->  [100x4] matrix
% 	>> [verticalDist, horizontalDist] = edgeSeparation(rp(1),rpRef);
% 	>> [topDist,botDdist,leftDist,rightDist] = edgeSeparation(rp,rpRef);
%
if nargin < 2
	r2 = r1;
end

% CALCULATE XLIM & YLIM (distance from bottom left corner)
bb = cat(1,r2.BoundingBox);
r2Xlim = single( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]); % [LeftEdge,RightEdge] distance from left side of image
r2Ylim = single( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]); % [BottomEdge,TopEdge] distance from bottom of image
bb = cat(1,r1.BoundingBox);
r1Xlim = single( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]);
r1Ylim = single( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]);

% FOR LARGE INPUT
if numel(r1) > 1 || numel(r2) > 1
	% Order in 3rd dimension is Top,Bottom,Left,Right
	r1Lim = cat(3, r1Ylim(:,2), r1Ylim(:,1), r1Xlim(:,1), r1Xlim(:,2));
	r2Lim = cat(3, r2Ylim(:,2), r2Ylim(:,1), r2Xlim(:,1), r2Xlim(:,2));
	limDist = bsxfun(@minus, r1Lim, permute(r2Lim, [2 1 3]));
else
	bottomYdist = r1Ylim(1) - r2Ylim(1);
	topYdist = r1Ylim(2) - r2Ylim(2);
	leftXdist = r1Xlim(1) - r2Xlim(1);
	rightXdist = r1Xlim(2) - r2Xlim(2);
	limDist = single(cat(1, topYdist, bottomYdist, leftXdist, rightXdist));
end
sz = size(limDist);
% Convert to COLUMN VECTOR for a 1xK Query
if (sz(1) == 1) || (sz(2) == 1)
	limDist = reshape(limDist, [], 4);
	n2cOut = 1;
else
	n2cOut = [1 2];
end

limDist = single(limDist);

switch nargout
	case 1
		varargout{1} = limDist;
	case 2
		if length(n2cOut) == 1
			varargout(1:2) = mat2cell(limDist, size(limDist,1), [2 2]);
		else
			varargout(1:2) = mat2cell(limDist, size(limDist,1), size(limDist,2), [2 2]);
		end
	case 4
		varargout = num2cell(limDist, n2cOut);
	otherwise
		varargout{1} = limDist;
end


end

