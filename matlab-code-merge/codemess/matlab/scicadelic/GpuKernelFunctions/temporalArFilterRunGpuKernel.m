function [Fout, varargout] = temporalArFilterRunGpuKernel(Fin, A, Fbuf, Na)
%
% >> F = temporalArFilterRunGpuKernel(F, .75)
% >> [F, Fbuf] = temporalArFilterRunGpuKernel(F, .75)
% >> [F, Fbuf] = temporalArFilterRunGpuKernel(F, .75, Fbuf)
% >> [F, Fbuf] = temporalArFilterRunGpuKernel(F, A, Fbuf)


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
if nargin < 4
	Na = [];
	if nargin < 3
		Fbuf = [];
		if nargin < 2
			A = [];
		end
	end
end
[numRows, numCols, numFrames, numChannels] = size(Fin);
numPixels = numRows*numCols;
if isempty(A)
	A = .5;
end
if (numel(A) < numPixels) && (numel(A) > 1)
	A = reshape(A, 1, 1, [], numChannels);
end
if isempty(Na)
	Na = size(A,3);
end


% ============================================================
% PREALLOCATE OUTPUT & INITIALIZE BUFFERED OUTPUT
% ============================================================
Fout = zeros(numRows, numCols, numFrames, numChannels, 'like', Fin);
nBuff = size(Fbuf,3);
if isempty(Fbuf) || (nBuff < Na)
	Fbuf = repmat( Fin(:,:,1,:), 1,1,Na,1);
end
k = 1;


% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
if Na == 1
	% FIRST ORDER RECURSIVE FILTER		
	while k <= numFrames
		Fbuf = arrayfun( @arFilterKernel1, Fin(:,:,k,:), Fbuf, A);
		Fout(:,:,k,:) = Fbuf;
		k=k+1;
	end
	
elseif Na ==2
	% SECOND ORDER RECURSIVE FILTER	
	Fkm1 = Fbuf(:,:,2,:);
	Fkm2 = Fbuf(:,:,1,:);
	while k <= numFrames
		Fk = arrayfun( @arFilterKernel2, Fin(:,:,k,:), A, Fkm1, Fkm2);
		Fout(:,:,k,:) = Fk;
		Fkm2 = Fkm1;
		Fkm1 = Fk;
		k=k+1;
	end
	Fbuf = cat(3, Fkm2, Fkm1);

else
	% N ORDER RECURSIVE FILTER
	rowSubs = int32(gpuArray.colon(1,numRows)');
	colSubs = int32(gpuArray.colon(1,numCols));
	frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
	chanSubs = reshape(int32(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);
	[aRows,aCols,Na,aChannels] = size(A);
	
	% NORMALIZE A
	aFactorial = sum( bsxfun(@times, A, reshape(Na:-1:1, 1,1,Na,1)), 3);
	A = bsxfun(@rdivide, A, aFactorial);
	F = single(Fin);
	while k <= numFrames
		Fk = arrayfun( @arFilterKernelN, F(:,:,k,:), rowSubs, colSubs, chanSubs);
		Fout(:,:,k,:) = Fk;
		Fbuf = cat(3, Fbuf(:,:,2:end,:), Fk);
		k=k+1;
	end
	Fout = cast(Fout, 'like',Fin);
end



if nargout > 1
	varargout{1} = Fbuf;
end









% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% FIRST-ORDER ################################################
% ============================================================
	function yk = arFilterKernel1(xk, ykm1, a)
		% Recursive  filter along third dimension (presumably time)
		
		yk = (1-a)*xk + a*ykm1;
		
	end

% ============================================================
% SECOND-ORDER ###############################################
% ============================================================
	function yk = arFilterKernel2(xk, a, ykm1, ykm2)
		% Recursive  filter along third dimension (presumably time)
		% 		a1 = A( min(m,aRows), min(n,aCols), 1, min(c,aChannels));
		
		% 		ykm1 = Fbuf(m,n,1,c);
		% 		ykm1 = Fbuf(m,n,1,c);
		yk = (1-a)^2*xk + 2*a*ykm1 - a^2*ykm2;
		
	end

% ============================================================
% N-ORDER ####################################################
% ============================================================
	function yk = arFilterKernelN(xk, m, n, c)
		% Recursive  filter along third dimension (presumably time)
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
























