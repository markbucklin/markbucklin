function [xc, template] = alignVid2Mean_SubPixel(vid, varargin)

if isstruct(vid)
   firstFrame = vid(1).cdata;
else
   firstFrame = vid(:,:,1);
end

maxOffset = floor(min(size(firstFrame))/4);
ysub = maxOffset+1 : size(firstFrame,1)-maxOffset;
xsub = maxOffset+1 : size(firstFrame,2)-maxOffset;

if nargin < 2
   vidMean = firstFrame;
   template = gpuArray(im2single(vidMean(ysub,xsub)));
else
   template = gpuArray(varargin{1});
end

maxSubPixel = 10;
templateSize = size(template);
subPixelFactor = adjustSubPixelation(maxSubPixel, templateSize);
template = imresize(template, subPixelFactor);
ysubsp = (ysub(1)*subPixelFactor-subPixelFactor) + 1 : ysub(end)*subPixelFactor;
xsubsp = (xsub(1)*subPixelFactor-subPixelFactor) + 1 : xsub(end)*subPixelFactor;

offsetShift = min(size(template)) + maxOffset*subPixelFactor;
if isstruct(vid)
   if isfield(vid,'frame')
	  frameMeanContribution = 1./[vid.frame];
   else
	  frameMeanContribution = 1./[1:numel(vid)];
   end
else
   frameMeanContribution = 1./[1:size(vid,3)];
end

validMaxMask = [];
if isstruct(vid)
   N = numel(vid);
else
   N = size(vid,3);
end
xc(N).cmax = zeros(N,1);
xc(N).xoffset = zeros(N,1);
xc(N).yoffset = zeros(N,1);
h = waitbar(0,  sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%f secs/frame)',1,N,0));
tic

for k = 1:N
   if isstruct(vid)
	  movingFrame = gpuArray(vid(k).cdata);
   else
	  movingFrame = gpuArray(vid(:,:,k));
   end
   movingFrame = im2single(movingFrame);
   movingFrame = imresize(movingFrame, subPixelFactor);
   c = normxcorr2(template, movingFrame);
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
   template = adjustedFrame*ndt + template*(1-ndt);
   xc(k).cmax = gather(cmax);
   xc(k).xoffset = gather(xoffset)/subPixelFactor;
   xc(k).yoffset = gather(yoffset)/subPixelFactor;
   
   waitbar(k/N, h, ...
	  sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%f secs/frame)',k,N,toc));
   tic
end
delete(h);
template = gather( imresize(template, 1/subPixelFactor) );


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