function displayParallelWorkerGpuIdx()


warning('off','MATLAB:structOnObject')
pool = gcp;
clus = pool.Cluster;
gdmgr = parallel.gpu.GPUDeviceManager.instance;
gpuDevice([]); % deselect

spmd
	gd = gpuDevice();
	if gd.DeviceSelected
		fprintf('Lab: %d\tGPU: %d\n',labindex, gd.Index)
	end
end



function displayStruct(s)
% todo: incorporate
flds = fields(s);
s = s(1);
for k=1:numel(flds)
	fprintf('\n-------------------\n%s\n-------------------\n',flds{k})
	disp(s.(flds{k}))
end
