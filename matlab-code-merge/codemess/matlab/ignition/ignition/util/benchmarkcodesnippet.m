


bufSize=2.^(0:5);
benchTime = zeros(size(bufSize));
idx = 0;

% #### SETUP CODE TO BENCHMARK ###
maxExpectedDiameter = obj.MaxExpectedDiameter;
dsVec = [2.^(2:nextpow2(maxExpectedDiameter)-1), maxExpectedDiameter];
% ###


for kb=1:numel(bufSize)
	idx = idx(end)+(1:bufSize(kb));
	
	% 	F = gpuArray(alldata(:,:,idx));
	F = alldata(:,:,idx);
	
	tStart = hat;
	
	
	% #### BEGIN CODE TO BENCHMARK ###
	if isa(F, 'gpuArray')
		bwFg = gpuArray.false(size(F));
	else
		bwFg = false(size(F));
	end
	for k=1:length(dsVec)
		bwFg = bwFg | findPixelForegroundArrayWise(F,dsVec(k));
	end
	
	% #### END CODE TO BENCHMARK ###
	
	benchTime(kb) = hat - tStart;
	disp(benchTime)
end


benchVectorisedCpu = benchTime;




