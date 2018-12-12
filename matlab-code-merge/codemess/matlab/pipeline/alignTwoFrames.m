function [yoffset, xoffset] = alignTwoFrames(leftFrame, rightFrame)

subPixelFactor = 5;

fixed = gpuArray(imcrop(im2single(leftFrame),crFixed));
fixed = imresize(fixed, subPixelFactor);
N = min(size(fixed));

moving = gpuArray(imcrop(rightFrame,crMoving));
moving = im2single(moving);
moving = imresize(moving, subPixelFactor);
c = normxcorr2(fixed, moving);
% find peak in cross correlation
[cmax, imax] = max(abs(c(:)));
[ypeak, xpeak] = ind2sub(size(c),imax(1));
% account for offset from padding?
xoffset = N/2 - xpeak;
yoffset = N/2 - ypeak;

cmax = gather(cmax);
xoffset = gather(xoffset)/subPixelFactor;
yoffset = gather(yoffset)/subPixelFactor;


% 	im = imtranslate(im, [xoffset yoffset], 'linear', 'OutputView','same', 'FillValues', 0)
% OR
% sz = size(data);
% yPadSub = maxOffset+1 : sz(1)+maxOffset;
% xPadSub = maxOffset+1 : sz(2)+maxOffset;
% [Xq, Yq] = meshgrid(xPadSub+xoffset, yPadSub+yoffset);
% adjustedFrame = interp2(adjustedFrame, Xq, Yq);


