






% NOT YET IN WORKING CONDITION






function [Fout, varargout] = temporalArmaFilterRunGpuKernel(Fin, B, A, Fbuf)
%
% >> F = temporalArmaFilterRunGpuKernel(0, .9, F)
% >> [F, Fbuf] = temporalArmaFilterRunGpuKernel(0, .9, F)
% >> [F, Fbuf] = temporalArmaFilterRunGpuKernel(0, .9, F, FbufOut)
% >> [F, Fbuf] = temporalArmaFilterRunGpuKernel(B, A, F, FbufOut, FbufIn)




% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
if nargin < 4
	Fbuf = [];
	if nargin < 3
		A = [];
	end
end
[numRows, numCols, numFrames, numChannels] = size(Fin);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs = reshape(int32(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);

Nb = size(B,3) - sum(all(all(B==0,1),2),3);
Na = size(A,3) - 1;
N = max(Na,Nb);
nBuff = size(Fbuf,3);
if isempty(Fbuf) || (nBuff < N)
	Fbuf = repmat( Fin(:,:,1,:), 1,1,N,1);
end




% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================

		Fout = arrayfun( @armaFilterKernel,...
			rowSubs, colSubs, frameSubs, chanSubs);

		
		if nargout > 1
			nextBufIdx = numFrames - Na + 1;			
			varargout{1} = Fout(:,:,nextBufIdx:end, :);
		end
	








% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% FIRST-ORDER ################################################
% ============================================================
	function fk = armaFilterKernel(m, n, t, c)
		
		% GET CENTRAL PIXEL (current frame & previous frame)
		fCC = single(Fin(m, n, t, c));
		fCCkm1 = single(Fin(m, n, t-1, c));
		
		% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
		rowU = int32(max( 1, m-1));
		rowD = int32(min( numRows, m+1));
		colL = int32(max( 1, n-1));
		colR = int32(min( numCols, n+1));
		
		% RETRIEVE NON-LOCAL (REGIONAL) SAMPLES
		%			TODO: if odd/even get HV-neighbors or Corner-Neighbors
		fUC = single(Fin(rowU, n, t, c));
		fCL = single(Fin(m, colL, t, c));
		fCR = single(Fin(m, colR, t, c));
		fDC = single(Fin(rowD, n, t, c));
		
		% COMPUTE 1ST ORDER GRADIENTS (CENTRAL-DIFFERENCE APPROX.)
		fx = .5*(fCR - fCL);
		fy = .5*(fDC - fUC);
		ft = fCC - fCCkm1;
		
	end

end




















