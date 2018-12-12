function [obj, Uxy] = motionCorrectFluoProObjData(obj, chunkSize)

if nargin <2
	chunkSize = 16;
end

N = size(obj.data,3);
idx = 1:chunkSize;
F = gpuArray(obj.data(:,:,idx));
Flocalfixed = mean(F,3);
Fglobalfixed = gaussFiltFrameStack(gpuArray(mean(obj.postSample,3)));
Uxy(N,2) = single(0);


while ~isempty(idx) && (idx(end) <= N)
	try
		F = gpuArray(obj.data(:,:,idx));
		[F2, uxy] = correctMotionGpu(F, Flocalfixed, Fglobalfixed);
		obj.data(:,:,idx) = gather(F);
		Uxy(idx,:) = oncpu(uxy);

		Flocalfixed = F(:,:,end);


	catch me
		msg = getReport(me);
		disp(msg)
	end
	idx = idx(end) + (1:chunkSize);
	idx = idx(idx<=N);
end



