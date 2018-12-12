function [F, Uxy] = correctMotionGpu(movingInput, fixedLocalInput, fixedGlobalInput, subPix, useLog, antiEdgeWin)
% Computes the mean frame displacement vector between unregistered frames MOVING (ND) &
% registered frame FIXED (2D) using phase correlation.
% === SUBFUNCTION RETURNS DISPLACEMENT OF FRAMES IN INPUT "MOVING" FROM INPUT "FIXED" ===
% 			function [uy, ux] = peakOfPhaseCorrelationMatrix(moving, fixed)
% Returns the row & column shift that one needs to apply to MOVING to align with FIXED
%		-> XC = Phase-Correlation Matrix
%		-> SW = Sub-Window
%		-> PS = Peak-Surround



% ============================================================
% MANAGE INPUT	& INITIALIZE DEFAULTS
% ============================================================

% OPTIONAL INPUT ARGUMENTS TODO: kernelWidth
if nargin < 6
	antiEdgeWin = [];
	if nargin < 5
	useLog = [];
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
if isempty(subPix)
	subPix = 10;
end
if isempty(useLog)
	useLog = false;
% 	useLog = max(abs(movingInput(:))) > 2*mean(abs(movingInput(:)));
end
if isempty(fixedGlobalInput) %TODO
	fixedGlobalInput = mean(movingInput,3);
end
if isempty(fixedLocalInput) %TODO
	fixedLocalInput = movingInput(:,:,1);
end

% ENSURE DATA IS ON GPU AND SINGLE-PRECISION FLOATING POINT DATATYPE
if isa(movingInput, 'gpuArray')
	moving_fp = single(movingInput);
else
	moving_fp = gpuArray(single(movingInput));
end
if isa(fixedLocalInput, 'gpuArray')
	fixed_fp = single(fixedLocalInput);
else
	fixed_fp = gpuArray(single(fixedLocalInput));
end

% SUBSCRIPTS % TODO: Optimize to nearest pow2 size
[numRows, numCols, numFrames] = size(moving_fp);
if nargin < 7
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
	frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
end
% subWinSize = min( size(squeeze(rowSubs),1), size(squeeze(colSubs),2));
subWinSize = min( numRows, numCols);
centerRow = floor(numRows/2) + 1;
centerCol = floor(numCols/2) + 1;

% SUBSCRIPT & SIZE-DEPENDENT DEFAULTS
if isempty(antiEdgeWin)
	antiEdgeWin = single(hann(subWinSize) * hann(subWinSize)');
end



% ============================================================
% CONVERT TO FLOATING-POINT, & APPLY TAPERING WINDOW FUNCTION
% ============================================================

% EXTRACT SUB-WINDOW IF SPECIFIED
if (numRows>subWinSize) || (numCols~=subWinSize)
	moving = bsxfun(@times, moving_fp(rowSubs, colSubs, :), antiEdgeWin); % 3.8ms
	fixed = bsxfun(@times, fixed_fp(rowSubs, colSubs, :), antiEdgeWin); % .5ms
	
else
	moving = bsxfun(@times, moving_fp, antiEdgeWin);
	fixed = bsxfun(@times, fixed_fp, antiEdgeWin);
	
end
if useLog
	moving = log1p(moving);
	fixed = log1p(fixed);
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
xc = fftshift(fftshift( ifft2( fFM ./ abs(fFM + eps(fFM)), 'symmetric'), 1),2);	% 25.6 ms/call




% ============================================================
% MITIGATE ERRORS & OFFSET PHASE-CORRELATION
% ============================================================
nanFrames = any(any(isnan(xc),1),2);
if any(nanFrames)
	% TODO: Use alternate fixed frame or switch to double precision?
	uy(nanFrames(:)) = eps(moving); % 					uy = zeros(1,1,numFrames, 'like',moving);
	ux(nanFrames(:)) = eps(moving); % 					ux = zeros(1,1,numFrames, 'like',moving);
	xc = xc(:,:,~nanFrames(:));
	
end
[xcNumRows, xcNumCols, xcNumFrames] = size(xc);

% ESTIMATE THE PHASE-CORR NOISE-FLOOR & SHIFT XC FLOOR TO NEGATIVE RANGE
xcFrameMin = min(min( xc, [],1), [], 2);
xc = log1p(bsxfun( @minus, xc, xcFrameMin)); % NEW -> LOG1P


% ============================================================
% FIND COARSE (INTEGER) SUBSCRIPTS OF PHASE-CORRELATION PEAK
% ============================================================
xcNumPixels = xcNumRows*xcNumCols;
[~, xcMaxFrameIdx] = max(reshape(xc, xcNumPixels, xcNumFrames),[],1);
xcMaxFrameIdx = reshape(xcMaxFrameIdx, 1, 1, xcNumFrames);
[xcMaxRow, xcMaxCol] = ind2sub([xcNumRows, xcNumCols], xcMaxFrameIdx);




% ============================================================
% REFINE ESTIMATE TO SUBPIXEL ACCURACY:
% ============================================================
if logical(subPix) && (subPix > 1)
	%	INTERPOLATE OR FIT PROTOTYPE FUNCTION TO PIXELS SURROUNDING PEAK
	Rk = gpuArray(single(2));
	kBinWidth = single(1/subPix);
	peakRelativeDomainFine = gpuArray.colon(-Rk, kBinWidth, Rk);
	kRowDomainFine = reshape(peakRelativeDomainFine, 2*Rk*subPix+1, 1);
	kColDomainFine = reshape(peakRelativeDomainFine, 1, 2*Rk*subPix+1);
	kRowSubsFine = bsxfun(@plus, reshape(peakRelativeDomainFine, 2*Rk*subPix+1, 1), xcMaxRow);
	kColSubsFine = bsxfun(@plus, reshape(peakRelativeDomainFine, 1, 2*Rk*subPix+1), xcMaxCol); % +1?
	
	
	
	% ============================================================
	% LAUNCH KERNEL-DENSITY ESTIMATE GPU-KERNEL
	% ============================================================
	kernelWidth = single(.60); % TODO: ESTIMATE KERNEL-WIDTH (SIGMA) PROPORTIONAL TO INITIAL INTERFRAME-VELOCITY
	K = arrayfun( @kernelDensityEstimate25PixelKernel, kRowDomainFine, kColDomainFine, frameSubs, kernelWidth);
	% 	K = arrayfun( @kernelDensityEstimate16PixelKernel, kRowSubsFine, kColSubsFine, frameSubs, kernelWidth);
% 	kRowSum = sum(K,2);
% 	kColSum = sum(K,1);
% 	[~,kMaxRow] = max(kRowSum,[],1);
% 	[~,kMaxCol] = max(kColSum,[],2);
	
	[kNumRows, kNumCols, kNumFrames] = size(K);
	kNumPixels = kNumRows*kNumCols;
		[~, kMaxFrameIdx] = max(reshape(K, kNumPixels, kNumFrames),[],1);
		kMaxFrameIdx = reshape(kMaxFrameIdx, 1, 1, kNumFrames);
		[kMaxRow, kMaxCol] = ind2sub([kNumRows, kNumCols], kMaxFrameIdx);
	kRowFrameStride = kNumRows*(0:kNumFrames-1);
	kColFrameStride = kNumCols*(0:kNumFrames-1);
	uy = reshape(kRowSubsFine(kMaxRow(:) + kRowFrameStride(:)), 1,1,kNumFrames) - centerRow ;
	ux = reshape(kColSubsFine(kMaxCol(:) + kColFrameStride(:)), 1,1,kNumFrames) - centerCol ;

	% ============================================================
	% RESAMPLE IMAGES AT USING FRAME SHIFT
	% ============================================================
	% 	kResampleKernel = K(1:subPix:end, 1:subPix:end, :);
	kResampleKernel = K(1:subPix:end, 1:subPix:end, :);
	kResampleKernelSum = sum(sum(kResampleKernel,1),2);
	kResampleKernel = bsxfun(@rdivide, kResampleKernel, kResampleKernelSum);
	uyCoarse = reshape(rowSubs(xcMaxRow), 1,1,numFrames) - centerRow ;
	uxCoarse = reshape(colSubs(xcMaxCol), 1,1,numFrames) - centerCol ;
	Ffp = arrayfun(@arbitraryResampleKernel, rowSubs, colSubs, frameSubs, uyCoarse, uxCoarse);
	
else
	% SKIP SUB-PIXEL CALCULATION
	uy = reshape(rowSubs(xcMaxRow), 1,1,numFrames) - centerRow - 1;
	ux = reshape(colSubs(xcMaxCol), 1,1,numFrames) - centerCol - 1;
	Ffp = arrayfun(@coarseResampleKernel, rowSubs, colSubs, frameSubs, uy, ux);
	
end


% figure
% for m=1:xcNumFrames
% 	subplot(4,4,m)
% 	hSurf(m) = surf(squeeze(kColSubsFine(1,:,m)), squeeze(kRowSubsFine(:,1,m)), K(:,:,m));
% 	hAx(m) = hSurf(m).Parent;
% end
% set(hSurf, 'EdgeAlpha',.05, 'SpecularStrength', .5)
% set(hAx, 'Visible','off', 'Clipping','off')
% linkprop(hAx,{'CameraPosition','CameraUpVector'});
% % rotate3d on
% h.surf = hSurf;
% h.ax = hAx;
% assignin('base','h',h);




% Nx2 OUTPUT
F = cast(Ffp, 'like', movingInput);
Uxy = [uy(:) ux(:)];





% ##################################################
% STENCIL-OP KDE SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function kSum = kernelDensityEstimate9PixelKernel( y, x, t, w)
		
		inv2w2 = 1 / (2*w^2);
		
		% NEAREST SINGLE PIXEL SUBSCRIPTS
		rowC = max(1, min(numRows, round(y)));
		colC = max(1, min(numCols, round(x)));
		
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
		
		
		function g = gausskern(y0, x0)
			f = xc(y0,x0,t);
			g = f * exp(-( inv2w2*((x-x0)^2 + (y-y0)^2) ));
		end
	end
	function kSum = kernelDensityEstimate25PixelKernel( y, x, t, w)
		
		inv2w2 = 1 / (2*w^2);
		coarseRow = xcMaxRow(t);
		coarseCol = xcMaxCol(t);
		yk = y + coarseRow;% - kBinWidth;
		xk = x + coarseCol;% - kBinWidth;
		
		% NEAREST CENTRAL SUBSCRIPTS
		rowC = round(y) + coarseRow;
		colC = round(x) + coarseCol;
		
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
		
		
		
		function g = gausskern(y0, x0)
			f = xc(y0,x0,t);
			g = f*exp(-( inv2w2*((xk-x0)^2 + (yk-y0)^2) ));
			
		end
	end
	function fResamp = arbitraryResampleKernel( y, x, t, dy, dx)
		
		ck = Rk + 1;
		
		% 		NEAREST SINGLE PIXEL SUBSCRIPTS
		rowC = min(numRows, max(1, y - dy));
		colC = min(numCols, max(1, x - dx));		
		
		
		% 		ADJACENT-TO-NEAREST PIXEL SUBSCRIPTS
		rowU = max(1, rowC-1);		
		colL = max(1, colC-1);
		rowD = min(numRows, rowC+1);
		colR = min(numRows, colC+1);
		
		% NEXT OUTER NEIGHBOR TO NEAREST PIXELS SUBSCRIPTS
		rowUU = max(1, rowU-1);
		colLL = max(1, colL-1);
		rowDD = min(numRows, rowD+1);
		colRR = min(numCols, colR+1);
		
		% 		INITIALIZE
		fResamp = single(0) ...
			+ kResampleKernel(-2,-2, t) * moving_fp( rowUU, colLL, t)...
			+ kResampleKernel(-1,-2, t) * moving_fp( rowU , colLL, t)...
			+ kResampleKernel( 3,-2, t) * moving_fp( rowC , colLL, t)...
			+ kResampleKernel( 4,-2, t) * moving_fp( rowD , colLL, t)...
			+ kResampleKernel( 5,-2, t) * moving_fp( rowDD, colLL, t)...
			+ kResampleKernel(-2,-1, t) * moving_fp( rowUU, colL , t)...
			+ kResampleKernel(-1,-1, t) * moving_fp( rowU , colL , t)...
			+ kResampleKernel( 3,-1, t) * moving_fp( rowC , colL , t)...
			+ kResampleKernel( 4,-1, t) * moving_fp( rowD , colL , t)...
			+ kResampleKernel( 5,-1, t) * moving_fp( rowDD, colC , t)...
			+ kResampleKernel(-2, 3, t) * moving_fp( rowUU, colC , t)...
			+ kResampleKernel(-1, 3, t) * moving_fp( rowU , colC , t)...
			+ kResampleKernel( 3, 3, t) * moving_fp( rowC , colC , t)...
			+ kResampleKernel( 4, 3, t) * moving_fp( rowD , colC , t)...
			+ kResampleKernel( 5, 3, t) * moving_fp( rowDD, colC , t)...
			+ kResampleKernel(-2, 4, t) * moving_fp( rowUU, colR , t)...
			+ kResampleKernel(-1, 4, t) * moving_fp( rowU , colR , t)...
			+ kResampleKernel( 3, 4, t) * moving_fp( rowC , colR , t)...
			+ kResampleKernel( 4, 4, t) * moving_fp( rowD , colR , t)...
			+ kResampleKernel( 5, 4, t) * moving_fp( rowDD, colR , t)...
			+ kResampleKernel(-2, 5, t) * moving_fp( rowUU, colRR, t)...
			+ kResampleKernel(-1, 5, t) * moving_fp( rowU , colRR, t)...
			+ kResampleKernel( 3, 5, t) * moving_fp( rowC , colRR, t)...
			+ kResampleKernel( 4, 5, t) * moving_fp( rowD , colRR, t)...
			+ kResampleKernel( 5, 5, t) * moving_fp( rowDD, colRR, t);
		
		function g = resamplePixel(dy,dx)
			
		end
		
	end
	function fResamp = coarseResampleKernel( y, x, t, dy, dx)
		
		% NEAREST SINGLE PIXEL SUBSCRIPTS
		rowC = min(numRows, max(1, y - dy));
		colC = min(numCols, max(1, x - dx));
		
		% DISPLACED RESAMPLE
		fResamp = moving_fp( rowC, colC, t);
		
	end











end



function F = applyFrameShift(obj, F, Uxy)
			
			% ---------->>> TODO: WOULD BY MUCH MUCH FASTER WITH A GPU KERNEL!!!!!!!!!!!!!!!!!!
			% ---------->>> TODO: WOULD BY MUCH MUCH FASTER WITH A GPU KERNEL!!!!!!!!!!!!!!!!!!
			dataisongpu = isa(F,'gpuArray');
			
			[numRows, numCols, numFrames] = size(F);
			
			% TODO
			if dataisongpu
				rowSubs = reshape(single(gpuArray.colon(1,numRows)), numRows,1);
				colSubs = reshape(single(gpuArray.colon(1,numCols)), 1, numCols);
				frameSubs = reshape(single(gpuArray.colon(1,numFrames)), 1,1,numFrames);
				Ffp = single(F);
				
			else
				rowSubs = reshape(colon(1,numRows), numRows,1);
				colSubs = reshape(colon(1,numCols), 1, numCols);
				frameSubs = reshape(colon(1,numFrames), 1,1,numFrames);
				Ffp = double(F);
				
			end
			
			% INTERPOLATE OVER NEW GRID SHIFTED BY Ux & Uy
			ux = reshape(Uxy(:,2), 1,1,numFrames);
			uy = reshape(Uxy(:,1), 1,1,numFrames);
			
			if numFrames > 1
				[Y,X,Z] = ndgrid(rowSubs, colSubs, frameSubs);
				Xq = bsxfun(@minus, X, ux);
				Yq = bsxfun(@minus, Y, uy);
				Zq = Z;
				Ffp = interpn( Y,X,Z, Ffp, Yq, Xq, Zq, 'linear', -1); % Ffp = interpn( X,Y,Z, Ffp, Xq, Yq, Zq, 'linear', -1);
			else
				try
					Ffp = interp2( Ffp, colSubs+ux, rowSubs+uy, 'linear', -1); % Ffp = interp2( Ffp, rowSubs-uy, colSubs-ux, 'linear', -1);
				catch me
					showError(me)
				end
			end
			
			% REPLACE MISSING PIXELS ALONG EDGE			
			dMask = Ffp < 0;
			% 			Fmean = repmat(obj.FixedMean, 1,1,numFrames);
			% 			Ffp(dMask) = Fmean(dMask);
			Ffp = Ffp + bsxfun(@times, cast(obj.FixedMean + 1,'like',Ffp), cast(dMask,'like',Ffp));
			F = cast(Ffp,'like', F);
			
		end

% function kSum = kernelDensityEstimate16PixelKernel( y, x, t, w)
% 		
% 		inv2w2 = 1 / (2*w^2);
% 		coarseRow = xcMaxRow(t);
% 		coarseCol = xcMaxCol(t);
% 		yk = y + coarseRow;
% 		xk = x + coarseCol;
% 		
% 		% NEAREST CENTRAL SUBSCRIPTS
% 		
% 		
% 		% UPPER-LEFT PIXEL SUBSCRIPTS
% 		rowU = max(1, min(numRows, floor(y)));
% 		colL = max(1, min(numCols, floor(x)));
% 		
% 		% OTHER NEAREST PIXEL SUBSCRIPTS
% 		rowD = rowU+1;
% 		colR = colL+1;
% 		
% 		% NEXT OUTER NEIGHBOR TO NEAREST PIXELS SUBSCRIPTS
% 		rowUU = max(1, rowU-1);
% 		colLL = max(1, colL-1);
% 		rowDD = min(numRows, rowD+1);
% 		colRR = min(numCols, colR+1);
% 		
% 		% INITIALIZE
% 		kSum = single(0) ...
% 			+ gausskern( rowUU, colLL)...
% 			+ gausskern( rowU , colLL)...
% 			+ gausskern( rowD , colLL)...
% 			+ gausskern( rowDD, colLL)...
% 			+ gausskern( rowUU, colL )...
% 			+ gausskern( rowU , colL )...
% 			+ gausskern( rowD , colL )...
% 			+ gausskern( rowDD, colL )...
% 			+ gausskern( rowUU, colR )...
% 			+ gausskern( rowU , colR )...
% 			+ gausskern( rowD , colR )...
% 			+ gausskern( rowDD, colR )...
% 			+ gausskern( rowUU, colRR)...
% 			+ gausskern( rowU , colRR)...
% 			+ gausskern( rowD , colRR)...
% 			+ gausskern( rowDD, colRR);
% 		% 		kSum = kSum /  (1 + gausskern(xcMaxRow(t), xcMaxCol(t)));
% 		
% 		function g = gausskern(y0, x0)
% 			f = xc(y0,x0,t);
% 			g = f*exp(-( inv2w2*((x-x0)^2 + (y-y0)^2) ));
% 			
% 		end
% 	end

%			xc = fftshift(fftshift( ifft2( bsxfun(@rdivide, fFM , (fFF + eps(fFF)).^2), 'symmetric'), 1),2);
% 			fFF = bsxfun(@times, fFixed, conj(fFixed)); % NEW: yikes ->> imscplay(bsxfun(@rdivide, fftshift(fftshift(ifft2(fFF),1),2), fftshift(fftshift(ifft2(abs(fFM+eps(fFM)),'symmetric'),1),2)))
%
%
% 			H = fFM ./ abs(fFM + eps(fFM));
% 			movingDeblurred = fftshift(fftshift( ifft2(...
% 				bsxfun(@rdivide,...
% 				fMoving.*conj(H) + .1*abs(fFM + eps(fFM)), ...
% 				H.*conj(H) + .1), 'symmetric'),1),2); % abs(bsxfun(@minus,fFixed,fMoving))










%
%
% 	% CALCULATE LINEAR ARRAY INDICES FOR PIXELS SURROUNDING INTEGER-PRECISION PEAK
% 				xcFrameIdx = reshape(xcNumPixels*(0:xcNumFrames-1),1,1,xcNumFrames);
% 				xcPeakSurrIdx = ...
% 					bsxfun(@plus, peakRelativeDomainCoarse(:),...
% 					bsxfun(@plus,peakRelativeDomainCoarse(:)' .* xcNumRows,...
% 					bsxfun(@plus,xcFrameIdx,...
% 					xcMaxFrameIdx)));
% 				Csize = 1+2*R;
% 				C = reshape(xc(xcPeakSurrIdx),...
% 					Csize,Csize,xcNumFrames);
%
% 				% CHOOSE A METHOD FOR FITTING A SURFACE TO PIXELS SURROUNDING PEAK
% 				if isempty(peakFitFcn)
% 					bench = comparePeakFitFcn(C, ...
% 						@getPeakSubpixelOffset_MomentMethod, ...
% 						@getPeakSubpixelOffset_PolyFit);
% 					if bench.precise.t > (2*bench.fast.t)
% 						peakFitFcn = bench.precise.fcn;
% 					else
% 						peakFitFcn = bench.fast.fcn;
% 					end
% 					%TODO: save bench
% 				end
%
% 				% USE MOMENT METHOD TO CALCULATE CENTER POSITION OF A GAUSSIAN FIT AROUND PEAK - OR USE LEAST-SQUARES POLYNOMIAL SURFACE FIT
% 				[spdy, spdx] = peakFitFcn(C);
% 				% 						[spdy, spdx] = getPeakSubpixelOffset_MomentMethod(C);		% 10.5 ms/call
% 				uy = reshape(rowSubs(xcMaxRow), 1,1,xcNumFrames) + spdy - centerRow - 1;
% 				ux = reshape(colSubs(xcMaxCol), 1,1,xcNumFrames) + spdx - centerCol - 1;
%
% 				% TODO: ROUND TO DESIRED SUBPIXEL ACCURACY
%
%
%
%
%
% 				% ===  BENCHMARKING FUNCTION TO CHOOSE WHICH FUNCTION TO PERFORM ===
% 				function bench = comparePeakFitFcn(c, fastFcn, preciseFcn)
%
% 					fast.fcn = fastFcn;
% 					precise.fcn = preciseFcn;
%
% 					if obj.pUseGpu
% 						fast.t = gputimeit(@() fast.fcn(c), 2);
% 						precise.t = gputimeit(@() precise.fcn(c), 2);
% 					else
% 						fast.t = timeit(@() fast.fcn(c), 2);
% 						precise.t = timeit(@() precise.fcn(c), 2);
% 					end
%
% 					fast.dydx = fast.fcn(c);
% 					precise.dydx = precise.fcn(c);
%
% 					bench.fast = fast;
% 					bench.precise = precise;
% 					bench.sse = sum((bench.precise.dydx(:) - bench.fast.dydx(:)).^2);
% 					bench.dt = (bench.precise.t - bench.fast.t) / bench.fast.t;
%
% 				end
%
%
% 				% ===  MOMENT-METHOD FOR ESTIMATING POSITION OF A GAUSSIAN FIT TO PEAK ===
% 				function [spdy, spdx] = getPeakSubpixelOffset_MomentMethod(c)
% 					cSum = sum(sum(c));
% 					d = size(c,1);
% 					r = floor(d/2);
% 					spdx = .5*(bsxfun(@rdivide, ...
% 						sum(sum( bsxfun(@times, (1:d), c))), cSum) - r ) ...
% 						+ .5*(bsxfun(@rdivide, ...
% 						sum(sum( bsxfun(@times, (-d:-1), c))), cSum) + r );
% 					spdy = .5*(bsxfun(@rdivide, ...
% 						sum(sum( bsxfun(@times, (1:d)', c))), cSum) - r ) ...
% 						+ .5*(bsxfun(@rdivide, ...
% 						sum(sum( bsxfun(@times, (-d:-1)', c))), cSum) + r );
%
% 				end
%
% 				% ===  LEAST-SQUARES FIT OF POLYNOMIAL FUNCTION TO PEAK ===
% 				function [spdy, spdx] = getPeakSubpixelOffset_PolyFit(c)
% 					% POLYNOMIAL FIT, c = Xb
% 					[cNumRows, cNumCols, cNumFrames] = size(c);
% 					d = cNumRows;
% 					r = floor(d/2);
% 					[xg,yg] = meshgrid(-r:r, -r:r);
% 					x=xg(:);
% 					y=yg(:);
% 					X = [ones(size(x),'like',x) , x , y , x.*y , x.^2, y.^2];
% 					b = X \ reshape(c, cNumRows*cNumCols, cNumFrames);
% 					if (cNumFrames == 1)
% 						spdx = (-b(3)*b(4)+2*b(6)*b(2)) / (b(4)^2-4*b(5)*b(6));
% 						spdy = -1 / ( b(4)^2-4*b(5)*b(6))*(b(4)*b(2)-2*b(5)*b(3));
% 					else
% 						spdx = reshape(...
% 							(-b(3,:).*b(4,:) + 2*b(6,:).*b(2,:))...
% 							./ (b(4,:).^2 - 4*b(5,:).*b(6,:)), ...
% 							1, 1, cNumFrames);
% 						spdy = reshape(...
% 							-1 ./ ...
% 							( b(4,:).^2 - 4*b(5,:).*b(6,:)) ...
% 							.* (b(4,:).*b(2,:) - 2*b(5,:).*b(3,:)), ...
% 							1, 1, cNumFrames);
% 					end
% 				end