function mask = circleCenters2Mask(centers, radii, sz)
% Find circles in image using something like the following:
% >> [centers,radii] = imfindcircles(A,[6 25], 'Sensitivity', .9);
%
% Can also display with something like the following:
% >> h = handle(viscircles(centers, radii, 'DrawBackgroundCircle',false))
%
% X-Coordinates for circle centers are in the first column, Y-Coordinates in the second

mask = false(sz);
imshow(mask);
h = handle(viscircles(centers, radii, 'DrawBackgroundCircle',false));
hLine = handle(h.Children);
ySubs = round(hLine.YData);
xSubs = round(hLine.XData);
goodsubs = ...
  xSubs<sz(2)...
  & xSubs>=1 ...
  & ySubs<sz(1)...
  & ySubs>=1 ;
xSubs = xSubs(goodsubs);
ySubs = ySubs(goodsubs);
mask(sub2ind(sz, ySubs, xSubs)) = true;
mask = imfill(imdilate(mask, strel('disk', 3, 4)),'holes');
imshow(mask)
close