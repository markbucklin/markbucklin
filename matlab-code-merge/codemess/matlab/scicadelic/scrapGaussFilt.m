function Fgaussfilt = scrapGaussFilt(F, sigma, filtSize, padType)

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

Hgauss = fspecial('gaussian', filtSize, sigma);
[U,S,V] = svd(single(Hgauss));
hGauss = single(V(:,1)' * sqrt(S(1,1)));
vGauss = single(U(:,1) * sqrt(S(1,1)));

if ismatrix(F)
	Fgaussfilt = conv2(vGauss,hGauss,single(F));
else
	switch padType
		case 'symmetric' % 8.9ms
			% SYMMETRIC PADDING
			padSize = (filtSize -1)/2;
			fpadfilt = reshape( ...
				cat(1, flipud(F(1:padSize,:,:)), F, F((end-padSize+1):end,:,:)),...
				numRows+2*padSize, numCols*numFrames);
			Fgaussfilt = reshape(...
				conv2(vGauss, hGauss, ...
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
			Fgaussfilt = reshape(...
				conv2(vGauss, hGauss, single(...
				cat(2, repmat(leftPad,1,padSize),  fpadfilt, repmat(rightPad,1,padSize)) ),...
				'valid'),...
				numRows, numCols, numFrames);
			
		case 'partial-symmetric' % 7.0ms
			% PARTIAL SYMMETRIC PADDING
			padSize = ceil(filtSize/2);
			fpadfilt = single(reshape(cat(1, flipud(F(1:padSize,:,:)), F, F((end-padSize+1):end,:,:)), numRows+2*padSize, numCols*numFrames));
			fpadfilt = conv2(vGauss, hGauss, fpadfilt,'same');
			Fgaussfilt = reshape(fpadfilt((padSize+1):(end-padSize),:) , numRows, numCols, numFrames);
			
		case 'none' % 5.0ms
			% NO PADDING
			Fgaussfilt = reshape(conv2(vGauss,hGauss,single(reshape(F,numRows,numCols*numFrames)),'same'), numRows, numCols, numFrames);
		
		case 'replace' % 6.9ms
			Fgaussfilt = conv2(vGauss,hGauss,single(reshape(F,numRows,numCols*numFrames)),'same');
			padSize = floor(filtSize/2);
			Fgaussfilt(:,1:padSize) = single(F(:, 1:padSize, 1));
			Fgaussfilt(:, (end-padSize+1):end) = single(F(:,(end-padSize+1):end, end));
			Fgaussfilt = reshape(Fgaussfilt , numRows, numCols, numFrames);
			Fgaussfilt(1:padSize, :, :) = single(F(1:padSize, :, :));
			Fgaussfilt((end-padSize+1):end, :, :) = single(F((end-padSize+1):end, :, :));
			
	end
end