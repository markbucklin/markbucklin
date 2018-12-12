function [S, varargout] = computeBorderDistanceRunGpuKernel(R, S0, B0, rowSubs, colSubs, frameSubs)
% MEASURE A GEODESIC DISTANCE TO NEAREST LAYER TRANSITION ( --> and/or label transition?!?!?)
%
% >>	[borderDist, isPeak, isBorder] = explorePixelLayerRunGpuKernel(P, S0, rowSubs, colSubs, frameSubs)
%
% To Initialize:
% >>	[S0, B0, bStable] = computeBorderDistanceRunGpuKernel(R(:,:,1));
% >>	for k=2:size(R,3)
%				[S0, B0, bStable] = computeBorderDistanceRunGpuKernel(R(:,:,k), S0, B0); 
%			end



% ============================================================
% PROCESS INPUT - ASSIGN CONSTANTS & DEFAULTS
% ============================================================
[numRows, numCols, numFrames] = size(R);
diagDist = single(realsqrt(2));
if nargin < 2
	S0 = [];
end
if nargin < 3
	B0 = [];
end
if nargin < 4
	rowSubs = gpuArray.colon(1,numRows)';
	colSubs = gpuArray.colon(1,numCols);
	frameSubs = reshape(gpuArray.colon(1, numFrames), 1,1,numFrames);
end
if isempty(S0)
	S0 = single( sign(mean(R,3))*numRows*numCols);
	sequentialBurnIn = true;
else
	sequentialBurnIn = false;
end
if isempty(B0)
	B0 = gpuArray.zeros(numRows,numCols, 'int8');
else
	B0 = int8(B0);
end



% ============================================================
% CALL SUB-FUNCTION USING GPU/ARRAYFUN (COMPILES CUDA KERNEL)
% ============================================================
if sequentialBurnIn
	for n = 1:numel(frameSubs)
		kFrame = frameSubs(n);
		[S0, B0, ~] = arrayfun( @BorderDistKernel,...
			R(:,:,kFrame), S0, B0, rowSubs, colSubs, kFrame);
	end
end
[S, B, bStability] = arrayfun( @BorderDistKernel,...
	R, S0, B0, rowSubs, colSubs, frameSubs);



% ============================================================
% MANAGE OUTPUT
% ============================================================
if nargout>1
	varargout{1} = B;
	if nargout>2
		varargout{2} = bStability;
	end
end












% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function [sCC, bCC, bStable] = BorderDistKernel(rCC, sCC0, bCC0, rowC, colC, k)
		% Adds difference between current-pixel & neighbor with shortest path, to propagate/update shortest path to a zero-crossing
		% rCC  -> R(rowC,colC,n)
		% sCC0 -> S0(rowC,colC)
		% bCC0 -> B0(rowC,colC)
		
		% 		rCC = R(rowC, colC, k);
		
		if (sCC0 == 0)
			% INITIALIZATION
			sCC = .1*sign(rCC);%*numRows*numCols;			
			bCC = int8(0);
			bStable = false;
			
		else
			% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS
			rowU = max( 1, rowC-1);
			rowD = min( numRows, rowC+1);
			colL = max( 1, colC-1);
			colR = min( numCols, colC+1);
			
			% GET NEIGHBORHOOD (ADJACENT-PIXELS) LAYER PROBABILITY-VALUES
			rUL = R(rowU, colL, k);
			rUC = R(rowU, colC, k);
			rUR = R(rowU, colR, k);
			rCL = R(rowC, colL, k);
			rCR = R(rowC, colR, k);
			rDL = R(rowD, colL, k);
			rDC = R(rowD, colC, k);
			rDR = R(rowD, colR, k);
			
			% DETERMINE IF ANY LAYER-TRANSITION (ZERO-CROSSING) EXISTS BETWEEN PIXEL & NEIGHBORS
			rSign = sign(rCC);
			isBorder = (rSign ~= sign(rUL)) ...
				|| (rSign ~= sign(rUC)) ...
				|| (rSign ~= sign(rUR)) ...
				|| (rSign ~= sign(rCL)) ...
				|| (rSign ~= sign(rCR)) ...
				|| (rSign ~= sign(rDL)) ...
				|| (rSign ~= sign(rDC)) ...
				|| (rSign ~= sign(rDR)) ;
			%				ds = rPxSign - rPx;
			% 			ds = rPx;
			ds = single(rSign);
			
			% IF CURRENT PIXEL IS ADJACENT TO ANY EDGE/BORDER
			if isBorder
				% INITIALIZE TRANSITION-DISTANCE WITH PIXEL-LAYER-PROBABILITY VALUE (R)				
				% 				sCC = .25*ds;
				sCC = rCC;
				bCC = int8(rSign);		
				
				% RETURN LOGICAL INDICATION OF EDGE STABILITY
				bStable = (bCC == bCC0);
				
			else
				% CAN ASSUME ALL PIXELS IN NEIGHBORHOOD ARE SAME LAYER & NON-BORDER
				bCC = int8(0);
				bStable = false;
				
				% GET NEIGHBORHOOD (ADJACENT) PIXEL LAYER-TRANSITION-DISTANCES (K-1)				
				sUL = S0(rowU, colL) + ds*diagDist;
				sUC = S0(rowU, colC) + ds;
				sUR = S0(rowU, colR) + ds*diagDist;
				sCL = S0(rowC, colL) + ds;
				sCR = S0(rowC, colR) + ds;
				sDL = S0(rowD, colL) + ds*diagDist;
				sDC = S0(rowD, colC) + ds;
				sDR = S0(rowD, colR) + ds*diagDist;
				
				% COMPUTE SHORTEST-PATH (GEODESIC) TO A ZERO-CROSSING ('LAYER-TRANSITION-DISTANCE')
				sSign = sign(sCC0);
				sFixedMin = abs(sCC0);
				sFixedMin = min(abs(sFixedMin), abs(sUL)*(sSign == sign(sUL)));
				sFixedMin = min(abs(sFixedMin), abs(sUC)*(sSign == sign(sUC)));
				sFixedMin = min(abs(sFixedMin), abs(sUR)*(sSign == sign(sUR)));
				sFixedMin = min(abs(sFixedMin), abs(sCL)*(sSign == sign(sCL)));
				sFixedMin = min(abs(sFixedMin), abs(sCR)*(sSign == sign(sCR)));
				sFixedMin = min(abs(sFixedMin), abs(sDL)*(sSign == sign(sDL)));
				sFixedMin = min(abs(sFixedMin), abs(sDC)*(sSign == sign(sDC)));
				sFixedMin = min(abs(sFixedMin), abs(sDR)*(sSign == sign(sDR)));
				sCC = sFixedMin*sSign;
								
			end
			
			
		end		
	end


end












