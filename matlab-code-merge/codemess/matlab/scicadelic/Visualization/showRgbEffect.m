function showRgbEffect(Rin, Rout)
% SHOWRGBEFFECT
%
% Uses Red-Green-Blue to show the effect of a morphological operation
%		Red: pixel SWITCHED-ON
%		Green: pixel UNCHANGED-ON
%		Blue: pixel SWITCHED-OFF

indims = ndims(Rin);
outdims = ndims(Rout);
if max(indims,outdims) < 4
	channelDim = 4;
else
	channelDim = 3;
end

redChan = bsxfun(@and, ~Rin, Rout);
greenChan = bsxfun(@and, Rin, Rout);
blueChan = bsxfun(@and, Rin, ~Rout);

imrgbplay( cat(channelDim, redChan, greenChan, blueChan));


