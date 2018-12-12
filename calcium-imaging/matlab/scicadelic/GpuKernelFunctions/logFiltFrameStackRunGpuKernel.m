function Fout = logFiltFrameStackRunGpuKernel(F, sigma, filtSize, padType)
% LOGFILTFRAMESTACK
% Performs Laplacian-Of-Gaussian filtering on assumed gpuArray input (only slightly faster than builtin imgaussfilt, but handles 3D input)
%
% >> Fout = logFiltFrameStack(F, sigma, filtSize, padType)
% >> Fout = logFiltFrameStack(F)
% >> Fout = logFiltFrameStack(F, 1.25)
% >> Fout = logFiltFrameStack(F, 3, 7, 'symmetric')
% >> Fout = logFiltFrameStack(F, 1.5, [], 'symmetric')
% >> Fout = logFiltFrameStack(F, 1.5, [], 'replicate')
% >> Fout = logFiltFrameStack(F, 1.5, [], 'partial-symmetric')
% >> Fout = logFiltFrameStack(F, 1.5, [], 'replace')
% >> Fout = logFiltFrameStack(F, 1.5, [], 'none')



% TODO: NOT YET IMPLEMENTED


if nargin < 4
	padType = [];
	if nargin < 3
		filtSize = []; % 2*ceil(2*SIGMA)+1
		if nargin < 2
			sigma = [];
		end
	end
end
if isempty(sigma)
	sigma = 1.25;
end
if isempty(filtSize)
	filtSize = 2*ceil(2*sigma) + 1;
end
if isempty(padType)
	padType = 'symmetric';
end
% TIMING VS. FILTER SIZE: for 1024*1024*16 frames -> gputimeit returns .004 + .0001*filtSize


[numRows, numCols, numFrames] = size(F);

Hlog = fspecial('log', filtSize, sigma);
[U,S,V] = svd(single(Hlog));
hLog = single(V(:,1)' * sqrt(S(1,1)));
vLog = single(U(:,1) * sqrt(S(1,1)));

switch padType
	case 'symmetric' % 8.9ms
		% SYMMETRIC PADDING
		padSize = (filtSize -1)/2;
		fpadfilt = reshape( ...
			cat(1, flipud(F(1:padSize,:,:)), F, F((end-padSize+1):end,:,:)),...
			numRows+2*padSize, numCols*numFrames);
		Fout = reshape(...
			conv2(vLog, hLog, ...
			single(cat(2, fpadfilt(:, 1:padSize), fpadfilt, fliplr(fpadfilt(:, (end-padSize+1):end)))),...
			'valid'),...
			numRows, numCols, numFrames);
		
	case 'replicate' % 10.5ms
		% REPLICATE PADDING
		padSize = (filtSize -1)/2;
		topPad = F(1,:,:);
		botPad = F(end,:,:);
		fpadfilt = cat(1,...
			repmat(topPad(:)',padSize,1),...
			reshape(F, numRows, numCols*numFrames),...
			repmat(botPad(:)',padSize,1));
		leftPad = fpadfilt(:,1);
		rightPad = fpadfilt(:,end);
		Fout = reshape(...
			conv2(vLog, hLog, single(...
			cat(2, repmat(leftPad,1,padSize),  fpadfilt, repmat(rightPad,1,padSize)) ),...
			'valid'),...
			numRows, numCols, numFrames);
		
	case 'partial-symmetric' % 7.0ms
		% PARTIAL SYMMETRIC PADDING
		padSize = ceil(filtSize/2);
		fpadfilt = single(reshape(cat(1, flipud(F(1:padSize,:,:)), F, F((end-padSize+1):end,:,:)), numRows+2*padSize, numCols*numFrames));
		fpadfilt = conv2(vLog, hLog, fpadfilt,'same');
		Fout = reshape(fpadfilt((padSize+1):(end-padSize),:) , numRows, numCols, numFrames);
		
	case 'none' % 5.0ms
		% NO PADDING
		Fout = reshape(conv2(vLog,hLog,single(reshape(F,numRows,numCols*numFrames)),'same'), numRows, numCols, numFrames);
		
	case 'replace' % 6.9ms
		Fout = conv2(vLog,hLog,single(reshape(F,numRows,numCols*numFrames)),'same');
		padSize = floor(filtSize/2);
		Fout(:,1:padSize) = single(F(:, 1:padSize, 1));
		Fout(:, (end-padSize+1):end) = single(F(:,(end-padSize+1):end, end));
		Fout = reshape(Fout , numRows, numCols, numFrames);
		Fout(1:padSize, :, :) = single(F(1:padSize, :, :));
		Fout((end-padSize+1):end, :, :) = single(F((end-padSize+1):end, :, :));
		
end






