function [eigval1, eigval2, eigvec1dir] = structureTensorEigDecompRunGpuKernel(Finput, preSmooth, rowSubs, colSubs, frameSubs)
%
% DESCRIPTION:
%		Similar to computeSurfaceCharacterRunGpuKernel Computes 1st & 2nd order spatial gradients, then
%		uses these to construct Structure and Diffusion tensors. The eigen-decomposition of the
%		diffusion tensor (hessian) will then return the gaussian & mean curvature at each pixel, as well
%		as the principal curvatures (1st & 2nd eigen-values). The second (optional) input argument - if
%		set to TRUE - applies a gaussian smoothing operation to the input.
% 
% 
% USAGE:
%		>> [k1,k2,w1] = structureTensorEigDecompRunGpuKernel(F);
%		>> [k1,k2,w1] = structureTensorEigDecompRunGpuKernel(F, true);
%
%
% ALGORITHM:
%		% Gaussian Curvature (direction independent)
%		K = (fxx .* fyy - fxy.^2)...
%			./ (1 + fx.^2 + fy.^2).^2;
%		% Mean Curvature (direction independent)
%		H = ( (1+fy.^2).*fxx + (1+fx.^2).*fyy - 2*fx.*fy.*fxy)...
%			./ (2*(1 + fx.^2 + fy.^2) .^(3/2));
%		% Principal Curvature k1, k2 (associated with direction)
%		k1 = H + sqrt(H.^2 - K);
%		k2 = H - sqrt(H.^2 - K);
%		% First Eigen Vector [u1, v1]
%		u1 = k1 - fyy;	%		or fxy
%		v1 = fxy;		%		or	k1-fxx
%		% Second Eigen Vector [u2, v2]
%		u2 = k2 - fyy;
%		v2 = fxy;
%
%
% SEE ALSO:
%		COMPUTESURFACECHARACTERRUNGPUKERNEL
%


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames, numChannels] = size(Finput);
chanSubs = reshape(int32(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);
if nargin < 4
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
	frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
	if nargin < 2
		preSmooth = [];		
	end
end
if isempty(preSmooth)
	preSmooth = false;
end

% ============================================================
% SMOOTH WITH GAUSSIAN KERNEL IF SPECIFIED
% ============================================================
if preSmooth
	hsigma = 1.5;
	hsize = 2*ceil(2*hsigma) + 1;
	 F = imgaussfilt3(single(Finput), [hsigma hsigma 1],...
		 'FilterSize', [hsize hsize 1],...
		 'Padding', 'replicate',...
		 'FilterDomain', 'spatial');
	% 	F = gaussFiltFrameStack(Finput,1.5);
else
	F = single(Finput);
end


% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
% RETURN EIGENVECTORS AND EIGENVALUES
[eigval1, eigval2, eigvec1dir] = arrayfun(...
	@structureTensorEigDecompKernel, rowSubs, colSubs, frameSubs, chanSubs);











% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% SURFACE-CLASSIFICATION & INTERMEDIATE RESULTS ONLY #########
% ============================================================
function [k1, k2, w1] = structureTensorEigDecompKernel(rowIdx, colIdx, frameIdx, chanIdx)
		
		% GET CENTRAL PIXEL (current frame & previous frame)
		f = single(F(rowIdx, colIdx, frameIdx, chanIdx));
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS
		rowU = int32(max( 1, rowIdx-1));
		rowD = int32(min( numRows, rowIdx+1));
		colL = int32(max( 1, colIdx-1));
		colR = int32(min( numCols, colIdx+1));
		
		% RETRIEVE NEIGHBORING PIXEL VALUES		
		fUL = single(F(rowU, colL, frameIdx, chanIdx));
		fUC = single(F(rowU, colIdx, frameIdx, chanIdx));
		fUR = single(F(rowU, colR, frameIdx, chanIdx));
		fCL = single(F(rowIdx, colL, frameIdx, chanIdx));
		fCR = single(F(rowIdx, colR, frameIdx, chanIdx));
		fDL = single(F(rowD, colL, frameIdx, chanIdx));
		fDC = single(F(rowD, colIdx, frameIdx, chanIdx));
		fDR = single(F(rowD, colR, frameIdx, chanIdx));
		
		% COMPUTE 1ST ORDER GRADIENTS (CENTRAL-DIFFERENCE APPROX.)
		fx = .5*(fCR - fCL);
		fy = .5*(fDC - fUC);
		
		% COMPUTE 2ND ORDER GRADIENTS
		fxx = fCR + fCL - 2*f;
		fyy = fUC + fDC - 2*f;
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
		
		% ALSO RETURN DIRECTION OF PRINCIPAL EIGEN VECTOR		
		if fxy == 0
			w1 = single(0);
		else
			u1 = k1 - fyy;
			v1 = fxy;
			w1 = atan2(v1,u1);
			% 			u2 = k2 - fyy;
			% 			v2 = fxy;
			
		end
	end

	

end














