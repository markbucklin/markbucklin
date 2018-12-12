function dataSample = getDataSample(data,varargin)

N = size(data,ndims(data));
if nargin > 1
	nSampleFrames = varargin{1};
else
	nSampleFrames = min(N, 100);
end
jitter = floor(N/nSampleFrames);
sampleFrameNumbers = round(linspace(1, N-jitter, nSampleFrames)')...
 + round( jitter*rand(nSampleFrames,1));
dataSample = data(:,:,sampleFrameNumbers);

% [mvSamp{1, 1:nSampleFrames}] = deal(1/nSampleFrames);
% [mvSamp{2, 1:nSampleFrames}] = deal(vid(sampleFrameNumbers).cdata);
% mvAvg = gpuArray(imlincomb(mvSamp{:}, 'uint8'));


