function varargout = findPeakGaussianKernelDensityRunGpuKernel(XC, subPix)
% Mark Bucklin


% ============================================================
% MANAGE INPUT	& INITIALIZE DEFAULTS
% ============================================================
if nargin < 2
	subPix = 10;
end
kernelWidth = single(.61);
[numRows, numCols, numFrames, numChannels] = size(XC);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));
centerRow = floor(numRows/2) + 1;
centerCol = floor(numCols/2) + 1;
rowLim = int32(centerRow + fix(numRows*[-.25 .25]));
colLim = int32(centerCol + fix(numCols*[-.25 .25]));

% ESTIMATE THE PHASE-CORR NOISE-FLOOR & SHIFT XC FLOOR TO NEGATIVE RANGE
% xcFrameMin = min(min( XC, [],1), [], 2);
% XC = bsxfun( @minus, XC, xcFrameMin); % takes too long for being potentially unnecessary?? TODO

% APPLY QUICK GAUSSIAN KERNEL FILTER TO COARSE XC ARRAY
% XC = arrayfun( @gaussFilt9PixelKernel, rowSubs, colSubs, frameSubs, chanSubs);


% ============================================================
% FIND COARSE (INTEGER) SUBSCRIPTS OF PHASE-CORRELATION PEAK
% ============================================================
xcNumPixels = numRows*numCols;
[~, xcMaxFrameIdx] = max(reshape(XC, xcNumPixels, numFrames),[],1);
xcMaxFrameIdx = reshape(xcMaxFrameIdx, 1, 1, numFrames);
[xcMaxRow, xcMaxCol] = ind2sub([numRows, numCols], xcMaxFrameIdx);


% ============================================================
% GAUSSIAN KERNEL DENSITY ESTIMATION
% ============================================================
Rk = gpuArray(single(2));
kBinWidth = single(1/subPix);
peakRelativeDomainFine = gpuArray.colon(-Rk , kBinWidth, Rk);
pdN = numel(peakRelativeDomainFine);
kRowDomainFine = reshape(peakRelativeDomainFine, pdN, 1);
kColDomainFine = reshape(peakRelativeDomainFine, 1, pdN);
kRowSubsFine = bsxfun(@plus, kRowDomainFine, xcMaxRow);
kColSubsFine = bsxfun(@plus, kColDomainFine, xcMaxCol);
uOffset = 0;

% LAUNCH KERNEL-DENSITY ESTIMATE GPU-KERNEL
K = arrayfun( @kernelDensityEstimate16PixelKernel, kRowDomainFine, kColDomainFine, frameSubs, kernelWidth);

% FIND SUBPIXEL PEAK FROM INTERPOLATED CROSS-CORRELATION
[kNumRows, kNumCols, kNumFrames] = size(K);
kNumPixels = kNumRows*kNumCols;
[~, kMaxFrameIdx] = max(reshape(K, kNumPixels, kNumFrames),[],1);
kMaxFrameIdx = reshape(kMaxFrameIdx, 1, 1, kNumFrames);
[kMaxRow, kMaxCol] = ind2sub([kNumRows, kNumCols], kMaxFrameIdx);
kRowFrameStride = kNumRows.*(0:kNumFrames-1);
kColFrameStride = kNumCols.*(0:kNumFrames-1);

% COMPUTE Uxy OFFSET THAT WILL ALIGN EACH INPUT (MOVING) FRAME WITH FIXED-LOCAL-INPUT FRAME
uy = reshape(kRowSubsFine(kMaxRow(:) + kRowFrameStride(:)), 1,1,kNumFrames) - centerRow + uOffset;
ux = reshape(kColSubsFine(kMaxCol(:) + kColFrameStride(:)), 1,1,kNumFrames) - centerCol + uOffset;




% ============================================================
% OUTPUT
% ============================================================
if nargout > 1
	varargout{1} = uy;
	varargout{2} = ux;
else
	Uxy = [uy(:) ux(:)];
	varargout{1} = Uxy;
end





% ##################################################
% STENCIL-OP KDE SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function kSum = gaussFilt9PixelKernel( rowC, colC, frameC, chanC)
		% Adds neighbor pixels (simple convolution with gaussian kernel)
		
		%     0.0927    0.1191    0.0927
		%     0.1191    0.1529    0.1191
		%     0.0927    0.1191    0.0927
		
		% APPLY WINDOWING OPERATION TO VALID PIXELS AROUND CENTER
		if (rowC<rowLim(1)) || (rowC>rowLim(2)) || (colC<colLim(1)) || (colC>colLim(2))
			kSum = single(0);
		else
			
			% DEFINE KERNEL (FROM gausswin(3,sqrt(2)/2) * gausswin(3,sqrt(2)/2)')
			h0 = single(.1529);
			h1 = single(.1191);
			h2 = single(.0927);
			
			% ADJACENT-TO-NEAREST PIXEL SUBSCRIPTS
			rowU = max(rowLim(1),rowC-1);
			rowD = min(rowLim(2),rowC+1);
			colL = max(colLim(1),colC-1);
			colR = min(colLim(2),colC+1);
			
			% ADD NEIGHBOR PIXELS
			kSum = single(0) ...
				+ XC( rowU, colL, frameC, chanC)*h2 ...
				+ XC( rowU, colC, frameC, chanC)*h1 ...
				+ XC( rowU, colR, frameC, chanC)*h2 ...
				+ XC( rowC, colL, frameC, chanC)*h1 ...
				+ XC( rowC, colC, frameC, chanC)*h0 ...
				+ XC( rowC, colR, frameC, chanC)*h1 ...
				+ XC( rowD, colL, frameC, chanC)*h2 ...
				+ XC( rowD, colC, frameC, chanC)*h1 ...
				+ XC( rowD, colR, frameC, chanC)*h2;
		end
		
	end
	function kSum = kernelDensityEstimate9PixelKernel( dy, dx, t, w)
		
		
		inv2w2 = 1 / (2*w^2);
		coarseRow = xcMaxRow(t);
		coarseCol = xcMaxCol(t);
		y = dy + coarseRow;
		x = dx + coarseCol;
		
		% NEAREST SINGLE PIXEL SUBSCRIPTS
		rowC = round(y);
		colC = round(x);
		
		% ADJACENT-TO-NEAREST PIXEL SUBSCRIPTS
		rowU = rowC-1;
		rowD = rowC+1;
		colL = colC-1;
		colR = colC+1;
		
		% INITIALIZE
		kSum = single(0) ...
			+ gausskern( rowU, colL) ...
			+ gausskern( rowU, colC) ...
			+ gausskern( rowU, colR) ...
			+ gausskern( rowC, colL) ...
			+ gausskern( rowC, colC) ...
			+ gausskern( rowC, colR) ...
			+ gausskern( rowD, colL) ...
			+ gausskern( rowD, colC) ...
			+ gausskern( rowD, colR);
		
		
		function g = gausskern(yk, xk)
			f = XC(yk,xk,t);
			g = f * exp(-( inv2w2*((x-xk)^2 + (y-yk)^2) ));
		end
	end
	function kSum = kernelDensityEstimate16PixelKernel( dy, dx, t, w)
		
		inv2w2 = 1 / (2*w^2);
		coarseRow = xcMaxRow(t);
		coarseCol = xcMaxCol(t);
		y = dy + coarseRow;
		x = dx + coarseCol;
		
		% UPPER-LEFT PIXEL SUBSCRIPTS
		rowU = max(1,min(numRows, floor(y)));
		colL = max(1,min(numCols, floor(x)));
		
		% OTHER NEAREST PIXEL SUBSCRIPTS
		rowD = max(1,min(numRows, rowU+1));
		colR = max(1,min(numCols, colL+1));
		
		% NEXT OUTER NEIGHBOR TO NEAREST PIXELS SUBSCRIPTS
		rowUU = max(1,min(numRows, rowU-1));
		colLL = max(1,min(numCols, colL-1));
		rowDD = max(1,min(numRows, rowD+1));
		colRR = max(1,min(numCols, colR+1));
		
		% INITIALIZE
		kSum = single(0) ...
			+ gausskern( rowUU, colLL)...
			+ gausskern( rowU , colLL)...
			+ gausskern( rowD , colLL)...
			+ gausskern( rowDD, colLL)...
			+ gausskern( rowUU, colL )...
			+ gausskern( rowU , colL )...
			+ gausskern( rowD , colL )...
			+ gausskern( rowDD, colL )...
			+ gausskern( rowUU, colR )...
			+ gausskern( rowU , colR )...
			+ gausskern( rowD , colR )...
			+ gausskern( rowDD, colR )...
			+ gausskern( rowUU, colRR)...
			+ gausskern( rowU , colRR)...
			+ gausskern( rowD , colRR)...
			+ gausskern( rowDD, colRR);
		
		
		function g = gausskern(yk, xk)
			f = XC(yk,xk,t);
			g = f*exp(-( inv2w2*((x-xk)^2 + (y-yk)^2) ));
			
		end
	end
	function kSum = kernelDensityEstimate25PixelKernel( dy, dx, t, w)
		
		inv2w2 = 1 / (2*w^2);
		coarseRow = xcMaxRow(t);
		coarseCol = xcMaxCol(t);
		y = dy + coarseRow;% - kBinWidth;
		x = dx + coarseCol;% - kBinWidth;
		
		% NEAREST CENTRAL SUBSCRIPTS
		rowC = round(dy) + coarseRow;
		colC = round(dx) + coarseCol;
		
		% UPPER-LEFT PIXEL SUBSCRIPTS
		rowU = rowC-1;
		colL = colC-1;
		
		% LOWER-RIGHT PIXEL SUBSCRIPTS
		rowD = rowC+1;
		colR = colC+1;
		
		% NEXT OUTER NEIGHBOR TO NEAREST PIXELS SUBSCRIPTS
		rowUU = rowU-1;
		colLL = colL-1;
		rowDD = rowD+1;
		colRR = colR+1;
		
		% INITIALIZE
		kSum = single(0) ...
			+ gausskern( rowUU, colLL)...
			+ gausskern( rowU , colLL)...
			+ gausskern( rowC , colLL)...
			+ gausskern( rowD , colLL)...
			+ gausskern( rowDD, colLL)...
			+ gausskern( rowUU, colL )...
			+ gausskern( rowU , colL )...
			+ gausskern( rowC , colL )...
			+ gausskern( rowD , colL )...
			+ gausskern( rowDD, colL )...
			+ gausskern( rowUU, colC )...
			+ gausskern( rowU , colC )...
			+ gausskern( rowC , colC )...
			+ gausskern( rowD , colC )...
			+ gausskern( rowDD, colC )...
			+ gausskern( rowUU, colR )...
			+ gausskern( rowU , colR )...
			+ gausskern( rowC , colR )...
			+ gausskern( rowD , colR )...
			+ gausskern( rowDD, colR )...
			+ gausskern( rowUU, colRR)...
			+ gausskern( rowU , colRR)...
			+ gausskern( rowC , colRR)...
			+ gausskern( rowD , colRR)...
			+ gausskern( rowDD, colRR);
		
		
		
		function g = gausskern(yk, xK)
			f = XC(yk,xK,t); % LOG?? TODO:?
			g = f*exp(-( inv2w2*((x-xK)^2 + (y-yk)^2) ));
			
		end
	end
	function kSum = kernelDensityEstimateEsincKernel( dy, dx, t, w)
		
		inv2w2 = 1 / (2*w^2);
		coarseRow = xcMaxRow(t);
		coarseCol = xcMaxCol(t);
		y = dy + coarseRow;
		x = dx + coarseCol;
		
		% UPPER-LEFT PIXEL SUBSCRIPTS
		rowU = floor(y);
		colL = floor(x);
		
		% OTHER NEAREST PIXEL SUBSCRIPTS
		rowD = rowU+1;
		colR = colL+1;
		
		% NEXT OUTER NEIGHBOR TO NEAREST PIXELS SUBSCRIPTS
		rowUU = rowU-1;
		colLL = colL-1;
		rowDD = rowD+1;
		colRR = colR+1;
		
		% INITIALIZE
		kSum = single(0) ...
			+ esinckern( rowUU, colLL)...
			+ esinckern( rowU , colLL)...
			+ esinckern( rowD , colLL)...
			+ esinckern( rowDD, colLL)...
			+ esinckern( rowUU, colL )...
			+ esinckern( rowU , colL )...
			+ esinckern( rowD , colL )...
			+ esinckern( rowDD, colL )...
			+ esinckern( rowUU, colR )...
			+ esinckern( rowU , colR )...
			+ esinckern( rowD , colR )...
			+ esinckern( rowDD, colR )...
			+ esinckern( rowUU, colRR)...
			+ esinckern( rowU , colRR)...
			+ esinckern( rowD , colRR)...
			+ esinckern( rowDD, colRR);
		
		
		function g = esinckern(yk, xk)
			f = XC(yk,xk,t);
			dx2dy2 = (x-xk)^2 + (y-yk)^2 ;
			g = f ...
				* exp(-(inv2w2*dx2dy2)) ...
				* sin(pi*sqrt(dx2dy2)) ...
				/ ( pi*sqrt(dx2dy2));
			
		end
	end
	function fk = bicubicPhaseCorrPeakInterpKernel( dy, dx, t)
		
		% SUBPIXEL POINTS
		coarseRow = xcMaxRow(t);
		coarseCol = xcMaxCol(t);
		y = dy + coarseRow;
		x = dx + coarseCol;
		
		y0 = round(y);
		x0 = round(x);
		
		if (y0==y) || (x0==x)
			fk = single(0); % xc(y0,x0,t)
			
		else
			% GRID POINTS ( either  |x3|xL|x0|xR|   or |xL|x0|xR|x3| )
			yU = y0 - 1;
			yD = y0 + 1;
			y3 = y0 + 2*sign(y-y0);
			xL = x0 - 1;
			xR = x0 + 1;
			x3 = x0 + 2*sign(x-x0);
			
			% COMPUTE OVER COLUMNS TO GET VALUES AT X
			fL = catmullromcolkern(xL);
			f0 = catmullromcolkern(x0);
			fR = catmullromcolkern(xR);
			f3 = catmullromcolkern(x3);
			
			fk = single(0) ...
				+ fL * catmullkern(x-xL) ...
				+ f0 * catmullkern(x-x0) ...
				+ fR * catmullkern(x-xR) ...
				+ f3 * catmullkern(x-x3);
			
		end
		
		
		function fcol = catmullromcolkern(xk)
			fcol = single(0) ...
				+ XC(yU, xk, t) * catmullkern(y-yU) ...
				+ XC(y0, xk, t) * catmullkern(y-y0) ...
				+ XC(yD, xk, t) * catmullkern(y-yD) ...
				+ XC(y3, xk, t) * catmullkern(y-y3);
			
		end
		function g = catmullkern(s)
			s = abs(s);
			if s < 2
				s3 = s^3;
				s2 = s^2;
				g = .5*(0 ...
					+ (s<1) * (3*s3 - 5*s2 + 2) ...
					+ (s>=1) * (-s3 + 5*s2 - 8*s + 4));
			else
				g = single(0);
			end
			
		end
		
		
	end







end





