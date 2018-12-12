% prebuffle
%%


chTempFilter = scicadelic.TemporalFilter;
chStatCollector = scicadelic.StatisticCollector;
chMedFilter = scicadelic.HybridMedianFilter;

proc = initProc();

%%
for burnIn = 1:4
	[F, mot, dstat, proc] = feedFrameChunk(proc);
	A = step(chTempFilter, dstat.M4);
	A = log(abs( A ));
	A = step(chMedFilter, A);
	A = gaussFiltFrameStack(A, 1.5);
	step(chStatCollector, A);
end

N = proc.tl.FileFrameIdx.last(end);
reset(proc.tl)
[numRows, numCols, numFramesPerChunk] = size(F);



Fcpu(numRows,numCols,N) = uint16(0);
Rcpu(numRows,numCols,N) = single(0);
Acpu(numRows,numCols,N) = single(0);


%%
idx = 0;
while proc.idx(end)<N
	[F, mot, dstat, proc] = feedFrameChunk(proc);
	idx = oncpu(proc.idx);
	idx = idx(idx <=N);	
	
	Fsmooth = single(mean(gaussFiltFrameStack(F, 1),3));
	R = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], Fsmooth);
	R = gaussFiltFrameStack(R, 1.5);
	
	A = step(chTempFilter, dstat.M4);
	A = log(abs( A ));
	A = step(chMedFilter, A);
	A = gaussFiltFrameStack(A, 1.5);
	step(chStatCollector, A);
	
	
	
Fcpu(:,:,idx) = gather(F); % BG
Rcpu(:,:,idx) = gather(R); % Structure or activity
Acpu(:,:,idx) = gather(A); % Activity
% 	h = imscplay(im);
% 	drawnow;
end

%%
Fmean = mean(Fcpu,3);
Rmean = mean(Rcpu,3); 
Amean = mean(Acpu,3); 

Fexp = expnormalizedcomplement(Fcpu);


imscplay(bsxfun(@minus, single(Fcpu), single(Fmean)))



% s = getappdata(h.fig,'s')
% bsxfun(@minus, single(F), proc.sc.Mean)



% Fmax = single(max(Fcpu,[],3));
% Fexp = 1 - exp( bsxfun(@rdivide, bsxfun(@minus, single(Fcpu), Fmax), Fmax));