function [F, varargout] = spatiallyAdaptiveTemporalFilterRunGpuKernel(F, F0, A0, N0Max)
% temporalStabilityRunGpuKernel
%
%		USAGE:
%				>> F = spatiallyAdaptiveTemporalFilterRunGpuKernel(F, F0, A0, N0Max)
%				>> [F, F0] = spatiallyAdaptiveTemporalFilterRunGpuKernel(F, F0, A0, N0Max)
%				>> [F, F0, A] = spatiallyAdaptiveTemporalFilterRunGpuKernel(F, F0, A0, N0Max)
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
% frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));

% INPUT -> BUFFERED OUTPUT FROM PREVIOUS CALL
if (nargin < 4)
	N0Max = [];
	if nargin < 3
		A0 = [];
		if (nargin < 2)
			F0 = [];
		end
	end
end
if isempty(F0)
	F0 = F(:,:,1,:); %max(F,[],3); %uint16(mean(F,3));
end

% FILTER ORDER & MAX TIME-CONSTANT
filterOrder = single(min(2, size(F0,3)));
if isempty(A0)
	A0 = gpuArray.zeros(numRows, numCols, 1, numChannels, 'single');
end
if isempty(N0Max)
	N0Max = single(50);
end


% ============================================================
% DETERMINE/UPDATE FILTER COEFFICIENT FOR EACH PIXEL
% ============================================================
A = arrayfun(@normalizedSpatialGradientMagnitudeKernelFcn, max(F0,[],3), rowSubs, colSubs, chanSubs);



% ============================================================
% PREALLOCATE OUTPUT & INITIALIZE BUFFERED OUTPUT
% ============================================================
% Fout = gpuArray.zeros(numRows, numCols, numFrames, numChannels, 'single');
k = 1;



% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
if filterOrder == 1
	% FIRST ORDER RECURSIVE FILTER
	Fkm1 = F0;
	while k <= numFrames
		[F(:,:,k,:), Fkm1] = arrayfun( @arFilterKernel1, F(:,:,k,:), Fkm1, A);
		k=k+1;		
	end	
	F0 = Fkm1;
	
else
	% SECOND ORDER RECURSIVE FILTER
	Fkm1 = F0(:,:,2,:);
	Fkm2 = F0(:,:,1,:);
	while k <= numFrames
		[F(:,:,k,:), Fkm1, Fkm2] = arrayfun( @arFilterKernel2, F(:,:,k,:), Fkm1, Fkm2, A);
		k=k+1;
	end
	F0 = cat(3, Fkm2, Fkm1);
		
end



% ============================================================
% OUTPUT
% ============================================================
if nargout > 1
	varargout{1} = F0;
	if nargout > 2
		varargout{2} = A;
	end
end









% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% SPATIAL GRADIENT DETERMINES FILTER COEFFICIENT
% ============================================================
	
	function a = normalizedSpatialGradientMagnitudeKernelFcn(fIn, rowC, colC, chanC)
		
		f = single(fIn);
		a0 = A0(rowC,colC,1,chanC);
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING (NEIGHBOR) PIXELS
		rowU = int32(max( 1, rowC-1));
		rowD = int32(min( numRows, rowC+1));
		colL = int32(max( 1, colC-1));
		colR = int32(min( numCols, colC+1));
		
		% RETRIEVE NEIGHBOR PIXEL INTENSITY VALUES
		fUL = single(F0(rowU, colL, 1, chanC));
		fUC = single(F0(rowU, colC, 1, chanC));
		fUR = single(F0(rowU, colR, 1, chanC));
		fCL = single(F0(rowC, colL, 1, chanC));
		fCR = single(F0(rowC, colR, 1, chanC));
		fDL = single(F0(rowD, colL, 1, chanC));
		fDC = single(F0(rowD, colC, 1, chanC));
		fDR = single(F0(rowD, colR, 1, chanC));
		
		% COMPUTE DIFFERENCE BETWEEN CURRENT PIXEL & NEIGHBORING SAMPLES		
		df000 = fCR - fCL;
		df045 = fUR - fDL;
		df090 = fUC - fDC;
		df135 = fUL - fDR;
		
		% COMPUTE MEAN INTENSITY & GRADIENT
		fNeighSum = f + fUL + fUC + fUR + fCL + fCR + fDL + fDC + fDR;
		fNeighMean = single(1/9) * fNeighSum;
		
		meanSpatialDiff = single(1/4) * ( abs(df000) + abs(df045) + abs(df090) + abs(df135));
		% 		maxSpatialDiff = max(max(max(abs(df000),abs(df045)),abs(df090)),abs(df135));
		% 		minSpatialDiff = min(min(min(abs(df000),abs(df045)),abs(df090)),abs(df135));
		
		% 		d = meanSpatialDiff*(maxSpatialDiff - minSpatialDiff) / fNeighMean^2;
		d = min(1, meanSpatialDiff/fNeighMean); % max(0,f-fNeighMean)/fNeighMean;
		n0 = d*N0Max;
		a = max( exp(-filterOrder/n0), .5*a0);
		
	end

% ============================================================
% FIRST-ORDER ################################################
% ============================================================
	function [yk, ykm1] = arFilterKernel1(xk, ykm1, a32)
		% Recursive  filter along third dimension (presumably time)
		
		a = double(a32);
		yk = (1-a)*xk + a*ykm1;
		ykm1 = yk;
		
	end

% ============================================================
% SECOND-ORDER ###############################################
% ============================================================
	function [yk, ykm1, ykm2] = arFilterKernel2(xk, ykm1, ykm2, a32)
		% Recursive  filter along third dimension (presumably time)
		
		a = double(a32);
		yk = (1-a)^2*xk + 2*a*ykm1 - a^2*ykm2;
		ykm2 = ykm1;
		ykm1 = yk;
		
	end


end
















% function a = normalizedSpatialGradientMagnitudeKernelFcn(fIn, rowC, colC, chanC)
% 		
% 		f = single(fIn);
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
% 		dfUL = f - fUL;
% 		dfUC = f - fUC;
% 		dfUR = f - fUR;
% 		dfCL = f - fCL;
% 		dfCR = f - fCR;
% 		dfDL = f - fDL;
% 		dfDC = f - fDC;
% 		dfDR = f - fDR;
% 		
% 		% COMPUTE MEAN INTENSITY & GRADIENT
% 		fNeighSum = fUL + fUC + fUR + fCL + fCR + fDL + fDC + fDR;
% 		fNeighMean = single(1/8) * fNeighSum;
% 		
% 		meanSpatialDiff = single(1/8) * ( single(0) ...
% 			+ abs(dfUL) + abs(dfUC) + abs(dfUR) ...
% 			+ abs(dfCL) 						+	abs(dfCR) ...
% 			+ abs(dfDL) + abs(dfDC) + abs(dfDR) );
% 		
% 		
% 		d = meanSpatialDiff/fNeighMean; % max(0,f-fNeighMean)/fNeighMean;
% 		n0 = d*N0Max;
% 		a = max( exp(-filterOrder/n0), .5*a0);
% 		
% end
% 	



% 	Fkm1 = single(F0);
% 	Fk = single(F(:,:,k,:));

% 		Fk = arrayfun( @arFilterKernel1, F(:,:,k,:), Fkm1, A);
% 		Fout(:,:,k,:) = Fk;
% 		Fkm1 = Fk;

% 	F0 = cast(Fkm1,'like',F0);

% 		Fk = arrayfun( @arFilterKernel2, F(:,:,k,:), Fkm1, Fkm2, A);
% 		Fout(:,:,k,:) = Fk;
% 		Fkm2 = Fkm1;
% 		Fkm1 = Fk;

% 	F0 = cast(cat(3, Fkm2, Fkm1),'like',F0);


% 		yk = uint16((1-a)*single(xk) + a*single(ykm1));

% 		yk = uint16((1-a)^2*single(xk) + 2*a*single(ykm1) - a^2*single(ykm2));

% F = cast(Fout, 'like',F);



% [fMin,fMax,fM1,fM2,fM3,fM4,N] = arrayfun(@statUpdateLoopInternalKernelFcn, rowSubs, colSubs, Na, chanSubs);
% 	function [fmin,fmax,m1,m2,m3,m4,n] = temporalStabilityKernelFcn(f0, rowC, colC, frameC, chanC)
% 		function a = normalizedSpatialGradientMagnitudeKernelFcn(fIn, rowC, colC, frameC, chanC)

% [difMean,difMax] = arrayfun(@statUpdateLoopInternalKernelFcn, Fbuf, rowSubs, colSubs, frameSubs, chanSubs);

% 			out1 = dfNeighMax/fNeighMax;
% 			out2 = meanSpatialDiff/fNeighMax;


% 			dfMax = single(0);
% 			dfMin = single(0);
% 			dfSum = single(0);
% 			fkm1 = fCC;
% 			dfkm1 = single(0);
% 			k = 0;
% 			while k < numFrames
%
% 				% UPDATE SAMPLE INDICES (USUALLY TEMPORAL)
% 				k = k + 1;
%
% 				% GET PIXEL SAMPLE
% 				fk = single(F(rowC,colC,k,chanC));
%
% 				% UPDATE MIN/MAX
% 				dfk = (fk - fkm1)/max(fk,fCC);
% 				dfMax = max( dfMax, dfk);
% 				dfMin = min( dfMin, dfk);
% 				dfSum = dfSum + abs(dfk-dfkm1);
%
% 				fkm1 = fk;
% 				dfkm1 = dfk;
%
% 				% 				dk = d/n;
% 				% 				dk2 = dk^2;
% 				% 				s = d*dk*(n-1);
% 				% 				m1 = m1 + dk;
% 				% 				m4 = m4 + s*dk2*(n^2-3*n+3) + 6*dk2*m2 - 4*dk*m3;
% 				% 				m3 = m3 + s*dk*(n-2) - 3*dk*m2;
% 				% 				m2 = m2 + s;
% 			end
%
% 			dfRange = (dfMax - dfMin)/max(dfMax,-dfMin);
% 			dfMean = dfSum/single(numFrames);
%


% COMPUTE BASIC STATISTICS FOR INTENSITY VALUES
% fNeighMax = max(max(max(max(max(max(max(max(f,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
% fNeighMin = min(min(min(min(min(min(min(min(f,fUL),fUC),fUR),fCL),fCR),fDL),fDC),fDR);
% fNeighRange = max(fNeighMax - fNeighMin, 1);
%
% fBright = 1 - (fNeighMax - f)/fNeighRange;
% fDark = 1 - (f - fNeighMin)/fNeighRange;
%
%
% % COMPUTE BASIC STATISTICS FOR INTENSITY VALUES
% dfNeighMax = max(max(max(max(max(max(max(abs(dfUL),abs(dfUC)),abs(dfUR)),abs(dfCL)),abs(dfCR)),abs(dfDL)),abs(dfDC)),abs(dfDR));
% dfNeighMin = min(min(min(min(min(min(min(abs(dfUL),abs(dfUC)),abs(dfUR)),abs(dfCL)),abs(dfCR)),abs(dfDL)),abs(dfDC)),abs(dfDR));
% dfNeighRange = max(fNeighMax - fNeighMin, 1);



% 			dfUL = f0 - single(F0(rowU, colL, 1, c));
% 			dfUC = f0 - single(F0(rowU, colC, 1, c));
% 			dfUR = f0 - single(F0(rowU, colR, 1, c));
% 			dfCL = f0 - single(F0(rowC, colL, 1, c));
% 			dfCR = f0 - single(F0(rowC, colR, 1, c));
% 			dfDL = f0 - single(F0(rowD, colL, 1, c));
% 			dfDC = f0 - single(F0(rowD, colC, 1, c));
% 			dfDR = f0 - single(F0(rowD, colR, 1, c));






