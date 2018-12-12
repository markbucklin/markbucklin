function [F, varargout] = correctMotionGpu(movingInput, fixedLocalInput, fixedGlobalInput, subPix, normFcn, antiEdgeWin, peakInterpBicubic, resampleBicubic)
warning('correctMotionGpu.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% Computes the mean frame displacement vector between unregistered frames MOVING (ND) &
% registered frame FIXED (2D) using phase correlation.
% === SUBFUNCTION RETURNS DISPLACEMENT OF FRAMES IN INPUT "MOVING" FROM INPUT "FIXED" ===
% 			function [uy, ux] = peakOfPhaseCorrelationMatrix(moving, fixed)
% Returns the row & column shift that one needs to apply to MOVING to align with FIXED
%		-> XC = Phase-Correlation Matrix
%		-> SW = Sub-Window
%		-> PS = Peak-Surround
%
%	USAGE:
%			>> F = correctMotionGpu(F);
%			>> [F, Uxy] = correctMotionGpu(F);
%			>> [F, Uxy, K] = correctMotionGpu(F);
%			>> [F, ..] = correctMotionGpu(F, fixedLocalInput);
%			>> [F, ..] = correctMotionGpu(F, fixedLocalInput, fixedGlobalInput);
%			>> [F, ..] = correctMotionGpu(F, fixedLocalInput, fixedGlobalInput, subPix, normFcn);
%			>> [F, ..] = correctMotionGpu(F, fixedLocalInput, fixedGlobalInput, subPix, normFcn, antiEdgeWin, peakInterpBicubic, resampleBicubic);
%
%
% INPUTS:
%			normFcn may be a function handle, or specify one of the internal subfunctions: 'expnorm' (default) or 'lognorm'



% ============================================================
% MANAGE INPUT	& INITIALIZE DEFAULTS
% ============================================================

% OPTIONAL INPUT ARGUMENTS TODO: kernelWidth
if nargin < 8
	resampleBicubic = [];
	if nargin < 7
		peakInterpBicubic = [];
		if nargin < 6
			antiEdgeWin = [];
			if nargin < 5
				normFcn = [];
				if nargin < 4
					subPix = [];
					if nargin < 3
						fixedGlobalInput = [];
						if nargin < 2
							fixedLocalInput = [];
						end
					end
				end
			end
		end
	end
end
fillDefaultInput()


% ENSURE DATA IS ON GPU AND SINGLE-PRECISION FLOATING POINT DATATYPE
if isa(movingInput, 'gpuArray')
	moving_fp = single(movingInput);
else
	if isa(movingInput, 'double')
		moving_fp = gpuArray(single(movingInput));
	else
		moving_fp = single(gpuArray(movingInput));
	end
end
if isa(fixedLocalInput, 'gpuArray')
	fixed_fp = single(fixedLocalInput);
else
	fixed_fp = gpuArray(single(fixedLocalInput));
end
if isa(fixedGlobalInput, 'gpuArray')
	global_fp = single(fixedGlobalInput);
else
	global_fp = gpuArray(single(fixedGlobalInput));
end

% SUBSCRIPTS % TODO: Optimize to nearest pow2 size
[numRows, numCols, numFrames] = size(moving_fp);
if nargin < 7
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
	frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
end
% subWinSize = min( size(squeeze(rowSubs),1), size(squeeze(colSubs),2));
% subWinSize = min( numRows, numCols);
subWinSize = [numRows, numCols];
centerRow = floor(numRows/2) + 1;
centerCol = floor(numCols/2) + 1;

% SUBSCRIPT & SIZE-DEPENDENT DEFAULTS
if isempty(antiEdgeWin)
	antiEdgeWin = single(hann(subWinSize(1)) * hann(subWinSize(end))');
end



% ============================================================
% CONVERT TO FLOATING-POINT, & APPLY TAPERING WINDOW FUNCTION
% ============================================================

% EXTRACT SUB-WINDOW IF SPECIFIED
if (numRows>subWinSize(1)) || (numCols~=subWinSize(end))
	moving = bsxfun(@times, moving_fp(rowSubs, colSubs, :), antiEdgeWin); % 3.8ms
	fixed = bsxfun(@times, fixed_fp(rowSubs, colSubs, :), sqrt(abs(antiEdgeWin))); % .5ms	
	
else
	moving = bsxfun(@times, moving_fp, antiEdgeWin);
	fixed = bsxfun(@times, fixed_fp, sqrt(abs(antiEdgeWin)));
	
end
if ~isempty(normFcn)
	moving = normFcn(moving);
	fixed = normFcn(fixed);
end



% ============================================================
% COMPUTE PHASE-CORRELATION IN FREQUENCY DOMAIN
% ============================================================

% TRANSFORM TO FOURIER DOMAIN (FFT)
fMoving = fft2(moving);		% 3.6 ms/call
fFixed = fft2(fixed);			% 2.7 ms/call

% MULTIPLY FIXED FRAME WITH CONJUGATE OF MOVING FRAMES
fFM = bsxfun(@times, fFixed , conj(fMoving));

% TRANSFORM BACK TO SPATIAL DOMAIN (IFT) AFTER NORMALIZATION (CROSS-CORRELATION FUNCTION -> XC)
XC = fftshift(fftshift( ifft2( fFM ./ abs(fFM + eps(fFM)), 'symmetric'), 1),2);	% 25.6 ms/call

% MITIGATE ERRORS & OFFSET PHASE-CORRELATION
nanFrames = any(any(isnan(XC),1),2);
if any(nanFrames(:))
	% TODO: Use alternate fixed frame or switch to double precision?
	if all(nanFrames(:))
		Uxy = zeros(numFrames,2);
		F = movingInput;
		warning('NAN - Frames returned from inverse fourier transform during motion correction')
		return
	else
		% TODO
		warning('NAN - Frames returned from inverse fourier transform during motion correction')
		% 		uy(nanFrames(:)) = eps(moving); % uy = zeros(1,1,numFrames, 'like',moving);
		% 		ux(nanFrames(:)) = eps(moving); % ux = zeros(1,1,numFrames, 'like',moving);
		% 		xc(:,:,nanFrames) = xc(:,:,~nanFrames(:));
	end
end

% ESTIMATE THE PHASE-CORR NOISE-FLOOR & SHIFT XC FLOOR TO NEGATIVE RANGE
[xcNumRows, xcNumCols, xcNumFrames] = size(XC);
xcFrameMin = min(min( XC, [],1), [], 2);
XC = bsxfun( @minus, XC, xcFrameMin); % NEW -> LOG1P



% ============================================================
% FIND COARSE (INTEGER) SUBSCRIPTS OF PHASE-CORRELATION PEAK
% ============================================================
xcNumPixels = xcNumRows*xcNumCols;
[~, xcMaxFrameIdx] = max(reshape(XC, xcNumPixels, xcNumFrames),[],1);
xcMaxFrameIdx = reshape(xcMaxFrameIdx, 1, 1, xcNumFrames);
[xcMaxRow, xcMaxCol] = ind2sub([xcNumRows, xcNumCols], xcMaxFrameIdx);



% ============================================================
% REFINE ESTIMATE TO SUBPIXEL ACCURACY & RE-SAMPLE/INTERPOLATE
% ============================================================
if logical(subPix) && (subPix > 1)
	
	% ============================================================
	%	INTERPOLATE OR FIT PROTOTYPE FUNCTION TO PIXELS SURROUNDING PEAK
	% ============================================================
	% TODO: add poly-fit & moment method from subpixel-peak-finding function (or MC-system)
	
	if peakInterpBicubic
		% BICUBIC SUBPIXEL PEAK INTERPOLATION
		Rk = gpuArray(single(3));
		kBinWidth = single(1/subPix);
		peakRelativeDomainFine = gpuArray.colon(-Rk + kBinWidth/2, kBinWidth, Rk - kBinWidth/2);
		pdN = numel(peakRelativeDomainFine);
		kRowDomainFine = reshape(peakRelativeDomainFine, pdN, 1);
		kColDomainFine = reshape(peakRelativeDomainFine, 1, pdN);
		kRowSubsFine = bsxfun(@plus, kRowDomainFine, xcMaxRow);
		kColSubsFine = bsxfun(@plus, kColDomainFine, xcMaxCol); % +1?
		uOffset = kBinWidth/2;
		
		% LAUNCH BICUBIC PEAKFITTING/INTERPOLATION GPU-KERNEL
		K = arrayfun( @bicubicPhaseCorrPeakInterpKernel, kRowDomainFine, kColDomainFine, frameSubs);
		
	else
		% GAUSSIAN KERNEL DENSITY ESTIMATION (more accurate during testing)
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
		kernelWidth = single(.65); % TODO:
		
		% 		K = arrayfun( @kernelDensityEstimateEsincKernel, kRowDomainFine, kColDomainFine, frameSubs, kernelWidth);
		K = arrayfun( @kernelDensityEstimate16PixelKernel, kRowDomainFine, kColDomainFine, frameSubs, kernelWidth);
		
	end
	
	% FIND SUBPIXEL PEAK FROM INTERPOLATED CROSS-CORRELATION
	[kNumRows, kNumCols, kNumFrames] = size(K);
	kNumPixels = kNumRows*kNumCols;
	[~, kMaxFrameIdx] = max(reshape(K, kNumPixels, kNumFrames),[],1);
	kMaxFrameIdx = reshape(kMaxFrameIdx, 1, 1, kNumFrames);
	[kMaxRow, kMaxCol] = ind2sub([kNumRows, kNumCols], kMaxFrameIdx);
	kRowFrameStride = kNumRows*(0:kNumFrames-1);
	kColFrameStride = kNumCols*(0:kNumFrames-1);
	
	% COMPUTE Uxy OFFSET THAT WILL ALIGN EACH INPUT (MOVING) FRAME WITH FIXED-LOCAL-INPUT FRAME
	uy = reshape(kRowSubsFine(kMaxRow(:) + kRowFrameStride(:)), 1,1,kNumFrames) - centerRow + uOffset;
	ux = reshape(kColSubsFine(kMaxCol(:) + kColFrameStride(:)), 1,1,kNumFrames) - centerCol + uOffset;%NEW
	
	
	
	% ============================================================
	% RESAMPLE IMAGES AT USING RESULTANT FRAME SHIFT (Uxy)
	% ============================================================
	if resampleBicubic
		% RESAMPLE/INTERPOLATE IMAGE USING BICUBIC INTERPOLATION ON GPU
		uy = uy + .001111*sign(randn(size(uy)));
		ux = ux + .001111*sign(randn(size(ux)));
		Ffp = arrayfun(@bicubicImageResampleKernel, rowSubs, colSubs, frameSubs, uy, ux);
		
	else
		% RESAMPLE IMAGE USING GAUSSIAN-BLUR KERNEL GENERATED DURING PHASE-CORR PROCEDURE ABOVE (not working yet, todo?)
		kCenter = Rk*subPix + 1;
		kSampleSpan = 2;
		kAlignedSubs = (kCenter-kSampleSpan*subPix):subPix:(kCenter+kSampleSpan*subPix);
		kResampleKernel = K(kAlignedSubs, kAlignedSubs, :);%K(1:subPix:end,1:subPix:end,:);
		kResampleKernelSum = sum(sum(kResampleKernel,1),2);
		kResampleKernel = bsxfun(@rdivide, kResampleKernel, kResampleKernelSum);
		uyCoarse = reshape(rowSubs(xcMaxRow), 1,1,numFrames) - centerRow ;
		uxCoarse = reshape(colSubs(xcMaxCol), 1,1,numFrames) - centerCol ;
		Ffp = arrayfun(@arbitraryResampleKernel, rowSubs, colSubs, frameSubs, uyCoarse, uxCoarse);
		
	end
	
else
	% SKIP SUB-PIXEL CALCULATION
	uy = reshape(rowSubs(xcMaxRow), 1,1,numFrames) - centerRow - 1;
	ux = reshape(colSubs(xcMaxCol), 1,1,numFrames) - centerCol - 1;
	Ffp = arrayfun(@coarseResampleKernel, rowSubs, colSubs, frameSubs, uy, ux);
	
end



% ============================================================
% OUTPUT
% ============================================================
F = cast(Ffp, 'like', movingInput);
Uxy = [uy(:) ux(:)];
if nargout > 1
	varargout{1} = Uxy;
	if nargout > 2
		varargout{2} = K;
	end
end


% ##################################################
% SUBFUNCTIONS
% ##################################################
	function fillDefaultInput()
		if isempty(subPix)
			subPix = 10;
		end
		if isempty(normFcn)
			normFcn = @expnorm;
		elseif ischar(normFcn)
			normFcn = str2func(normFcn);
			% 	normFcn = max(abs(movingInput(:))) > 2*mean(abs(movingInput(:)));
		end
		if isempty(fixedGlobalInput) %TODO
			fixedGlobalInput = mean(movingInput,3);
		end
		if isempty(fixedLocalInput) %TODO
			fixedLocalInput = movingInput(:,:,1,:);
		end
		if isempty(peakInterpBicubic)
			peakInterpBicubic = false;
		end
		if isempty(resampleBicubic)
			resampleBicubic = true; % todo: provide all options: gaussianBlurKernel, Bicubic, Bilinear, NN, other?
		end
	end
	function f = expnorm(f)
		fmax = max(max(max(f,[],1),[],2),[],3);
		fmin = min(min(min(f,[],1),[],2),[],3);
		expInvScale = cast(1/(1-exp(-1)), 'like', f);
		expInvShift = cast(exp(-1), 'like', f);
		frange = fmax - fmin;
		f = bsxfun(@minus, f, fmin);
		f = expInvScale * (exp( - ...
			bsxfun(@rdivide,...
			bsxfun(@minus, frange, f), ...
			frange)) ...
			- expInvShift);
		
	end
	function f = lognorm(f)
		fmax = max(max(max(f,[],1),[],2),[],3);
		fmin = min(min(min(f,[],1),[],2),[],3);
		frange = fmax - fmin;
		f = bsxfun(@minus, f, fmin);
		frange = fmax - fmin;
		f = bsxfun(@minus, f, fmin);
		f = log( ...
			bsxfun(@rdivide,...
			frange, ...
			abs(bsxfun(@minus, frange, f))));
		
	end

% ====================================================
% VISUALIZATION 
% ====================================================
	function showPhaseCorrPeakSurf()
		h.fig = figure;
		for m=1:xcNumFrames
			subplot(4,4,m)
			hSurf(m) = surf(squeeze(kColSubsFine(1,:,m)), squeeze(kRowSubsFine(:,1,m)), K(:,:,m));
			hAx(m) = hSurf(m).Parent;
		end
		set(hSurf, 'EdgeAlpha',.05, 'SpecularStrength', .5)
		set(hAx, 'Visible','off', 'Clipping','off')
		linkprop(hAx,{'CameraPosition','CameraUpVector'});
		% rotate3d on
		h.surf = hSurf;
		h.ax = hAx;
		assignin('base','h',h);
	end

% ====================================================
% STENCIL-OP KDE SUB-FUNCTION -> RUNS ON GPU
% ====================================================
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
			+ gausskern( rowU, colL)...
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
	function fk = bicubicImageResampleKernel( rowC, colC, t, dy, dx)
		
		
		
		y = single(rowC) - dy;% + sign(randn)*.001111;
		x = single(colC) - dx;% + sign(randn)*.001111;
		
		y0 = round(y);
		x0 = round(x);
		sx = x - x0;
		sy = y - y0;
		
		if (abs(sx)+abs(sy)) > eps
			fk = single(resamplePixel(0,0));
			
		else
			% GRID POINTS ( either  |x3|xL|x0|xR|   or |xL|x0|xR|x3| )
			dy0 = 0;
			dyU = -1;
			dyD = 1;
			dy3 = 2*sign(sy);
			dx0 = 0;
			dxL = -1;
			dxR = 1;
			dx3 = 2*sign(sx);
			
			% COMPUTE OVER COLUMNS TO GET VALUES AT X
			fL = catmullromcolkern(dxL);
			f0 = catmullromcolkern(dx0);
			fR = catmullromcolkern(dxR);
			f3 = catmullromcolkern(dx3);
			
			fk = single(0) ...
				+ fL * catmullkern(sx-dxL) ...
				+ f0 * catmullkern(sx-dx0) ...
				+ fR * catmullkern(sx-dxR) ...
				+ f3 * catmullkern(sx-dx3);
			
		end
		
		% SUBFUNCTIONS ================
		function f = resamplePixel(uyk,uxk)
			% SELECT PIXEL WITHIN BOARDERS, OR REPLACE WITH GLOBAL INPUT (BACKGROUND)
			yk = y0 + uyk;
			xk = x0 + uxk;
			frow = max(1, min(numRows, yk));
			fcol = max(1, min(numCols, xk));
			
			if (frow~=yk) || (fcol~=xk)
				f = single(global_fp(max(1,min(numRows, y0)), max(1,min(numCols,x0))));
				
			else
				f = moving_fp(frow,fcol,t);
				
			end
			
		end
		function fcol = catmullromcolkern(dxk)
			fcol = single(0) ...
				+ resamplePixel(dyU, dxk) * catmullkern(sy-dyU) ...
				+ resamplePixel(dy0 , dxk) * catmullkern(sy-dy0) ...
				+ resamplePixel(dyD, dxk) * catmullkern(sy-dyD) ...
				+ resamplePixel(dy3, dxk) * catmullkern(sy-dy3);
			
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
	function fResamp = arbitraryResampleKernel( y, x, t, dy, dx)
		
		ck = kSampleSpan + 1;
		cy = y - dy;
		cx = x - dx;
		
		% RESAMPLE USING GAUSSIAN BLUR KERNEL GENERATED PREVIOUSLY
		fResamp = single(0) ...
			+ resamplePixel(-2,-2) ...
			+ resamplePixel(-1,-2) ...
			+ resamplePixel( 0,-2) ...
			+ resamplePixel( 1,-2) ...
			+ resamplePixel( 2,-2) ...
			+ resamplePixel(-2,-1) ...
			+ resamplePixel(-1,-1) ...
			+ resamplePixel( 0,-1) ...
			+ resamplePixel( 1,-1) ...
			+ resamplePixel( 2,-1) ...
			+ resamplePixel(-2, 0) ...
			+ resamplePixel(-1, 0) ...
			+ resamplePixel( 0, 0) ...
			+ resamplePixel( 1, 0) ...
			+ resamplePixel( 2, 0) ...
			+ resamplePixel(-2, 1) ...
			+ resamplePixel(-1, 1) ...
			+ resamplePixel( 0, 1) ...
			+ resamplePixel( 1, 1) ...
			+ resamplePixel( 2, 1) ...
			+ resamplePixel(-2, 2) ...
			+ resamplePixel(-1, 2) ...
			+ resamplePixel( 0, 2) ...
			+ resamplePixel( 1, 2) ...
			+ resamplePixel( 2, 2);
		
		function g = resamplePixel(yk,xk)
			krow = ck + yk;
			kcol = ck + xk;
			frow = max(1, min(numRows, cy + yk));
			fcol = max(1, min(numCols, cx + xk));
			g = kResampleKernel(krow,kcol,t) * moving_fp(frow,fcol,t);
			
		end
		
	end
	function fResamp = coarseResampleKernel( y, x, t, dy, dx)
		
		% NEAREST SINGLE PIXEL SUBSCRIPTS
		rowC = min(numRows, max(1, y - dy));
		colC = min(numCols, max(1, x - dx));
		
		% DISPLACED RESAMPLE
		fResamp = moving_fp( rowC, colC, t);
		
	end


% FROM Scicadelic.MotionCorrector
% ===  BENCHMARKING FUNCTION TO CHOOSE WHICH FUNCTION TO PERFORM ===
	function bench = comparePeakFitFcn(c, fastFcn, preciseFcn)
		
		fast.fcn = fastFcn;
		precise.fcn = preciseFcn;
		
		fast.t = gputimeit(@() fast.fcn(c), 2);
		precise.t = gputimeit(@() precise.fcn(c), 2);
		
		fast.dydx = fast.fcn(c);
		precise.dydx = precise.fcn(c);
		
		bench.fast = fast;
		bench.precise = precise;
		bench.sse = sum((bench.precise.dydx(:) - bench.fast.dydx(:)).^2);
		bench.dt = (bench.precise.t - bench.fast.t) / bench.fast.t;
		
	end

% % CALCULATE LINEAR ARRAY INDICES FOR PIXELS SURROUNDING INTEGER-PRECISION PEAK
% peakDomain = -R:R;
% xcFrameIdx = reshape(xcNumPixels*(0:xcNumFrames-1),1,1,xcNumFrames);
% xcPeakSurrIdx = ...
% 	bsxfun(@plus, peakDomain(:),...
% 	bsxfun(@plus,peakDomain(:)' .* xcNumRows,...
% 	bsxfun(@plus,xcFrameIdx,...
% 	xcMaxFrameIdx)));
% C = reshape(xc(xcPeakSurrIdx),...
% 	Csize,Csize,xcNumFrames);
% % CHOOSE A METHOD FOR FITTING A SURFACE TO PIXELS SURROUNDING PEAK
% if isempty(obj.PeakFitFcn)
% 	bench = comparePeakFitFcn(C, ...
% 		@getPeakSubpixelOffset_MomentMethod, ...
% 		@getPeakSubpixelOffset_PolyFit);
% 	if bench.precise.t < (2*bench.fast.t)
% 		obj.PeakFitFcn = bench.precise.fcn;
% 	else
% 		obj.PeakFitFcn = bench.fast.fcn;
% 	end
% 	%TODO: save bench
% end
%
% % USE MOMENT METHOD TO CALCULATE CENTER POSITION OF A GAUSSIAN FIT AROUND PEAK - OR USE LEAST-SQUARES POLYNOMIAL SURFACE FIT
% [spdy, spdx] = obj.PeakFitFcn(C);
% % 						[spdy, spdx] = getPeakSubpixelOffset_MomentMethod(C);		% 10.5 ms/call
% uy = reshape(swRowSubs(xcMaxRow), 1,1,xcNumFrames) + spdy - centerRow - 1;
% ux = reshape(swColSubs(xcMaxCol), 1,1,xcNumFrames) + spdx - centerCol - 1;

% ESTIMATE THE PHASE-CORR NOISE-FLOOR & SHIFT XC FLOOR TO NEGATIVE RANGE
% 				[xcNumRows, xcNumCols, xcNumFrames] = size(xc);
% 				xcFrameMin = min(min( xc, [],1), [], 2);
% 				xc = log1p(bsxfun( @minus, xc, xcFrameMin)); % NEW -> LOG1P
%
%
% 				% ============================================================
% 				% FIND COARSE (INTEGER) SUBSCRIPTS OF PHASE-CORRELATION PEAK (INTEGER-PRECISION MAXIMUM)
% 				% ============================================================
% 				[xcNumRows, xcNumCols, xcNumFrames] = size(xc);
% 				R = obj.PeakSurroundRadius;
% 				Csize = 1+2*R;
% 				xcNumPixels = xcNumRows*xcNumCols;
% 				[~, xcMaxFrameIdx] = max(reshape(xc, xcNumPixels, xcNumFrames),[],1);
% 				xcMaxFrameIdx = reshape(xcMaxFrameIdx, 1, 1, xcNumFrames);
% 				[xcMaxRow, xcMaxCol] = ind2sub([xcNumRows, xcNumCols], xcMaxFrameIdx);

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
		spdy = real(spdy);
		spdx = real(spdx);
	end





end





