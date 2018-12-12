function [Ftz, stat, ftstat] = temporallyAdaptiveTemporalFilterRunGpuKernel(F, stat, ftstat, A0, N0Max)
% 
% NOT YET FUNCTIONAL
%			NOTES: there are several versions in the backups folder, several of which implement good
%			edge-finding functions, but none of which seem to lend well to what the function was
%			originally trying to accomplish
%
%
% ftstat = []; F0 = []; idx=0; while idx(end)<2047, idx=idx(end)+(1:16); F=gpuArray(Fcpu(:,:,idx)); [ft, F0, ftstat] = temporallyAdaptiveTemporalFilterRunGpuKernel(F, F0, ftstat); Ft(:,:,idx) = gather(ft); end
%
% SEE ALSO:
%
%
% Mark Bucklin





% ============================================================
% INFO ABOUT INPUT
% ============================================================
[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));

% INPUT -> BUFFERED OUTPUT FROM PREVIOUS CALL
if (nargin < 5)
	N0Max = [];
	if (nargin < 4)
		A0 = [];
		if (nargin < 3)
			ftstat = [];
			if (nargin < 2)
				stat = []; % F0
			end
		end
	end
end

% FILTER ORDER & MAX TIME-CONSTANT
if isempty(A0)
	A0 = gpuArray.zeros(numRows, numCols, 1, numChannels, 'single');
end
if isempty(N0Max)
	N0Max = single(50);
end

% UPDATE FMIN & FMAX
Aminmax = single(.90);
if isempty(stat)
	stat.min = F(:,:,1,:);
	stat.max = F(:,:,1,:);
	% 	F0 = bsxfun(@minus, F(:,:,1,:), cast(mean(diff(F,1,3),3),'like',F));
	% 	F0 = cast(mean(F,3),'like',F);
else
	stat.min = minFilterKernel(stat.min, rowSubs,colSubs,chanSubs);
	stat.max = maxFilterKernel(stat.max, rowSubs,colSubs,chanSubs);
end
Fmin = cummin(bsxfun(@min, stat.min, F),3);
Fmax = cummin(bsxfun(@max, stat.max, F),3);
% Frange = Fmax - Fmin;
F0 = single(max(Fmax - Fmin,[],3));



filterOrder = single(min(2, size(F0,3)));



% ============================================================
% DETERMINE/UPDATE FILTER COEFFICIENT FOR EACH PIXEL FROM TEMPORAL GRADIENT
% ============================================================
N0md = single(256);
edgeSuppressionDist = int32(1);
% Fbase = single(mean(mean(F0(:))));

Ft = arrayfun(@extremeDiffMagnitudeKernel, F, Fmin, Fmax);
% Ft = arrayfun(@temporalGradientMagnitudeKernel, rowSubs, colSubs, frameSubs, chanSubs);
% Ft = arrayfun(@movingDiffMagnitudeKernel, F, F0, frameSubs, chanSubs);
Ft = arrayfun(@suppressNonEdgeKernel, Ft, rowSubs, colSubs, frameSubs, chanSubs);


if isempty(ftstat)
	% INITIALIZE TEMPORAL-CHANGE STATISTICS
	FtMean = single(mean(Ft,3));
	FtStd = single(std(Ft,[],3));
	N = gpuArray.zeros(numRows,numCols,1,numChannels,'single') + single(numFrames);
	% 	FtMean = single(Ft(:,:,1,:));
	% 	FtStd = gpuArray.zeros(numRows,numCols,1,numChannels, 'single');
	% 	N = gpuArray.ones(1,'single');
else
	% UPDATE TEMPORAL-CHANGE STATISTICS
	% 	FtMean = ftstat.mean;
	% 	FtStd = ftstat.std;
	% 	N = ftstat.n;
	[FtMean, FtStd, N] = arrayfun(@ftStatUpdateKernel, ftstat.mean, ftstat.std, ftstat.n, rowSubs, colSubs, chanSubs);
end

% UPDATE TEMPORAL-CHANGE STATISTICS
% [FtMean, FtStd, N] = arrayfun(@ftStatUpdateKernel, FtMean, FtStd, N, rowSubs, colSubs, chanSubs);
ftstat.mean = FtMean;
ftstat.std = FtStd;
ftstat.n = N;

% Z-SCORE THE TEMPORAL CHANGE
% Ft = bsxfun(@times, bsxfun(@minus, Ft, FtMean), 1./FtStd);
FtStdMean = single(mean(FtStd(:)));
% Ftz = arrayfun(@zScoreKernel, Ft, FtMean, FtStd);
Ftz = bsxfun(@minus, Ft, FtMean);



% Ftz = arrayfun(@suppressNonEdgeKernel, Ftz, rowSubs, colSubs, frameSubs, chanSubs);



% FtSSD = sum(sum(Ft,1),2);
% FtSSDmax = max(FtSSD,[],3);



% nk = double(numFrames) + double(N0md);		


% F0 = single(mean(F,3));
% [F0, Ftmean, FtStd] = arrayfun(@movingFilterKernel, F0, rowSubs, colSubs, chanSubs);

% FtSSD = squeeze(FtSSD);

% Aminmax = single(.65);
% Fmin = minmaxFilterKernel( min(F,[],3), Fmin);
% Fmax = minmaxFilterKernel( max(F,[],3), Fmax);


% ============================================================
% PREALLOCATE OUTPUT & INITIALIZE BUFFERED OUTPUT
% ============================================================
% Fout = gpuArray.zeros(numRows, numCols, numFrames, numChannels, 'single');
% k = 1;
% 
% 
% 
% % ============================================================
% % CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% % ============================================================
% if filterOrder == 1
% 	% FIRST ORDER RECURSIVE FILTER
% 	Fkm1 = F0;
% 	while k <= numFrames
% 		[F(:,:,k,:), Fkm1] = arrayfun( @arFilterKernel1, F(:,:,k,:), Fkm1, A);
% 		k=k+1;
% 	end
% 	F0 = Fkm1;
% 
% else
% 	% SECOND ORDER RECURSIVE FILTER
% 	Fkm1 = F0(:,:,2,:);
% 	Fkm2 = F0(:,:,1,:);
% 	while k <= numFrames
% 		[F(:,:,k,:), Fkm1, Fkm2] = arrayfun( @arFilterKernel2, F(:,:,k,:), Fkm1, Fkm2, A);
% 		k=k+1;
% 	end
% 	F0 = cat(3, Fkm2, Fkm1);
% 
% end

%
%
% % ============================================================
% % OUTPUT
% % ============================================================

% UPDATE MOVING-AVERAGE
% Amovavg = exp(-1/N0md);
% F0 = arrayfun(@movingFilterKernel, F0, rowSubs, colSubs, chanSubs);


% F0 = single(F(:,:,end,:));
% stat.min = min(Fmin,[],3);
% stat.max = max(Fmax,[],3);

% if nargout > 1
% 	varargout{1} = F0;
% 	if nargout > 2
% 		varargout{2} = A;
% 	end
% end









% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% TEMPORAL GRADIENT -> FILTER COEFFICIENT ####################
% ============================================================

% ---------------------------------------
% GET TEMPORAL-GRADIENT
% ---------------------------------------
	function ft = movingDiffMagnitudeKernel(f, f0, frameIdx, chanIdx)
		% COMPUTE DIFFERENCE BETWEEN EACH FRAME & MOVING-AVERAGE
		nk = double(numFrames) + double(N0md) - double(frameIdx);
		a = exp(-1/nk);
		f0 = (1-a)*single(f) + a*f0;
		ft = (single(f)-f0).^2 ./ (f0 + 1);%single(Fbase(1,1,1,chanIdx)));		
	end
	function ft = temporalGradientMagnitudeKernel(rowIdx, colIdx, frameIdx, chanIdx)
						
		if frameIdx > 1
			fkm1 = single(F(rowIdx,colIdx,frameIdx-1,chanIdx));
		else
			fkm1 = single(F0(rowIdx,colIdx,filterOrder,chanIdx));
		end
		
		fk = single(F(rowIdx,colIdx,frameIdx,chanIdx));
		
		ft = abs(fk - fkm1);% ./ (fkm1 + single(Fbase(1,1,1,chanIdx)));
		
	end
	function fmin = minFilterKernel(fmin0, rowIdx, colIdx, chanIdx)
		% Recursive  filter along third dimension (presumably time)
		k=1;
		fmin = F(rowIdx,colIdx,k,chanIdx);
		while k < numFrames
			k = k + 1;
			fmin = min( fmin, F(rowIdx,colIdx,k,chanIdx));
		end
		a = double(Aminmax);
		fmin = min( fmin, (1-a)*fmin + a*fmin0);
		
	end
	function fmax = maxFilterKernel(fmax0, rowIdx, colIdx, chanIdx)
		% Recursive  filter along third dimension (presumably time)
		k=1;
		fmax = F(rowIdx,colIdx,k,chanIdx);
		while k < numFrames
			k = k + 1;
			fmax = max( fmax, F(rowIdx,colIdx,k,chanIdx));
		end
		a = double(Aminmax);
		fmax = max( fmax, (1-a)*fmax + a*fmax0);
		
	end
	function ft = extremeDiffMagnitudeKernel(f, fmin, fmax)
		
		fmindiff = single(f) - single(fmin);
		fmaxdiff = single(fmax) - single(f);
		
		% 		ft = fmindiff + fmaxdiff;
		% 		ft = max(fmindiff,fmaxdiff);
		% 		ft = (fmindiff^2 + fmaxdiff^2) ./ single(frange);
		ft = max(fmindiff, fmaxdiff);% ./ single(fmax-fmin+1);
		
	end

% ---------------------------------------
% SUPPRESS NON-EDGE TEMPORAL GRADIENTS
% ---------------------------------------
	function ft = suppressNonEdgeKernel(ft, rowIdx, colIdx, frameIdx, chanIdx)		
		% 		f0 = single(F0(rowIdx,colIdx,1,chanIdx)) + single(Fbase(1,1,1,chanIdx));
		% 		ft = single(Ft(rowIdx,colIdx,frameIdx,chanIdx));% ./ f0;
		d = edgeSuppressionDist;
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING (NEIGHBOR) PIXELS
		rowU = int32(max( 1, rowIdx-d));
		rowD = int32(min( numRows, rowIdx+d));
		colL = int32(max( 1, colIdx-d));
		colR = int32(min( numCols, colIdx+d));
		
		% RETRIEVE NEIGHBOR PIXEL INTENSITY VALUES
		% 		fUL = single(Ft(rowU, colL, 1, chanC));
		% 		fUC = single(Ft(rowU, colC, 1, chanC));
		% 		fUR = single(Ft(rowU, colR, 1, chanC));
		% 		fCL = single(Ft(rowC, colL, 1, chanC));
		% 		fCR = single(Ft(rowC, colR, 1, chanC));
		% 		fDL = single(Ft(rowD, colL, 1, chanC));
		% 		fDC = single(Ft(rowD, colC, 1, chanC));
		% 		fDR = single(Ft(rowD, colR, 1, chanC));
		fU = single(Ft(rowU, colIdx, frameIdx, chanIdx));
		fL = single(Ft(rowIdx, colL, frameIdx, chanIdx));
		fR = single(Ft(rowIdx, colR, frameIdx, chanIdx));
		fD = single(Ft(rowD, colIdx, frameIdx, chanIdx));
		
		fudmin = min(fU,fD);% ./ f0;
		flrmin = min(fL,fR);% ./ f0;
		fudmax = max(fU,fD);% ./ f0;
		flrmax = max(fL,fR);% ./ f0;
		udNonEdge = (fudmin*2 >= ft) & (ft*2 > fudmax);
		% 		udNonEdge = (fudmin+ft >= fudmax) ;%| abs(fudmax-ft) < fudmin);
		lrNonEdge = (flrmin*2 >= ft) & (ft*2 > flrmax);
		% 		udNonEdge = fudmin > (ft/2);
		% 		lrNonEdge = flrmin > (ft/2);
		nonEdgeSuppression = single(udNonEdge & lrNonEdge) * .95;
		
		ft = ft .* (1-nonEdgeSuppression);
		
		% 		ft = ft .* (1-udSuppression) .* (1-lrSuppression);
		
	end

% ---------------------------------------
% TEMPORAL-GRADIENT STATISTIC UPDATE
% ---------------------------------------
	function [ftmean, ftstd, n] = ftStatUpdateKernel(ftmean, ftstd, n, rowIdx, colIdx, chanIdx)		
		k = int32(0);
		m2 = ftstd^2;
		while k < numFrames
			
			% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
			k = k + 1;
			n = n + 1;
			
			% GET PIXEL SAMPLE
			ft = Ft(rowIdx,colIdx,k,chanIdx);
			
			% PRECOMPUTE & CACHE SOME VALUES FOR SPEED
			d = single(ft) - ftmean;
			dk = d/n;
			s = d*dk*(n-1);
			
			% UPDATE MEAN & STANDARD DEVIATION (VIA CENTRAL MOMENTS)
			ftmean = ftmean + dk;
			m2 = m2 + s;
			
		end
		ftstd = sqrt(abs(m2));
		
	end

% ---------------------------------------
% Z-SCORE TEMPORAL GRADIENT
% ---------------------------------------
	function ft = zScoreKernel(ft, ftmean, ftstd)
				ft = ft - ftmean;
				ft = ft ./ (ftstd + FtStdMean);
				
	end

% ---------------------------------------
% UPDATE MOVING AVERAGE
% ---------------------------------------
	function f0 = movingFilterKernel(f0, rowIdx, colIdx, chanIdx)
		% UPDATE MOVING-AVERAGE
		a = double(Amovavg);
		k = int32(0);
		while (k < numFrames)
			k = k + 1;
			fk = single(F(rowIdx,colIdx,k,chanIdx));
			f0 = (1-a)*fk + a*f0;
		end
		
	end






% ============================================================
% TEMPORAL FILTERS ###########################################
% ============================================================

% ---------------------------------------
% FIRST ORDER
% ---------------------------------------
	function [yk, ykm1] = arFilterKernel1(xk, ykm1, a32)
		% Recursive  filter along third dimension (presumably time)
		
		a = double(a32);
		yk = (1-a)*xk + a*ykm1;
		ykm1 = yk;
		
	end

% ---------------------------------------
% SECOND ORDER
% ---------------------------------------
	function [yk, ykm1, ykm2] = arFilterKernel2(xk, ykm1, ykm2, a32)
		% Recursive  filter along third dimension (presumably time)
		
		a = double(a32);
		yk = (1-a)^2*xk + 2*a*ykm1 - a^2*ykm2;
		ykm2 = ykm1;
		ykm1 = yk;
		
	end


end



















% 	function ft = extremeDiffMagnitudeKernelFcn(f, fmin, fmax)
%
% 		fmindiff = single(f) - single(fmin);
% 		fmaxdiff = single(fmax) - single(f);
%
% 		% 		ft = fmindiff + fmaxdiff;
% 		ft = max(fmindiff,fmaxdiff);
%
% 	end
% 	function yk = minmaxFilterKernel(xk, ykm1)
% 		% Recursive  filter along third dimension (presumably time)
%
% 		a = double(Aminmax);
% 		yk = (1-a)*xk + a*ykm1;
%
% 	end
% 	function ft = temporalGradientMagnitudeKernelFcn(rowIdx, colIdx, frameIdx, chanIdx)
%
% 		% 		if frameIdx > 1
% 		% 			fkm1 = single(F(rowIdx,colIdx,frameIdx-1,chanIdx));
% 		% 		else
% 		% 			fkm1 = single(Fmin(rowIdx,colIdx,int32(filterOrder),chanIdx));
% 		% 		end
%
% 		fk = single(F(rowIdx,colIdx,frameIdx,chanIdx));
%
% 		ft = (fk - fkm1).^2;
%
% 	end

% 		a0 = A0(rowC,colC,1,chanC);
%
% 		% CALCULATE SUBSCRIPTS FOR SURROUNDING (NEIGHBOR) PIXELS
% 		rowU = int32(max( 1, rowC-1));
% 		rowD = int32(min( numRows, rowC+1));
% 		colL = int32(max( 1, colC-1));
% 		colR = int32(min( numCols, colC+1));
%
% 		% RETRIEVE NEIGHBOR PIXEL INTENSITY VALUES
% 		fUL = single(F0(rowU, colL, 1, chanC));
% 		fUC = single(F0(rowU, colC, 1, chanC));
% 		fUR = single(F0(rowU, colR, 1, chanC));
% 		fCL = single(F0(rowC, colL, 1, chanC));
% 		fCR = single(F0(rowC, colR, 1, chanC));
% 		fDL = single(F0(rowD, colL, 1, chanC));
% 		fDC = single(F0(rowD, colC, 1, chanC));
% 		fDR = single(F0(rowD, colR, 1, chanC));
%
% 		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NEIGHBORING SAMPLES
% 		df000 = fCR - fCL;
% 		df045 = fUR - fDL;
% 		df090 = fUC - fDC;
% 		df135 = fUL - fDR;
%
% 		% COMPUTE MEAN INTENSITY & GRADIENT
% 		fNeighSum = f + fUL + fUC + fUR + fCL + fCR + fDL + fDC + fDR;
% 		fNeighMean = single(1/9) * fNeighSum;
%
% 		meanSpatialDiff = single(1/4) * ( abs(df000) + abs(df045) + abs(df090) + abs(df135));
% 		% 		maxSpatialDiff = max(max(max(abs(df000),abs(df045)),abs(df090)),abs(df135));
% 		% 		minSpatialDiff = min(min(min(abs(df000),abs(df045)),abs(df090)),abs(df135));
%
% 		% 		d = meanSpatialDiff*(maxSpatialDiff - minSpatialDiff) / fNeighMean^2;
% 		d = min(1, meanSpatialDiff/fNeighMean); % max(0,f-fNeighMean)/fNeighMean;
% 		n0 = d*N0Max;
% 		a = max( exp(-filterOrder/n0), .5*a0);
%
% 	end


