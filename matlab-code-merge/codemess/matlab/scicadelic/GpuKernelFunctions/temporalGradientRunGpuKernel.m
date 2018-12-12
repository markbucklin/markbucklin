function [Ft, varargout] = temporalGradientRunGpuKernel(F, F0, T, T0)
%
% 



% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
[numRows, numCols, numFrames, numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs = reshape(int32(gpuArray.colon(1,numChannels)), 1,1,1,numChannels);

if nargin < 4
	T0 = [];
	if nargin < 3
		T = [];
		if nargin < 2
			F0 = [];
		end
	end
end
if isempty(F0)
	F0 = cast(single(mean(F(:,:,1:2,:),3)) - diff(single(F(:,:,1:2,:)),[],3),'like',F);
end

% new
if isempty(T)
	T = single(frameSubs);
end
if isempty(T0)
	T0 = T(1) - T(2);
end
T = reshape(T, 1,1,numFrames,[]);


% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
Ft = arrayfun( @temporalGradientKernel, rowSubs, colSubs, frameSubs, chanSubs);


if nargout > 1
	varargout{1} = F(:,:,end,:);
	if nargout > 2
		varargout{2} = T(end);
	end
end



% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function ft = temporalGradientKernel(rowIdx, colIdx, frameIdx, chanIdx)
		
		% GET CURRENT PIXEL
		fk = single(F(rowIdx, colIdx, frameIdx, chanIdx));
		tk = single(T(1, 1, frameIdx, 1)); % new (multichannel todo??)
		
		% GET PREVIOUS PIXEL
		if frameIdx > 1			
			fkm1 = single(F(rowIdx, colIdx, frameIdx-1, chanIdx));
			tkm1 = single(T(1,1,frameIdx-1,1));
		else
			fkm1 = single(F0(rowIdx, colIdx, 1, chanIdx));
			tkm1 = single(T0);
		end
		
		% SUBTRACT
		ft = (fk - fkm1) / (tk - tkm1);
		
	end







end















