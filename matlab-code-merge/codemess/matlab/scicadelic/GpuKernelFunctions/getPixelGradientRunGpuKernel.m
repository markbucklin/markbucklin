function [df, varargout] = getPixelGradientRunGpuKernel(F, F0, getMagDir, rowSubs, colSubs, frameSubs)
%
% Note: Spatial gradients use the central-difference approximation while the temporal gradient (3rd
% dimension) is computed using direct causal difference between each frame & the previous frame.







% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames, numChannels] = size(F);
chanSubs = reshape(int32(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);
if nargin < 4
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
	frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
	if nargin < 3
		getMagDir = [];
		if nargin < 2
			F0 = [];
		end
	end
end
if isempty(F0)
	F0 = F(:,:,1,:);
end
if isempty(getMagDir)
	getMagDir = false;
end


% ============================================================
% CONCATENATE F WITH PREVIOUS (BUFFERED) FRAME
% ============================================================
F = cat(3, F0, F);
frameSubs = frameSubs + 1;


% ============================================================
% ALSO RETURN SECOND-ORDER SPATIAL DERIVATIVES (Fxx, Fyy, Fxy)
% ============================================================
getSecondOrderOutput = nargout>1;



% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
if ~getSecondOrderOutput
	if ~getMagDir
		[df.x, df.y, df.t] = arrayfun( @gradientFirstOrderKernel,...
			rowSubs, colSubs, frameSubs, chanSubs);
	else
		[df.x, df.y, df.t, df.r, df.w] = arrayfun( @gradientFirstOrderMagDirKernel,...
			rowSubs, colSubs, frameSubs, chanSubs);
	end
	
else
	[df.x, df.y, df.t, d2f.xx, d2f.yy, d2f.xy] = arrayfun( @gradientSecondOrderKernel,...
		rowSubs, colSubs, frameSubs, chanSubs);
	varargout{1} = d2f;
	
end








% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% FIRST-ORDER ################################################
% ============================================================
	function [fx, fy, ft] = gradientFirstOrderKernel(rowC, colC, k, c)
		% GET CENTRAL PIXEL (current frame & previous frame)
		fCC = single(F(rowC, colC, k, c));
		fCCkm1 = single(F(rowC, colC, k-1, c));
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = int32(max( 1, rowC-1));
		rowD = int32(min( numRows, rowC+1));
		colL = int32(max( 1, colC-1));
		colR = int32(min( numCols, colC+1));
		
		% RETRIEVE NON-LOCAL (REGIONAL) SAMPLES
		%			TODO: if odd/even get HV-neighbors or Corner-Neighbors
		fUC = single(F(rowU, colC, k, c));
		fCL = single(F(rowC, colL, k, c));
		fCR = single(F(rowC, colR, k, c));
		fDC = single(F(rowD, colC, k, c));
		
		% COMPUTE 1ST ORDER GRADIENTS (CENTRAL-DIFFERENCE APPROX.)
		fx = .5*(fCR - fCL);
		fy = .5*(fDC - fUC);
		ft = fCC - fCCkm1;
		
	end

% ============================================================
% FIRST-ORDER WITH MAGNITUDE & DIRECTION #####################
% ============================================================
	function [fx, fy, ft, fr, fw] = gradientFirstOrderMagDirKernel(rowC, colC, k, c)
		% GET CENTRAL PIXEL
		fCC = single(F(rowC, colC, k, c));
		fCCkm1 = single(F(rowC, colC, k-1, c));
		
		% SUBSCRIPTS FOR SURROUNDING-PIXELS
		rowU = int32(max( 1, rowC-1));
		rowD = int32(min( numRows, rowC+1));
		colL = int32(max( 1, colC-1));
		colR = int32(min( numCols, colC+1));
		
		% REGIONAL SAMPLES
		% 		fUL = single(F(rowU, colL, k, c));
		fUC = single(F(rowU, colC, k, c));
		% 		fUR = single(F(rowU, colR, k, c));
		fCL = single(F(rowC, colL, k, c));
		fCR = single(F(rowC, colR, k, c));
		% 		fDL = single(F(rowD, colL, k, c));
		fDC = single(F(rowD, colC, k, c));
		% 		fDR = single(F(rowD, colR, k, c));
		
		% COMPUTE 1ST ORDER GRADIENTS
		fx = .5*(fCR - fCL);
		fy = .5*(fDC - fUC);
		ft = fCC - fCCkm1;
		fr = sqrt(fx^2 + fy^2);
		fw = atan2(fy,fx);
		
		
	end

% ============================================================
% FIRST- & SECOND ORDER ######################################
% ============================================================
	function [fx, fy, ft, fxx, fyy, fxy] = gradientSecondOrderKernel(rowC, colC, k, c)
		% GET CENTRAL PIXEL
		fCC = single(F(rowC, colC, k, c));
		fCCkm1 = single(F(rowC, colC, k-1, c));
		
		% SUBSCRIPTS FOR SURROUNDING-PIXELS
		rowU = int32(max( 1, rowC-1));
		rowD = int32(min( numRows, rowC+1));
		colL = int32(max( 1, colC-1));
		colR = int32(min( numCols, colC+1));
		
		% REGIONAL SAMPLES
		fUL = single(F(rowU, colL, k, c));
		fUC = single(F(rowU, colC, k, c));
		fUR = single(F(rowU, colR, k, c));
		fCL = single(F(rowC, colL, k, c));
		fCR = single(F(rowC, colR, k, c));
		fDL = single(F(rowD, colL, k, c));
		fDC = single(F(rowD, colC, k, c));
		fDR = single(F(rowD, colR, k, c));
		
		% COMPUTE 1ST ORDER GRADIENTS
		fx = .5*(fCR - fCL);
		fy = .5*(fDC - fUC);
		ft = fCC - fCCkm1;
		
		% COMPUTE 2ND ORDER GRADIENTS
		fxx = fCR + fCL - 2*fCC;
		fyy = fUC + fDC - 2*fCC;
		fxy = .25*(fUL + fDR - fDL - fUR);
		
		
	end
end















