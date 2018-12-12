

bufSize=2.^(0:5);
benchTime = zeros(size(bufSize));
idx = 0; 
for k=1:numel(bufSize)
	idx = idx(end)+(1:bufSize(k));
	output = step(obj, data(:,:,idx));
	
	tStart = hat; 
	idx = idx(end)+(1:bufSize(k));
	output = step(obj, data(:,:,idx));
	benchTime(k) = hat - tStart;
	disp(benchTime)
end
