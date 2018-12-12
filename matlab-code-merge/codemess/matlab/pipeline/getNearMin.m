function minval = getNearMin(data)

sz = size(data);
nFrames = sz(end);
sampSize = min(nFrames, 500);
% minval = min(data(:));
minSamp = zeros(sampSize,1);
sidx = ceil(linspace(1, nFrames, sampSize))';
for ks=1:sampSize
   minSamp(ks) = double(min(min(data(:,:,sidx(ks)))));
end

sampval = mean(minSamp) - exp(1)*std(double(minSamp));
% minval = min( double(minval), double(sampval));
dataRange = getrangefromclass(data);
minval = max(dataRange(1), sampval);