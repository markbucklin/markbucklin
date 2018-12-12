function vid = correctBrainMotion(vid)

subPixelFactor = 10;
fixedPixCountMax = 3e5;
[winrows, wincols] = getRobustWindow(vid, 100);
crFixed = [wincols(1) , wincols(end)-wincols(1) , winrows(1) , winrows(end)-winrows(1)];

% ACCOMODATE A LARGE CORRELATION REGION BY REDUCING SUBPIXELATION
fixedWidth = crFixed(3)+1;
fixedHeight = crFixed(4)+1;
nFixedPix = fixedWidth*fixedHeight*subPixelFactor^2;
while (nFixedPix > fixedPixCountMax)
	subPixelFactor = subPixelFactor - 1;
	nFixedPix = fixedWidth*fixedHeight*subPixelFactor^2;
	fprintf('Reducing subpixellation factor used for xcorr motion correction,\n\tsubPixelFactor: %g\n',...
	subPixelFactor)
end

out = alignVidRecursive(vid, crFixed);
keyboard
