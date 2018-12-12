fld = fields(md(1).vidstats);
normimage = @(im) uint8(255*(double(im)-min(double(im(:))))/double(range(im(:))));
% vstat = cat(2,md.vidstats);
for fln = 1:numel(fld)
   fn = fld{fln};
   for k=1:numel(md)
	  vday(k).(fn) = mean(cat(3,md(k).vidstats.(fn) ), 3);
   end
   vd.(fn).unregdata = cat(3,vday.(fn));
%    figure, imaqmontage(permute(shiftdim(vd.(fn).unregdata, -1), [2, 3, 1, 4])),title(fn);
   %    [v.(fn).regdata, v.(fn).xc, v.(fn).prealign] = correctMotion(v.(fn).unregdata);
end

fixedImage = cat(3,...
   normimage(vd.Mean.unregdata(:,:,1)),...
   normimage(vd.Std.unregdata(:,:,1)),...
   255-normimage(vd.Min.unregdata(:,:,1)));
cpout(1).im = fixedImage;
for k =2:numel(md)
   movingImage = cat(3,...
	  normimage(vd.Mean.unregdata(:,:,k)),...
	  normimage(vd.Std.unregdata(:,:,k)),...
	  255-normimage(vd.Min.unregdata(:,:,k)));
   if k<3
	  [movingPoints,fixedPoints] = cpselect(movingImage, fixedImage,'wait',true);
   else
	  [movingPoints,fixedPoints] = cpselect(movingImage, fixedImage,movingPoints, fixedPoints,'wait',true);
   end
   t = cp2tform(movingPoints, fixedPoints, 'nonreflective similarity');
   
   
   u = [0 1];
   v = [0 0];
   [x, y] = tformfwd(t, u, v);
   dx = x(2) - x(1);
   dy = y(2) - y(1);
   cpout(k).angle = (180/pi) * atan2(dy, dx);
   cpout(k).scale = 1 / sqrt(dx^2 + dy^2) ;
   cpout(k).displacement = [dx dy];
   
   cpout(k).tform = t;
   %    cpout(k).im = imwarp(movingImage(:,:,1),cpout(k).tform.tdata.T);
   cpout(k).movingpoints = movingPoints;
   cpout(k).fixedpoints = fixedPoints;
   %    fixedImage = fixedImage * ((k-1)/k) + cpout{k} * (1/k);
   %    cpout(k).fixedim = fixedImage;
end












data = vmouse.Mean.dcdata;
data = bsxfun(@rdivide, double(bsxfun(@minus, data, min(min(data,[],1),[], 2))), double(range(range(data,1),2)) );
imFixed = data(:,:,1);
for k=2:size(data,3);
   imMoving = data(:,:,k);
   tform =  imregtform(imMoving, imFixed, 'rigid',optimizer,metric);
   imRegistered = imwarp(imMoving,tform,'OutputView',imref2d([1024 1024]));
   regOutput{k} = imfuse(imFixed, imRegistered, 'Scaling','joint');
   regTform{k} = tform;
   data(:,:,k) = imRegistered;
end

% normimage = @(im) uint8(255*(double(im)-min(double(im(:))))/double(range(im(:))));
% ref = imref2d([1024 1024], 13,13);
% [optimizer,metric] = imregconfig('monomodal');
% optimizer.MinimumStepLength = .000005;
% optimizer.MaximumStepLength = .001;
% optimizer.RelaxationFactor = .4;
% optimizer.GradientMagnitudeTolerance = .0005;
% vsFixed = md(1).vidstats;
% regOutput = cell(numel(md),numel(vsFixed));
% regTform = cell(numel(md),numel(vsFixed));
% msk = cell(numel(md),1);
% for k=1:numel(md)
%    msk{k} = md(k).roi.createMask;
% end
% fixedMask = ~imdilate(msk{1},strel('disk',10,8));
% for kMoving = 1:numel(md)
%    vsMoving = md(kMoving).vidstats;
%    movingMask =  ~imdilate(msk{kMoving},strel('disk',10,8));
%    parfor k = 1:numel(vsMoving)
% 	  imFixed =  maskimage( normimage(vsFixed(k).Max), fixedMask,0);
% 	  imMoving = maskimage(normimage(vsMoving(k).Max), movingMask, 0);
% 	  tform =  imregtform(imMoving, ref, imFixed, ref, 'rigid',optimizer,metric);
% 	  imRegistered = imwarp(imMoving,tform);
% 	  regOutput{kMoving,k} = imfuse(imFixed, imRegistered, 'Scaling','joint');
% 	  regTform{kMoving,k} = tform;
%    end
% end



% regOutput{kMoving,k} = imfuse(imFixed, imwarp(imMoving,regTform{kMoving,k}), 'Scaling','joint');