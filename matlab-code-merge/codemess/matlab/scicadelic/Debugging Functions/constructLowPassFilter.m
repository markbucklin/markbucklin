function filterFcn = constructLowPassFilter(imSize, sigma, hSize)

try
	gdev = gpuDevice;
	useGpu = ~isempty(gdev);
catch
	useGpu = false;
end

% DEFINE FILTER PROPERTIES
maxFilterSize = min(imSize);
maxSigma = floor((maxFilterSize -1)/4);
if nargin < 2
	sigma = floor(1/8 * maxSigma);
end
if numel(imSize) == 1
	imSize = [imSize imSize];
end
if nargin < 3
	hSize = 2*ceil(2 * sigma)+1;
end

% CALCULATE COEFFICIENTS
H = rot90(fspecial('gaussian', hSize, sigma),2);
[sepcoeff, hcol, hrow] = isfilterseparable(H);
hCenter = floor((size(H)+1)/2);
hPad = hSize - hCenter;

% CREATE SUBREFERENCE STRUCTURE FOR DEPADDING
imCenter = floor((imSize+1)/2) + hPad;
if useGpu
	subsCenteredOn = @(csub,n) gpuArray.colon(floor(csub-n/2+1),floor(csub+n/2))';%NEW
else
	subsCenteredOn = @(csub,n) (floor(csub-n/2+1):floor(csub+n/2))';
end
subrefDePad.type = '()';
subrefDePad.subs = {...
	subsCenteredOn(imCenter(2),imSize(2)),...
	subsCenteredOn(imCenter(1),imSize(1))};

% CONSTRUCT FILTER FUNCTION ->  CONV2 - GPU
if useGpu
	if sepcoeff
		ghrow = gpuArray(hrow);
		ghcol = gpuArray(hcol);
		gfcn = @(F)...
			subsref(...
			conv2(ghrow, ghcol, ...
			padarray(F, hPad, 'replicate', 'both'),'same'),...
			subrefDePad); % gputimeit -> .0040
	else
		gH = gpuArray(H);
		gfcn = @(F)...
			subsref(...
			conv2(padarray(F, hPad, 'replicate', 'both'), gH, 'same'),...
			subrefDePad);
	end
	filterFcn = gfcn;
else
	if sepcoeff
		cfcn = @(F)...
			subsref(...
			conv2(hrow, hcol, ...
			padarray(F, hPad, 'replicate', 'both'),'same'),...
			subrefDePad); % timeit -> .0480
	else
		cfcn = @(F)...
			subsref(...
			conv2(padarray(F, hPad, 'replicate', 'both'), H, 'same'),...
			subrefDePad); % timeit -> .720
	end
	filterFcn = cfcn;
end

% CLEAN ANONYMOUS FUNCTION WORKSPACE
% 			filterFcn = str2func(func2str(filterFcn)); % Recently uncommented (was commented out because imcompatible with codegen)


end