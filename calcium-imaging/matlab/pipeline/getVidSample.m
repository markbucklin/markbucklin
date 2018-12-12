function vidSample = getVidSample(vid,varargin)

N = numel(vid);
if nargin > 1
	nSampleFrames = varargin{1};
else
	nSampleFrames = min(numel(vid), 100);
end
sampleFrameNumbers = round(linspace(1, N, nSampleFrames));
vidSample = vid(sampleFrameNumbers);

% [mvSamp{1, 1:nSampleFrames}] = deal(1/nSampleFrames);
% [mvSamp{2, 1:nSampleFrames}] = deal(vid(sampleFrameNumbers).cdata);
% mvAvg = gpuArray(imlincomb(mvSamp{:}, 'uint8'));


