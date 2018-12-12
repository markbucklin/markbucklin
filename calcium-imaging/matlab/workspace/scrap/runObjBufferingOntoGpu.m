function [data, info, benchTime] = runObjBufferingOntoGpu(csys, data, bufSize)
warning('runObjBufferingOntoGpu.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if nargin < 3
	bufSize = 8;
end
if ~iscell(csys)
	csys = {csys};
end

N = size(data,3);

idx = 0; 
k=0;
benchTime = zeros(ceil(N/bufSize),1);
hWait = waitbar(0,'processing time');
returnInfo = false;

while idx(end) < N
	tStart = tic; 
	k=k+1;
	idx = idx(end)+(1:bufSize);
	idx = idx(idx<=N);

	gdata = gpuArray(data(:,:,idx));	
	for Sn = 1:numel(csys)
		gdata = step(csys{Sn}, gdata);
		if isprop(csys{Sn}, 'Info')
			[~,fn] = strtok(class(csys{Sn}),'.');
			fn = fn(isletter(fn));
			info(k).(fn) = csys{Sn}.Info;
			returnInfo = true;
		end
	end	
	data(:,:,idx) = gather(gdata);
	
	t = toc(tStart);
	benchTime(k) = t;
	waitbar(idx(end)/N, hWait, sprintf('processing time: %-03.3g ms/frame',t*1000/bufSize));
end
close(hWait)

if returnInfo
	info = unifyStructArray(info);
else
	info = struct([]);
end


