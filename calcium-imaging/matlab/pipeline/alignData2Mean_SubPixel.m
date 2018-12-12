function [xc, prealign] = alignData2Mean_SubPixel(data, varargin)


firstFrame = data(:,:,1);


maxOffset = floor(min(size(firstFrame))/3);
ysub = maxOffset+1 : size(firstFrame,1)-maxOffset;
xsub = maxOffset+1 : size(firstFrame,2)-maxOffset;

sz = size(data);
nFrames = sz(3);
if nargin < 2
   %    prealign.hMean = vision.Mean(...
   % 	  'RunningMean',true,...
   % 	  'Dimension',3);
   prealign.cropBox = selectWindowForMotionCorrection(data,sz(1:2)./2);
   prealign.n = 0;
   fixedFrame = gpuArray(im2single(vidMean(ysub,xsub)));
else
   prealign = varargin{1};
   fixedFrame = gpuArray(prealign.template);
end
ySubs = round(prealign.cropBox(2): (prealign.cropBox(2)+prealign.cropBox(4)-1)');
xSubs = round(prealign.cropBox(1): (prealign.cropBox(1)+prealign.cropBox(3)-1)');


maxSubPixel = 10;
templateSize = size(fixedFrame);
subPixelFactor = adjustSubPixelation(maxSubPixel, templateSize);
fixedFrame = imresize(fixedFrame, subPixelFactor);
ysubsp = (ysub(1)*subPixelFactor-subPixelFactor) + 1 : ysub(end)*subPixelFactor;
xsubsp = (xsub(1)*subPixelFactor-subPixelFactor) + 1 : xsub(end)*subPixelFactor;

offsetShift = min(size(fixedFrame)) + maxOffset*subPixelFactor;
frameMeanContribution = 1./[1:size(data,3)];


validMaxMask = [];
N = size(data,3);
xc(N).cmax = zeros(N,1);
xc(N).xoffset = zeros(N,1);
xc(N).yoffset = zeros(N,1);
h = waitbar(0,  sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%f secs/frame)',1,N,0));
tic

for k = 1:N
   movingFrame = gpuArray(data(:,:,k));
   movingFrame = im2single(movingFrame);
   movingFrame = imresize(movingFrame, subPixelFactor);
   c = normxcorr2(fixedFrame, movingFrame);
   % Restrict available peaks in xcorr matrix
   if isempty(validMaxMask)
	  validMaxMask = false(size(c));
	  mosp = maxOffset*subPixelFactor;
	  validMaxMask(offsetShift-mosp:offsetShift+mosp, offsetShift-mosp:offsetShift+mosp) = true;
   end
   c(~validMaxMask) = 0;
   c(c<0) = 0;
   % find peak in cross correlation
   [cmax, imax] = max(abs(c(:)));
   [ypeak, xpeak] = ind2sub(size(c),imax(1));
   % account for offset from padding?
   xoffset = xpeak - offsetShift;
   yoffset = ypeak - offsetShift;
   % APPLY OFFSET AND ADD TO VIDMEAN
   adjustedFrame = movingFrame(ysubsp+yoffset , xsubsp+xoffset);
   ndt = frameMeanContribution(k);
   fixedFrame = adjustedFrame*ndt + fixedFrame*(1-ndt);
   xc(k).cmax = gather(cmax);
   xc(k).xoffset = gather(xoffset)/subPixelFactor;
   xc(k).yoffset = gather(yoffset)/subPixelFactor;
   
   waitbar(k/N, h, ...
	  sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%f secs/frame)',k,N,toc));
   tic
end
delete(h);
prealign.template = gather( imresize(fixedFrame, 1/subPixelFactor) );

% ACCOMODATE A LARGE CORRELATION REGION BY REDUCING SUBPIXELATION
   function subPixelFactor = adjustSubPixelation(subPixelFactor, templateSize)
	  maxNumTemplatePixels = 5e6;
	  templateWidth = templateSize(1)+1;
	  templateHeight = templateSize(2)+1;
	  nTemplatePixels = templateWidth*templateHeight*subPixelFactor^2;
	  while (nTemplatePixels > maxNumTemplatePixels)
		 subPixelFactor = subPixelFactor - 1;
		 nTemplatePixels = templateWidth*templateHeight*subPixelFactor^2;
		 fprintf('Reducing subpixellation factor used for xcorr motion correction,\n\tsubPixelFactor: %g\n',...
			subPixelFactor)
	  end
   end
end


