function [uy,ux] = findPeakMomentMethod(XC)
warning('findPeakMomentMethod.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

% FIND COARSE ROW/COL INDEX OF COARSE PHASE-CORRELATION PEAK (INTEGER-PRECISION MAXIMUM)
R = 4;
Csize = 1+2*R;
[numRows, numCols, numFrames, numChannels] = size(XC);
numPixels = numRows*numCols;
rowSubs = single(gpuArray.colon(1,numRows)');
colSubs = single(gpuArray.colon(1,numCols));
centerRow = floor(numRows/2)+1;
centerCol = floor(numCols/2)+1;

[~, maxFrameIdx] = max(reshape(XC, numPixels, numFrames),[],1);
maxFrameIdx = reshape(maxFrameIdx, 1, 1, numFrames);
[xcMaxRow, xcMaxCol] = ind2sub([numRows, numCols], maxFrameIdx);

% CALCULATE LINEAR ARRAY INDICES FOR PIXELS SURROUNDING INTEGER-PRECISION PEAK
peakDomain = -R:R;
frameIdx = reshape(numPixels*(0:numFrames-1),1,1,numFrames);
xcPeakSurrIdx = ...
	bsxfun(@plus, peakDomain(:),...
	bsxfun(@plus,peakDomain(:)' .* numRows,...
	bsxfun(@plus,frameIdx,...
	maxFrameIdx)));
C = reshape(XC(xcPeakSurrIdx),...
	Csize,Csize,numFrames);

% USE MOMENT METHOD TO CALCULATE CENTER POSITION OF A GAUSSIAN FIT AROUND PEAK - OR USE LEAST-SQUARES POLYNOMIAL SURFACE FIT
[spdy, spdx] = getPeakSubpixelOffset_MomentMethod(C);

uy = reshape(rowSubs(xcMaxRow), 1,1,numFrames) + spdy - centerRow;
ux = reshape(colSubs(xcMaxCol), 1,1,numFrames) + spdx - centerCol;








% ===  MOMENT-METHOD FOR ESTIMATING POSITION OF A GAUSSIAN FIT TO PEAK ===
	function [spdy, spdx] = getPeakSubpixelOffset_MomentMethod(c)
		cSum = sum(sum(c));
		d = size(c,1);
		r = floor(d/2);
		spdx = .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (1:d), c))), cSum) - r ) ...
			+ .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (-d:-1), c))), cSum) + r );
		spdy = .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (1:d)', c))), cSum) - r ) ...
			+ .5*(bsxfun(@rdivide, ...
			sum(sum( bsxfun(@times, (-d:-1)', c))), cSum) + r );
		
	end


% ===  LEAST-SQUARES FIT OF POLYNOMIAL FUNCTION TO PEAK ===
	function [spdy, spdx] = getPeakSubpixelOffset_PolyFit(c)
		% POLYNOMIAL FIT, c = Xb
		[cNumRows, cNumCols, cNumFrames] = size(c);
		d = cNumRows;
		r = floor(d/2);
		[xg,yg] = meshgrid(-r:r, -r:r);
		x=xg(:);
		y=yg(:);
		X = [ones(size(x),'like',x) , x , y , x.*y , x.^2, y.^2];
		b = X \ reshape(c, cNumRows*cNumCols, cNumFrames);
		if (cNumFrames == 1)
			spdx = (-b(3)*b(4)+2*b(6)*b(2)) / (b(4)^2-4*b(5)*b(6));
			spdy = -1 / ( b(4)^2-4*b(5)*b(6))*(b(4)*b(2)-2*b(5)*b(3));
		else
			spdx = reshape(...
				(-b(3,:).*b(4,:) + 2*b(6,:).*b(2,:))...
				./ (b(4,:).^2 - 4*b(5,:).*b(6,:)), ...
				1, 1, cNumFrames);
			spdy = reshape(...
				-1 ./ ...
				( b(4,:).^2 - 4*b(5,:).*b(6,:)) ...
				.* (b(4,:).*b(2,:) - 2*b(5,:).*b(3,:)), ...
				1, 1, cNumFrames);
		end
	end




end
