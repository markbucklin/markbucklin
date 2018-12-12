% sc = scicadelic.StatisticCollector;

F0 = [];
M = [];
S = [];
N = [];
A = [];
idx=0; 
while idx(end)<2047
	idx=idx(end)+(1:16);
	F=gpuArray(Fcpu(:,:,idx));
	step(sc, F);
	[F, F0, M, S, N, A] = temporallyAdaptiveTemporalFilterRunGpuKernel(F, F0, M, S, N, A);
	if ~ismatrix(A) % if size(A,3) == numel(idx)
		Ft(:,:,idx) = gather(A);
	else
		Ft(:,:,idx) = repmat(gather(A),1,1,numel(idx));
	end
end




Ftmean = mean(mean(Ft));
Ftcolmean = mean(Ft,1);
Ftrowmean = mean(Ft,2);
Ftrowcolmeanmin = min(min(Ftcolmean),min(Ftrowmean));
chunkThresh = reshape(smooth(Ftmean(:),32) ./ 8, 1,1,[]);

