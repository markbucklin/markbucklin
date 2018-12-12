function F = blendColorCompositeRunGpuKernel(As, Cs, Fbg)
%
% >> F = blendColorCompositeRunGpuKernel(F, .75)
% >> [F, Fbuf] = blendColorCompositeRunGpuKernel(F, .75)
% >> [F, Fbuf] = blendColorCompositeRunGpuKernel(F, .75, Fbuf)
% >> [F, Fbuf] = blendColorCompositeRunGpuKernel(F, A, Fbuf)


% ============================================================
% PROCESS INPUT - FILL DEFAULTS
% ============================================================
if nargin < 3
	Fbg = [];
	if nargin < 2
		Cs = [];
	end
end


% RESHAPE INPUT ALPHA IMAGES TO [MxNx1xK]
if (ndims(As) < 4)
	[numRows, numCols, dim3] = size(As);
	numLayers = 1;
	numFrames = dim3;
	As = reshape(As, numRows, numCols, 1, numFrames);
		
else
	[numRows, numCols, numFrames, numLayers] = size(As);
	As = reshape(As, numRows, numCols, 1, numFrames, numLayers);
	
	% 	if (dim3 < 3) || (dim3 > 4)
	% 		numFrames = dim3;
	% 		numLayers = dim4;
	% 		As = reshape(As, numRows, numCols, 1, numFrames, numLayers);
	% 	else
	% 		numLayers = 1;
	% 		numFrames = dim4;
	% 		% TODO
	% 	end
	
end


if isempty(Fbg)
	Fbg = gpuArray.zeros(numRows, numCols, 3, numFrames, numLayers, 'single');
end
if (ndims(Fbg) < 4)
	[numRows, numCols, dim3] = size(Fbg);
	if (dim3 == numFrames)
		Fbg = reshape(Fbg, numRows, numCols, 1, numFrames);
	end
end


% DEFAULT COLORS
if isempty(Cs)
	Cs = gpuArray(reshape(single([.8 .1 .1]), 1, 1, 3));%TODO
	
elseif (size(Cs,1) < numRows) && (numel(Cs) > 1)	
	Cs = reshape(Cs, 1, 1, 3, 1, numLayers);
	
end


[numRows, numCols, ~, numFrames, numLayers] = size(As);
numChannels = size(Cs,3);






% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
% if size(Fbg,3) <3
% 	if isempty(C0)
% 		if numLayers == 3
% 			cGray = .5 * gpuArray(single( [1 1 1]));
% 		else
% 			cGray =  gpuArray(single( [.5 .5 .5 1]));
% 		end
% 		C0 = reshape( cGray, 1, 1, numLayers, 1, numChannels);
% 	end
	
	F = arrayfun(@blendOver, As, Cs, Fbg);
	
% else
% 	F = arrayfun(@blendOverBlend, As, Cs, Fbg);
	
% end








% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% FIRST-ORDER ################################################
% ============================================================
function f = blendOver(As, Cs, Cd)

	f = As*Cs + (1-As)*Cd;
% f = (c1*a1 + c0*(1-a1)) / (a1 + a0*(1-a1));

end

% ============================================================
% SECOND-ORDER ###############################################
% ============================================================
% function f1 = blendOverBlend(a1, c1, f0)
% 
% f1 = a1*c1 + f0*(1-a1);
% 
% 
% end



end
























