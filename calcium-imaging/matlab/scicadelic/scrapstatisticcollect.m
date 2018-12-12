
%%
m=1;
reset(TL)
[f,idx]=step(TL);
f = step(MF,f);
f = step(CE,f);
f = step(MC,f);
[stat, gstat] = statisticCollectorRunGpuKernel(f);
fn = fields(gstat);
numTotalFrames = TL.FileFrameIdx(end).last;
for k=1:numel(fn)
	cstat.(fn{k})(:,:,idx) = single(gather(gstat.(fn{k})));
	cstat.(fn{k})(:,:,numTotalFrames) = cstat.(fn{k})(:,:,1);
end

%%
while ~isDone(TL)
	disp(m)
	m=m+1; 
	[f,idx]=step(TL); 
	f = step(MF,f);
	f = step(CE,f);
	f = step(MC,f);
	[stat, gstat] = statisticCollectorRunGpuKernel(f, stat); 
	for k=1:numel(fn)
		cstat.(fn{k})(:,:,idx) = single(gather(gstat.(fn{k})));
	end
	imsc(znormalize(gstat.M3, [1 2]))
	% 	imsc(pnormalizeApprox(cstat.M3(:,:,idx), [1 2]))
	drawnow
end
