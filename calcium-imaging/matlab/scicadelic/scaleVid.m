function F = scaleVid( F, lims)

lowerLim = lims(1);
upperLim = lims(2);
scaleFactor = 1 / (upperLim-lowerLim);

if ~isfloat(F)
	F = single(F);
end

F = (rail(F, lims)-lowerLim)*(scaleFactor);


