function obj= hybridMedianFiltFluoProObjData(obj)

idx = 0;
N = size(obj.data,3);
chunkSize = 32;

while ~isempty(idx) && (idx(end) < N-1)
	try
		idx = idx(end) + (1:chunkSize);
		idx = idx(idx<=N);
		if isempty(idx)
			break
		end
		F = gpuArray(obj.data(:,:,idx));
		F = hybridMedianFilterRunGpuKernel(F);
		obj.data(:,:,idx) = gather(F);
	catch me
		showError(me)
	end
end



