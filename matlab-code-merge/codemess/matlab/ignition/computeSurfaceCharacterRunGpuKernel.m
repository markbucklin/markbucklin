function varargout = computeSurfaceCharacterRunGpuKernel(Finput, classifySurfaceType, preSmooth, rowSubs, colSubs, frameSubs)
%
% DESCRIPTION:
%		Computes 1st & 2nd order spatial gradients, then uses these to construct Structure and Diffusion
%		tensors. The eigen-decomposition of the diffusion tensor (hessian) will then return the gaussian &
%		mean curvature at each pixel, as well as the principal curvatures (1st & 2nd eigen-values).
% 
%		Will also or alternatively return an encoded "surface-classification" matrix with the following
%		encoding scheme (Besl):
%			1: Peak
%			2: Ridge
%			3: Saddle Ridge
%			4: Minimal
%			5: Saddle Valley
%			6: Valley
%			7: Pit
%			8: Flat
%
%
% USAGE:
%		>> s = computeSurfaceCharacterRunGpuKernel(F)
%		>> [s, surfType] = computeSurfaceCharacterRunGpuKernel(F)
%		>> surfType = computeSurfaceCharacterRunGpuKernel(F, true)
%		>> [...] = computeSurfaceCharacterRunGpuKernel(F, classifySurfaceType, preSmooth)
%
%
% ALGORITHM:
%		% Gaussian Curvature (direction independent)
%		K = (d2f.xx .* d2f.yy - d2f.xy.^2)...
%			./ (1 + df.x.^2 + df.y.^2).^2;
%		% Mean Curvature (direction independent)
%		H = ( (1+df.y.^2).*d2f.xx + (1+df.x.^2).*d2f.yy - 2*df.x.*df.y.*d2f.xy)...
%			./ (2*(1 + df.x.^2 + df.y.^2) .^(3/2));
%		% Principal Curvature k1, k2 (associated with direction)
%		k1 = H + sqrt(H.^2 - K);
%		k2 = H - sqrt(H.^2 - K);
%		% Surface-Type Encoding Function
%		surfClass = uint8(1 + 3*(1 + sign(H)) + (1-sign(K)));
%
%
% SEE ALSO: 
%		STRUCTURETENSOREIGDECOMPRUNGPUKERNEL, GETPIXELGRADIENTRUNGPUKERNEL
%


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames, numChannels] = size(Finput);
if nargin < 4
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
	frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
	chanSubs = int32(reshape(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);
	if nargin < 3
		preSmooth = [];
		if nargin < 2
			classifySurfaceType = [];
		end
	end
end
if isempty(classifySurfaceType)
	classifySurfaceType = nargout >= 2;
end
if isempty(preSmooth)
	preSmooth = false;
end


% ============================================================
% ALSO RETURN SPATIAL DERIVATIVES & INTERMEDIATE RESULTS
% ============================================================
returnIntermediateResults = (nargout>1) || ((nargout==1)&&(~classifySurfaceType)) ;
returnMapAndIntermediate = classifySurfaceType && returnIntermediateResults;
if preSmooth
	F = gaussFiltFrameStack(Finput,1.5);
else
	F = single(Finput);
end


% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
if returnMapAndIntermediate
	% RETURN SURFACE CLASSIFICATION & INTERMEDIATE CHARACTERIZATION DATA
	[surfType, s.fx, s.fy, s.fxx, s.fyy, s.fxy, s.K, s.H, s.k1, s.k2] = arrayfun(...
			@surfClassAndIntermediatesKernel, rowSubs, colSubs, frameSubs, chanSubs);		
		varargout{1} = s;
		varargout{2} = surfType;
	
else	
	if returnIntermediateResults
		% ONLY RETURN SURFACE CHARACTERIZATION DATA (GRADIENTS, CURVATURE, EIGENVALUES, ETC)
		[s.fx, s.fy, s.fxx, s.fyy, s.fxy, s.K, s.H, s.k1, s.k2] = arrayfun(...
			@intermediateResultsOnlyKernel, rowSubs, colSubs, frameSubs, chanSubs);
		varargout{1} = s;
		
	else
		% ONLY RETURN A CONDENSED/ENCODED MAP IDENTIFYING THRESHOLDED CLASSIFICATION
		surfType = arrayfun( @surfaceClassificationOnlyKernel, rowSubs, colSubs, frameSubs, chanSubs);
		varargout{1} = surfType;
	end	

end







% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% SURFACE-CLASSIFICATION & INTERMEDIATE RESULTS ONLY #########
% ============================================================
function [surfClass, fx, fy, fxx, fyy, fxy, K, H, k1, k2] = surfClassAndIntermediatesKernel(rowC, colC, n, c)
		
		% GET CENTRAL PIXEL (current frame & previous frame)
		fCC = single(F(rowC, colC, n, c));
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS
		rowU = int32(max( 1, rowC-1));
		rowD = int32(min( numRows, rowC+1));
		colL = int32(max( 1, colC-1));
		colR = int32(min( numCols, colC+1));
		
		% RETRIEVE NEIGHBORING PIXEL VALUES		
		fUL = single(F(rowU, colL, n, c));
		fUC = single(F(rowU, colC, n, c));
		fUR = single(F(rowU, colR, n, c));
		fCL = single(F(rowC, colL, n, c));
		fCR = single(F(rowC, colR, n, c));
		fDL = single(F(rowD, colL, n, c));
		fDC = single(F(rowD, colC, n, c));
		fDR = single(F(rowD, colR, n, c));
		
		% COMPUTE 1ST ORDER GRADIENTS (CENTRAL-DIFFERENCE APPROX.)
		fx = .5*(fCR - fCL);
		fy = .5*(fDC - fUC);
		
		% COMPUTE 2ND ORDER GRADIENTS
		fxx = fCR + fCL - 2*fCC;
		fyy = fUC + fDC - 2*fCC;
		fxy = .25*(fUL + fDR - fDL - fUR);
		
		% INTERMEDIATE TENSOR OPERANDS		
		fx2 = fx^2;
		fy2 = fy^2;
		fxy2 = fxy^2;
		Jtrace = 1 + fx2 + fy2;
		
		% GAUSSIAN CURVATURE (direction independent)
		K = (fxx*fyy - fxy2) / (Jtrace)^2;
		
		% MEAN CURVATURE (direction independent) & CURVATURE MAGNITUDE
		H = ( (1+fy2)*fxx + (1+fx2)*fyy - 2*fx*fy*fxy ) / (2*(Jtrace)^(3/2));
		CM = realsqrt( 1 + max(0, H^2 - K)) - 1;
		
		% PRINCIPAL CURVATURE k1, k2 (associated with direction)
		k1 = H + CM;
		k2 = H - CM;
		
		% ENCODE SIGN OF SURFACE DESCRIPTORS IN BIT-PACKED MATRIX
		surfClass = uint8(1 + 3*(1 + sign(H)) + (1-sign(K)));
		
	end

% ============================================================
% INTERMEDIATE RESULTS ONLY ##################################
% ============================================================
	function [fx, fy, fxx, fyy, fxy, K, H, k1, k2] = intermediateResultsOnlyKernel(rowC, colC, n, c)
		
		% GET CENTRAL PIXEL (current frame & previous frame)
		fCC = single(F(rowC, colC, n, c));
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS
		rowU = int32(max( 1, rowC-1));
		rowD = int32(min( numRows, rowC+1));
		colL = int32(max( 1, colC-1));
		colR = int32(min( numCols, colC+1));
		
		% RETRIEVE NEIGHBORING PIXEL VALUES		
		fUL = single(F(rowU, colL, n, c));
		fUC = single(F(rowU, colC, n, c));
		fUR = single(F(rowU, colR, n, c));
		fCL = single(F(rowC, colL, n, c));
		fCR = single(F(rowC, colR, n, c));
		fDL = single(F(rowD, colL, n, c));
		fDC = single(F(rowD, colC, n, c));
		fDR = single(F(rowD, colR, n, c));
		
		% COMPUTE 1ST ORDER GRADIENTS (CENTRAL-DIFFERENCE APPROX.)
		fx = .5*(fCR - fCL);
		fy = .5*(fDC - fUC);
		
		% COMPUTE 2ND ORDER GRADIENTS
		fxx = fCR + fCL - 2*fCC;
		fyy = fUC + fDC - 2*fCC;
		fxy = .25*(fUL + fDR - fDL - fUR);
		
		% INTERMEDIATE TENSOR OPERANDS
		fx2 = fx^2;
		fy2 = fy^2;
		fxy2 = fxy^2;
		Jtrace = 1 + fx2 + fy2;
		
		% GAUSSIAN CURVATURE (direction independent)
		K = (fxx*fyy - fxy2) / (Jtrace)^2;
		
		% MEAN CURVATURE (direction independent) & CURVATURE MAGNITUDE
		H = ( (1+fy2)*fxx + (1+fx2)*fyy - 2*fx*fy*fxy ) / (2*(Jtrace)^(3/2));
		CM = realsqrt( 1 + max(0, H^2 - K)) - 1;
		
		% PRINCIPAL CURVATURE k1, k2 (associated with direction)
		k1 = H + CM;
		k2 = H - CM;
		
	end

% ============================================================
% SURFACE-CLASSIFICATION ONLY ################################
% ============================================================
	function surfClass = surfaceClassificationOnlyKernel(rowC, colC, n, c)
		
		% GET CENTRAL PIXEL (current frame & previous frame)
		fCC = single(F(rowC, colC, n, c));
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS
		rowU = int32(max( 1, rowC-1));
		rowD = int32(min( numRows, rowC+1));
		colL = int32(max( 1, colC-1));
		colR = int32(min( numCols, colC+1));
		
		% RETRIEVE NEIGHBORING PIXEL VALUES		
		fUL = single(F(rowU, colL, n, c));
		fUC = single(F(rowU, colC, n, c));
		fUR = single(F(rowU, colR, n, c));
		fCL = single(F(rowC, colL, n, c));
		fCR = single(F(rowC, colR, n, c));
		fDL = single(F(rowD, colL, n, c));
		fDC = single(F(rowD, colC, n, c));
		fDR = single(F(rowD, colR, n, c));
		
		% COMPUTE 1ST ORDER GRADIENTS (CENTRAL-DIFFERENCE APPROX.)
		fx = .5*(fCR - fCL);
		fy = .5*(fDC - fUC);
		
		% COMPUTE 2ND ORDER GRADIENTS
		fxx = fCR + fCL - 2*fCC;
		fyy = fUC + fDC - 2*fCC;
		fxy = .25*(fUL + fDR - fDL - fUR);
		
		% INTERMEDIATE TENSOR OPERANDS
		fx2 = fx^2;
		fy2 = fy^2;
		fxy2 = fxy^2;
		Jtrace = 1 + fx2 + fy2;
		
		% GAUSSIAN CURVATURE (direction independent)
		K = (fxx*fyy - fxy2) / (Jtrace)^2;
		
		% MEAN CURVATURE (direction independent) & CURVATURE MAGNITUDE
		H = ( (1+fy2)*fxx + (1+fx2)*fyy - 2*fx*fy*fxy ) / (2*(Jtrace)^(3/2));
		% 		CM = realsqrt( 1 + max(0, realpow(H,2) - K)) - 1;
		
		% PRINCIPAL CURVATURE k1, k2 (associated with direction)
		% 		k1 = H + CM;
		% 		k2 = H - CM;
		
		% ENCODE SIGN OF SURFACE DESCRIPTORS IN BIT-PACKED MATRIX
		surfClass = uint8(1 + 3*(1 + sign(H)) + (1-sign(K)));
		
	end

	

end














