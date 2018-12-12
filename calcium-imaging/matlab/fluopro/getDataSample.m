function dataSample = getDataSample(data,varargin)

% CONSTANT PARAMETERS
minSampleNumber = 100;

% DETERMINE NUMBER OF FRAMES TO SAMPLE
if isnumeric(data)
   N = size(data,ndims(data));
elseif isstruct(data)
   N = numel(data);
else
   warning('Check input')
end
if nargin > 1
   nSampleFrames = ceil(varargin{1});
else
   nSampleFrames = min(N, minSampleNumber);
end
jitter = floor(N/nSampleFrames);
sampleFrameNumbers = round(linspace(1, N-jitter, nSampleFrames)')...
   + round( jitter*rand(nSampleFrames,1));
if isnumeric(data)
   switch ndims(data)
	  case 3
		 dataSample = data(:,:,sampleFrameNumbers);
	  case 4
		 dataSample = data(:,:,:,sampleFrameNumbers);
	  otherwise
		 dataSample = data;
   end
elseif isstruct(data)
   dataSample = data(sampleFrameNumbers);
end



