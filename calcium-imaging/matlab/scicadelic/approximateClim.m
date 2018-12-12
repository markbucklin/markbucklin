function cLim = approximateClim(im)

if ismatrix(im)
	lowLim = approximateFrameMinimum(im);
	highLim = approximateFrameMaximum(im);
	cLim = [lowLim highLim];
	
else
	% 	sz = size(im);
	% 	[~,timeDim] = max(sz(3:end));
	% 	timeDim = timeDim+2;
	% 	meanIm = mean(im, timeDim);
	% 	lowLim = approximateFrameMinimum(meanIm);
	% 	highLim = approximateFrameMaximum(meanIm);
	
	lowLim = approximateFrameMinimum(im);
	highLim = approximateFrameMaximum(im);
	cLim = cat(2, lowLim, highLim);
	
end





