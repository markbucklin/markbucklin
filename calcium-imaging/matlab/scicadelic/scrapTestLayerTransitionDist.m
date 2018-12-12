%%
layerTransitionDist = [];

%%
% for k=1:20
while ~isDone(TL)
	[F, idx] = TL.step();
	F = step(MF, F);
	F = step(CE, F);
	F = step( MC, F);
	[labelGroupSignal, pixelLabel] = step(PGC,F);
	
	pixelLayer = PGC.PixelLayer;
	if isempty(layerTransitionDist)
		[layerTransitionDist, isLocalPeak, isLocalBorder] = updateLayerTransitionDistanceRunGpuKernel(pixelLayer);
	else
		[layerTransitionDist, isLocalPeak, isLocalBorder] = updateLayerTransitionDistanceRunGpuKernel(pixelLayer,layerTransitionDist);
	end
	% 	imsc(layerTransitionDist)
	% 	imcomposite(pixelLayer, layerTransitionDist>1, isLocalPeak)
	imcomposite(F(:,:,end), isLocalBorder, imdilate(isLocalPeak & pixelLayer>.3 ,ones(2)), pixelLayer>.5)
	imcomposite(F(:,:,end), isLocalBorder, imdilate(isLocalPeak & pixelLayer>.3 ,ones(2)), layerTransitionDist>1)
	
	%		imcomposite(pixelLayer, isLocalBorder, imdilate(isLocalPeak,ones(3))&~isLocalBorder, layerTransitionDist>2)
	
	% 	imcomposite(pixelLayer, layerTransitionDist>1, layerTransitionDist>2, layerTransitionDist>3)
	drawnow
	
end

%%
reset(TL)
reset(MC)


