function [Fout, varargout] = temporalArFilter(Fin, A, Fbuf)
%
% >> F = temporalArFilter(F, .75)
% >> [F, Fbuf] = temporalAr(F, .75)
% >> [F, Fbuf] = temporalArFilter(F, .75, Fbuf)
% >> [F, Fbuf] = temporalArFilter(F, A, Fbuf)
%
% SEE ALSO:
%			TEMPORALARFILTERRUNGPUKERNEL



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
if nargin < 3
	Fbuf = [];
end
[numRows, numCols, numFrames, numChannels] = size(Fin);
numPixels = numRows*numCols;
if (numel(A) < numPixels) && (numel(A) > 1)
	A = reshape(A, 1, 1, [], numChannels);
end
if isempty(Fbuf) %|| (nBuff < N)
	% 	Fbuf = repmat( Fin(:,:,1,:), 1,1,N,1);
	Fbuf = Fin(:,:,1,:);
end

% ALLOCATE OUTPUT
Fout = zeros(numRows, numCols, numFrames, numChannels, 'like', Fin);

% ENSURE A & FBUF ARE ON GPU
A = ongpu(A);
Fbuf = ongpu(Fbuf);


% ============================================================
% RUN RECURSIVE FUNCTION ON DATA (TRANSFERRING TO GPU IF NECESSARY)
% ============================================================
k = 1;
if isa(Fin, 'gpuArray')
	while k <= numFrames
		Fbuf = arrayfun( @arFilterKernel, Fin(:,:,k,:), Fbuf, A);
		Fout(:,:,k,:) = Fbuf;
		k=k+1;
	end
	
else
	dev = gpuDevice;	
	numBlocks = 1 + floor(8*MB(Fin)/ dev.AvailableMemory/(2^20));
	framesPerBlock = numFrames/numBlocks;
	idx = 0;
	
	% TRANSFER BLOCK BY BLOCK TO GPU (EFFICIENT TRANSFERS TO USE AVAILABLE BANDWIDTH)
	while idx(end) < numFrames
		idx = idx(end) + (1:framesPerBlock);
		idx = idx(idx<=numFrames);
		F = gpuArray(Fin(:,:,idx,:));
		k=1;
		
		% RUN BLOCK
		while k <= numel(idx)
			Fbuf = arrayfun( @arFilterKernel, F(:,:,k,:), Fbuf, A);
			F(:,:,k,:) = Fbuf;
			k=k+1;
		end
		
		% RETRIEVE BLOCK FROM GPU
		Fout(:,:,idx,:) = gather(F);
		
	end	
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
	function yk = arFilterKernel(xk, ykm1, a)
		% Recursive  filter along third dimension (presumably time)
		
		yk = (1-a)*xk + a*ykm1;
		
		
		
	end





end