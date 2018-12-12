function Fout = gaussFiltFrameStack(F, sigma, filtSize, padType)
% GAUSSFILTFRAMESTACK
% Performs gaussian filtering on assumed gpuArray input (only slightly faster than builtin imgaussfilt, but handles 3D input)
%
% >> Fout = gaussFiltFrameStack(F, sigma, filtSize, padType)
% >> Fout = gaussFiltFrameStack(F)
% >> Fout = gaussFiltFrameStack(F, 1.25)
% >> Fout = gaussFiltFrameStack(F, 3, 7, 'symmetric')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'symmetric')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'replicate')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'partial-symmetric')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'replace')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'none')

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


[numRows, numCols, numFrames, numChans] = size(F);

Hgauss = fspecial('gaussian', filtSize, sigma);
[U,S,V] = svd(single(Hgauss));
hGauss = single(V(:,1)' * sqrt(S(1,1)));
vGauss = single(U(:,1) * sqrt(S(1,1)));

switch padType
	case 'symmetric' % 8.9ms
		% SYMMETRIC PADDING
		padSize = (filtSize -1)/2;
		fpadfilt = reshape( ...
			cat(1, flipud(F(1:padSize,:,:,:)), F, F((end-padSize+1):end,:,:,:)),...
			numRows+2*padSize, numCols*numFrames*numChans);
		Fout = reshape(...
			conv2(vGauss, hGauss, ...
			single(cat(2, fpadfilt(:, 1:padSize), fpadfilt, fliplr(fpadfilt(:, (end-padSize+1):end)))),...
			'valid'),...
			numRows, numCols, numFrames, numChans);
		
	case 'replicate' % 10.5ms
		% REPLICATE PADDING
		padSize = (filtSize -1)/2;
		topPad = F(1,:,:,:);
		botPad = F(end,:,:,:);
		fpadfilt = cat(1,...
			repmat(topPad(:)',padSize,1),...
			reshape(F, numRows, numCols*numFrames*numChans),...
			repmat(botPad(:)',padSize,1));
		leftPad = fpadfilt(:,1);
		rightPad = fpadfilt(:,end);
		Fout = reshape(...
			conv2(vGauss, hGauss, single(...
			cat(2, repmat(leftPad,1,padSize),  fpadfilt, repmat(rightPad,1,padSize)) ),...
			'valid'),...
			numRows, numCols, numFrames, numChans);
		
	case 'partial-symmetric' % 7.0ms
		% PARTIAL SYMMETRIC PADDING
		padSize = ceil(filtSize/2);
		fpadfilt = single(reshape(cat(1, flipud(F(1:padSize,:,:,:)), F, F((end-padSize+1):end,:,:,:)), numRows+2*padSize, numCols*numFrames*numChans));
		fpadfilt = conv2(vGauss, hGauss, fpadfilt,'same');
		Fout = reshape(fpadfilt((padSize+1):(end-padSize),:) , numRows, numCols, numFrames, numChans);
		
	case 'none' % 5.0ms
		% NO PADDING
		Fout = reshape(conv2(vGauss,hGauss,single(reshape(F,numRows,numCols*numFrames*numChans)),'same'), numRows, numCols, numFrames, numChans);
		
	case 'replace' % 6.9ms
		Fout = conv2(vGauss,hGauss,single(reshape(F,numRows,numCols*numFrames*numChans)),'same');
		padSize = floor(filtSize/2);
		Fout(:,1:padSize) = single(F(:, 1:padSize, 1));
		Fout(:, (end-padSize+1):end) = single(F(:,(end-padSize+1):end, end, end));
		Fout = reshape(Fout , numRows, numCols, numFrames, numChans);
		Fout(1:padSize, :, :, :) = single(F(1:padSize, :, :, :));
		Fout((end-padSize+1):end, :, :, :) = single(F((end-padSize+1):end, :, :, :));
		
end






