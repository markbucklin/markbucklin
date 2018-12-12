function maxval = getNearMax(data)

sz = size(data);
nFrames = sz(end);
sampSize = min(nFrames, 500);
% maxval = max(data(:));
maxSamp = zeros(sampSize,1);
sidx = ceil(linspace(1, nFrames, sampSize))';
for ks=1:sampSize
   maxSamp(ks) = double(max(max(data(:,:,sidx(ks)))));
end

sampval = mean(maxSamp) + exp(1)*std(double(maxSamp));
% maxval = min( double(maxval), double(sampval));
dataRange = getrangefromclass(data);
maxval = min(sampval, dataRange(2));







