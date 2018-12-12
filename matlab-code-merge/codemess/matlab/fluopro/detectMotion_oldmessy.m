function detectMotion(data)

global FPOPTION

sz = size(data);
N = sz(ndims(data));


scale16to8 = @(X) uint8(idivide( X, 65535/255,'fix'));
scaleTo8 = @(X) uint8( (X-min(X(:))) ./ (range(X(:)/255)));
inRgbChannel = @(X, ch) scaleTo8(shiftdim(cat(3, zeros([size(X,1) size(X,2) 2], 'like',X),X), ch));
bwVesselMask = @(X) ...
   bwmorph(bwmorph(bwmorph(...
   edge(imfill(imcomplement(...
   scale16to8(X)...
   )),'sobel'),...
   'clean'),'close'),'majority');
bwCellMask = @(X) ...
   bwmorph(bwmorph(bwmorph(...
   edge(imfill(...
   scale16to8(X)...
   ),'sobel'),...
   'clean'),'close'),'majority');
gfilt = fspecial('gaussian', 15, 1.5);
g = @(X) imfilter(X,gfilt);
cornFcn = @(Ix,Iy) sqrt(g(abs(Ix)).*g(abs(Iy))) - .5*sqrt(g(Ix.^2) + g(Iy.^2));



if FPOPTION.useGpu
   F = g(gpuArray(getDataSample(data)));
else
   F = getDataSample(data);
end

[Fx, Fy, Ft] = gradient(single(F));

structen = @(x,y,k,w) [...
   mean2(Fx(y-floor(w/2):y+ceil(w/2),x-floor(w/2):x+ceil(w/2),k)^2),...
   mean2(Fx(y-floor(w/2):y+ceil(w/2),x-floor(w/2):x+ceil(w/2),k)*Fy(y-floor(w/2):y+ceil(w/2),x-floor(w/2):x+ceil(w/2),k));...
   mean2(Fx(y-floor(w/2):y+ceil(w/2),x-floor(w/2):x+ceil(w/2),k)*Fy(y-floor(w/2):y+ceil(w/2),x-floor(w/2):x+ceil(w/2),k)),...
   mean2(Fy(y-floor(w/2):y+ceil(w/2),x-floor(w/2):x+ceil(w/2),k)^2)];

x = imfuse(gather(scaleTo8(abs(Fx(:,:,1)))),gather(scaleTo8(abs(Fy(:,:,1)))), 'ColorChannels', [1 2 0]);
imshow(decorrstretch(x + gather(inRgbChannel(abs(F(:,:,1)),3))))

showAbsGrad = @(k) imshow(decorrstretch(...
   imfuse(gather(scaleTo8(abs(Fx(:,:,k)))),gather(scaleTo8(abs(Fy(:,:,k)))), 'ColorChannels', [1 2 0])...
   + gather(inRgbChannel(abs(F(:,:,k)),3))));

showVC = @(k) imshow(decorrstretch(...
   imfuse(...
   bwVesselMask(data(:,:,k)),...
   bwCellMask(data(:,:,k)),...
   'ColorChannels', [1 2 0])...
   + inRgbChannel(data(:,:,k),3)));

% ------------------------------------------------------------------------------------------
% DETECT FOREGROUND (SALIENT PIXELS)
% ------------------------------------------------------------------------------------------
fgDetector = vision.ForegroundDetector('NumTrainingFrames',100);
d8a = scaleTo8(data);
fgMean = zeros(sz(1),sz(2),1,'double');
for k=1:N
   fgMean = fgMean + double(step(fgDetector,d8a(:,:,k)));
end


% ------------------------------------------------------------------------------------------
% FIND CORNERS
% ------------------------------------------------------------------------------------------
targetNumCorners = 100;


im = d8a(:,:,1);
minContrast = .01; % 0-1
minQuality = .25;
featLimBox = [...
   fix(sz(2)/4),...
   fix(sz(1)/4),...
   fix(sz(2)/2),...
   fix(sz(1)/2)];		% [X Y WIDTH HEIGHT] ->(X,Y) is top left
pts(N,1).fast = cornerPoints.empty(1000,0);
pts(N,1).features = binaryFeatures.empty(1,0);
pts(N,1).validpoints = cornerPoints.empty(1000,0);
pts(N,1).matchnext = cornerPoints.empty(1000,0);
pts(N,1).matchprevious = cornerPoints.empty(1000,0);
pts(N,1).matchfirstk = cornerPoints.empty(1000,0);
pts(N,1).matchfirst1 = cornerPoints.empty(1000,0);
parfor k=1:N
   pts(k).fast =  detectFASTFeatures(d8a(:,:,k), 'MinContrast', minContrast, 'MinQuality',minQuality);
   [pts(k).features, pts(k).validpoints] = extractFeatures(d8a(:,:,k), pts(k).fast);
end
for k=1:N
   if k<N
	  knext = k+1;
   else
	  knext = 1;
   end
   indexPairs = matchFeatures(pts(k).features, pts(knext).features,...
	  'Unique', true,...
	  'MatchThreshold', 20);
   pts(k).matchnext = pts(k).validpoints(indexPairs(:,1));
   pts(knext).matchprevious = pts(knext).validpoints(indexPairs(:,2));
   indexPairs = matchFeatures(pts(k).features, pts(1).features,...
	  'Unique', true,...
	  'MatchThreshold', 20);
   pts(k).matchfirstk = pts(k).validpoints(indexPairs(:,1));
   pts(k).matchfirst1 = pts(1).validpoints(indexPairs(:,2));
   
   showMatchedFeatures(d8a(:,:,k), d8a(:,:,1), pts(k).matchfirstk, pts(k).matchfirst1)
   title(sprintf('Frame %i matched to Frame %i',k, 1));
   drawnow
end


% detectMinEigenFeatures
% detectBRISKFeatures
% SURF
% MSER (Maximally Stable Extremal Regions)
% Harris
% -> extractFeatures
% -> matchFeatures
% -> Location( points.selectStrongest )

% Display corners found in images A and B.
figure; imshow(im); hold on;
plot(pointsA);
title('Corners in A');

figure; imshow(imgB); hold on;
plot(pointsB);
title('Corners in B');



% BLOB & FOREGROUND?


blob = vision.BlobAnalysis(...
   'CentroidOutputPort', false, 'AreaOutputPort', false, ...
   'BoundingBoxOutputPort', true, ...
   'MinimumBlobAreaSource', 'Property', 'MinimumBlobArea', 100);
fgMask = step(fgDetector, data(:,:,1));
d8a = scaleTo8(data);
videoPlayer = vision.VideoPlayer();
shapeInserter = vision.ShapeInserter('BorderColor','White');
for k=1:size(d8a,3)
   frame  = d8a(:,:,k);
   fgMask = step(fgDetector, frame);
   bbox   = step(blob, fgMask);
   out    = step(shapeInserter, frame, bbox); % draw bounding boxes around cars
   step(videoPlayer, out); % view results in the video player
end





















