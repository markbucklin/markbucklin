stat = getVidStats(vid);

%%
imshow(stat.Range)
[centers,radii] = imfindcircles(stat.Range,[6 15], 'Sensitivity', .94);
h = handle(viscircles(centers, radii,...
  'DrawBackgroundCircle',false,...
  'LineWidth',1,...
  'EdgeColor','m'...
  ));
%%
s=50;
firstFrame = 1:s:numel(vid);
for k=1:numel(firstFrame)
  n = firstFrame(k) : min(numel(vid),firstFrame(k)+s);
  im = range(cat(3,vid(n).cdata), 3);
  imshow(im)
  [centers,radii] = imfindcircles(im,[6 18], 'Sensitivity', .85);
  h = handle(viscircles(centers, radii,...
	 'DrawBackgroundCircle',false,...
	 'LineWidth',1,...
	 'EdgeColor','m'...
	 ));
  C(k).centers = centers;
  C(k).radii = radii;
  C(k).h = h;  
end



%%
cellMask = circleCenters2Mask(centers, radii, size(vid(1).cdata));
