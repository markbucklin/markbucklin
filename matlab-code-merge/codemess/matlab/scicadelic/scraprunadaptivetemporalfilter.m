idx=1:16;
[F, F0, A, stat, dmstat] = temporallyAdaptiveTemporalFilterRunGpuKernel(F);
while idx(end)< 2030
idx=idx(end)+(1:16);
F = gpuArray(Fcpu(:,:,idx));
[F, F0, A, stat, dmstat] = temporallyAdaptiveTemporalFilterRunGpuKernel(F, F0, A, stat, dmstat);
end

