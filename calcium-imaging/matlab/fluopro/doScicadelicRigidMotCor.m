
MC = scicadelic.RigidMotionCorrector;
bufsize = 32;
N = size(obj.data,3);
[gdata(:,:,bufsize) , motinfo(N)] = step(MC, gpuArray(obj.data(:,:,1)));
% mcdata = obj.data(:,:,500);
% N = 500;
for kbuf=0:bufsize:N
	fprintf('Correcting Motion in Frames: %i to %i\n',kbuf+1, kbuf+bufsize);
	idx = kbuf+(1:bufsize);
	idx = idx(idx<=N);
	gdata = gpuArray(obj.data(:,:,idx));
	for k=1:size(gdata,3)
		[gdata(:,:,k), info(k)] = step(MC,gdata(:,:,k));
	end
	obj.data(:,:,idx) = gather(gdata);
% mcdata(:,:,idx) = gather(gdata);
	motinfo(idx) = info(1:numel(idx)); 
end
motinfo = unifyStructArray(motinfo);






bufsize = 32;
N = size(obj.data,3);

for kbuf=0:bufsize:N
	fprintf('Filtering Frames: %i to %i\n',kbuf+1, kbuf+bufsize);
	idx = kbuf+(1:bufsize);
	idx = idx(idx<=N);
	gdata = gpuArray(obj.data(:,:,idx));
	for k=1:size(gdata,3)
		gdata(:,:,k) = medfilt2(gdata(:,:,k));
	end
	obj.data(:,:,idx) = gather(gdata);	
end


