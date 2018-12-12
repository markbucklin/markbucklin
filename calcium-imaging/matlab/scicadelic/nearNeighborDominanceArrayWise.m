function pxNearNeighborDominance = nearNeighborDominanceArrayWise(F, ds)

[nrows,ncols] = size(F(:,:,1));
% dim = ndims(F);

% DIRECT NEIGHBORS -> SHIFT MATRIX BY 1 IN EACH DIRECTION
fu = F([1, 1:nrows-1], :, :);
fd = F([2:nrows, nrows], :,:);
fl = F(:, [1, 1:ncols-1],:);
fr = F(:, [2:ncols, ncols], :);

% SURROUND -> SHIFT MATRIX BY DISTANCE ESTIMATED TO BE GREATER THAN 1 RADIUS OF THE LARGEST OBJECT
% IN THE FRAME
su = F([ones(1,ds), 1:nrows-ds], :, :);
sd = F([ds+1:nrows, nrows.*ones(1,ds)], :, :);
sl = F(:, [ones(1,ds), 1:ncols-ds], :);
sr = F(:, [ds+1:ncols, ncols.*ones(1,ds)], :);

% CENTRAL PIXEL AND 3 IMMEDIATE NEIGHBORS ARE ALL GREATER INTENSITY THAN 3 SURROUNDING PIXELS
Gu = min(min(min( F, fl), fd), fr) > max(max( sl, su), sr);
Gr = min(min(min( F, fu), fl), fd) > max(max( su, sr), sd);
Gd = min(min(min( F, fl), fu), fr) > max(max( sl, sd), sr);
Gl = min(min(min( F, fu), fr), fd) > max(max( su, sl), sd);


pxNearNeighborDominance = ...
	(Gu & Gr & Gd) |...
	(Gu & Gl & Gd) |...
	(Gl & Gu & Gr) |...
	(Gl & Gd & Gr);
