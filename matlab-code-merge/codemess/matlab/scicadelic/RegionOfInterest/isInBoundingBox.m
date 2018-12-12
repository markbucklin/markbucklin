function isWithin = isInBoundingBox(r1, r2) % 4ms
% Returns logical vector/array (digraph) that is true at all edges where the centroid of OBJ
% is within the rectangular box surrounding ROI (input 2, or all others in OBJ array )
if nargin < 2
	r2 = r1;
end
if (numel(r1) > 1) || (numel(r2) > 1)
	r1Cxy = permute(uint16(cat(1,r1.Centroid)), [1 3 2]);
	r2BBox = uint16(cat(1,r2.BoundingBox));
	% 	r2Xlim = uint16( [floor(r2BBox(:,1)) , ceil(r2BBox(:,1) + r2BBox(:,3)) ])';
	% 	r2Ylim = uint16( [floor(r2BBox(:,2)) , ceil(r2BBox(:,2) + r2BBox(:,4)) ])';
	r2LowerLim = shiftdim([r2BBox(:,1) , r2BBox(:,2)], -1);
	r2UpperLim = shiftdim(r2BBox(:,1:2) + r2BBox(:,3:4), -1);
	isWithin = all(bsxfun(@and,...	
		bsxfun(@ge, r1Cxy , r2LowerLim),...
		bsxfun(@le, r1Cxy , r2UpperLim)), 3);
		
	
	% 	isWithin = bsxfun(@and,...
	% 		bsxfun(@and,...
	% 		bsxfun(@ge,r1Cxy(:,1),r2Xlim(1,:)),...
	% 		bsxfun(@le,r1Cxy(:,1),r2Xlim(2,:))) , ...
	% 		bsxfun(@and,...
	% 		bsxfun(@ge,r1Cxy(:,2),r2Ylim(1,:)),...
	% 		bsxfun(@le,r1Cxy(:,2),r2Ylim(2,:))));
else
	if isempty(r1.BoundingBox) || isempty(r2.BoundingBox)
		isWithin = false;
		return
	end
	xc = r1.Centroid(1);
	yc = r1.Centroid(2);
	xbL = r2.BoundingBox(1);
	xbR = xbL + r2.BoundingBox(3);
	ybB = r2.BoundingBox(2);
	ybT = ybB + r2.BoundingBox(4);
	isWithin =  (xc >= xbL) & (xc <= xbR) & (yc >= ybB) & (yc <= ybT);
end
sz = size(isWithin);
% Convert to COLUMN VECTOR for a 1xK Query
if (sz(1) == 1)
	isWithin = isWithin(:);
end
end