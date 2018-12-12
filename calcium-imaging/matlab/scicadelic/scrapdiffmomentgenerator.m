if ~exist('TL','var')
	TL = scicadelic.TiffStackLoader;
	TL.FramesPerStep = 16;
	setup(TL)
	MF = scicadelic.HybridMedianFilter;
	CE = scicadelic.LocalContrastEnhancer;
	MC = scicadelic.RigidMotionCorrector;
	MC.CorrectionInfoOutputPort = false;
	MC.AlwaysAlignToMovingAverage = false;
	SC = scicadelic.StatisticCollector;
	SC.DifferentialMomentOutputPort = true;
else
	reset(TL)
end


%%
% VFW = vision.VideoFileWriter;
% VFW.VideoCompressor = 'DV Video Encoder';
% VFW.FileFormat = 'MPEG4';
% VFW.Quality = 90;
% VFW.Filename = [TL.FileDirectory, 'Differential 3rd Moment.mp4'];


%%
m=1;
[f,idx]=step(TL);
f = step(MF,f);
f = step(CE,f);
f = step(MC,f);
% [gstat, stat] = differentialMomentGeneratorRunGpuKernel(f);
gstat = step(SC,f);
fn = fields(gstat);

numTotalFrames = TL.FileFrameIdx(end).last;
% numTotalFrames = 16*25;

for k=1:numel(fn)
	cstat.(fn{k})(:,:,idx) = single(gather(gstat.(fn{k})));
	cstat.(fn{k})(:,:,numTotalFrames) = cstat.(fn{k})(:,:,1);
end

%%
while (idx(end)+16)<=numTotalFrames%~isDone(TL)
	disp(m)
	m=m+1;
	[f,idx]=step(TL); 
	f = step(MF,f);
	f = step(CE,f);
	f = step(MC,f);
	gstat = step(SC, f);
	% 	[gstat, stat] = differentialMomentGeneratorRunGpuKernel(f, stat);
	for k=1:numel(fn)
		cstat.(fn{k})(:,:,idx) = gather(gstat.(fn{k}));
	end
	im = gstat.M3;
	im = sqrt(abs(im)) .* sign(im);
	immed = median(cat(1, permute(median(im,1),[2 1 3]), median(im,2)),1);
	im = gather(bsxfun(@minus, im, immed));
	hIm = imsc(im(:,:,1));	
	hAx = handle(gca);
	set(hAx,'CLim',[-2e5 2e5])
	pause(.05)
% 	drawnow
% 	imFrame = getframe(hAx);
% 	step(VFW, imFrame.cdata);
	
	for k=2:16
		hIm.CData = im(:,:,k);
		pause(.05)
% 		drawnow
% 		imFrame = getframe(hAx);
% 		step(VFW, imFrame.cdata);
	end
	% 	imsc(znormalize(gstat.M3, [1 2]))
	% 	imsc(pnormalizeApprox(cstat.M3(:,:,idx), [1 2]))
	
end

%%
vidrgb(1024,1024,3,numTotalFrames) = uint8(0);
for k=1:numTotalFrames
	im = cstat.M3(:,:,k);
	im = sqrt(abs(im)) .* sign(im);
	im = 255*im/1e5;
	imrgb = cat(3, uint8(im/2), uint8(im*2), uint8(-im));
	vidrgb(:,:,:,k) = imrgb;
	% 	imshow(imrgb)
	% 	pause(.05)
end
saveData2Mp4(vidrgb)