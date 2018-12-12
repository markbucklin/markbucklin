function [Fout, varargout] = temporalMedianFilterRunGpuKernel(Fin, orderSpec)
%
% >> F = temporalMedianFilterRunGpuKernel(F)
% >> [F, Fbuf] = temporalMedianFilterRunGpuKernel(F)
% >> [F, Fbuf] = temporalMedianFilterRunGpuKernel(F, 4)
% >> [F, Fbuf] = temporalMedianFilterRunGpuKernel(F, Fbuf)
% 
% NOT YET WORKING: TODO


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
if nargin < 2
	orderSpec = [];
end
if isempty(orderSpec)
	orderSpec = 3;
end
[numRows, numCols, numFrames, numChannels] = size(Fin);
numPixels = numRows*numCols;
if isinteger(Fin)
	minVal = intmin(class(Fin));
	maxVal = intmax(class(Fin));
else
	minVal = single(-inf);
	maxVal = single(inf);
end



% ============================================================
% PREALLOCATE OUTPUT & INITIALIZE BUFFERED OUTPUT
% ============================================================
Fout = zeros(numRows, numCols, numFrames, numChannels, 'like', Fin);
if (numel(orderSpec) < numPixels)
	N = orderSpec;
	Fbuf = repmat( Fin(:,:,1,:), 1,1,N-1,1);
else
	Fbuf = orderSpec;
	N = size(Fbuf,3)+1;
end
% NOT YET WORKING!!!!!!!!!!!!!

% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs = reshape(int32(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);
Fout = arrayfun( @medianFilterKernel, rowSubs, colSubs, frameSubs, chanSubs);


if nargout > 1	
	varargout{1} = Fin(:,:,end-N+1:end,:);
end









% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% N-ORDER ####################################################
% ============================================================
	function fk = medianFilterKernel(m, n, k, c)
		% Parallel filter along third dimension (presumably time)
		fk = Fin(m,n,k,c);		
		numgt=int8(0);
		numlt=int8(0);
		q = 1;
		flt = minVal;
		fgt = maxVal;
		while q < N
			kmq = k-q;
			if kmq >= 1
				fkm = Fin(m,n,kmq,c);
			else
				qbuf = N-kmq+1;
				fkm = Fbuf(m,n,qbuf,c);
			end
			
			% 			if numgt>numlt
			% 				fk = max(fk, min(fgt,fkm));
			% 			elseif numlt>numgt
			% 			end
			
			isgt = fkm>=fk;
			islt = fkm<=fk;
			if isgt
				fgt = min(fgt, fkm);
			elseif islt
				flt = max(flt, fkm);
			end
			
			numgt = numgt + int8(isgt);
			numlt = numlt + int8(islt);
			
			fgt = max(fk, min(fgt,fkm));
			fk = min(fkm,fk);

			
			
			if numgt >= numlt
				flt = fk;
				fgt = min(fgt, fkm);
				fk = max(fgt, fkm);				
			else
				fgt = fk;
				fk = max(flt, fkm);
				flt = min(flt, fkm);
			end
		end
		
		
		
		b = single(1);
		yk = single(0);
		q = 1;
		% 		aqprev = single(0);
		while q <= Na
			aq = A( min(m,aRows), min(n,aCols), q, min(c,aChannels));
			b = b*(1-aq);
			ykmq = single(Fbuf(m,n,q,c));
			yk = yk + aq*ykmq;
			q = q + 1;
		end
		yk = yk + single(xk)*b;
		
		% 		ykm1 = Fbuf(m,n,1,c);
		% 		ykm1 = Fbuf(m,n,1,c);
		% 		yk = (1-a)^2*xk + 2*a*ykm1 - a^2*ykm2;
		
	end


end
























