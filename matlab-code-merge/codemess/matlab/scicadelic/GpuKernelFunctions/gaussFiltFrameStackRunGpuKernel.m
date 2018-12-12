function F = gaussFiltFrameStackRunGpuKernel(F, sigma, filtSize, padType)
% GAUSSFILTFRAMESTACK
% Performs gaussian filtering on assumed gpuArray input (only slightly faster than builtin imgaussfilt, but handles 3D input)
%
% >> Fout = gaussFiltFrameStack(F, sigma, filtSize, padType)
% >> Fout = gaussFiltFrameStack(F)
% >> Fout = gaussFiltFrameStack(F, 1.25)
% >> Fout = gaussFiltFrameStack(F, 3, 7, 'symmetric')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'symmetric')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'replicate')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'partial-symmetric')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'replace')
% >> Fout = gaussFiltFrameStack(F, 1.5, [], 'none')



% TODO: NOT YET IMPLEMENTED


if nargin < 4
	padType = [];
	if nargin < 3
		filtSize = [];
		if nargin < 2
			sigma = [];
		end
	end
end
if isempty(sigma)
	sigma = 1.25;
end
if isempty(filtSize)
	filtSize = 2*ceil(2*sigma) + 1;
else
	filtSize = 2*fix(filtSize/2) + 1;
end
if isempty(padType)
	padType = 'replicate';
end

% GET ARRAY DIMENSIONS
[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));

% GET SEPARABLE FILTER COEFFICIENTS
Hgauss = fspecial('gaussian', filtSize, sigma);
[U,S,V] = svd(single(Hgauss));
hGauss = single(V(:,1)' * sqrt(S(1,1)));
vGauss = single(U(:,1) * sqrt(S(1,1)));
hFiltSize = int32(numel(hGauss));
vFiltSize = int32(numel(vGauss));



% RUN SEQUENTIAL/SEPARABLE FILTER
Fk = single(F);
Fk = arrayfun( @gaussianSepFiltVertKernel, rowSubs, colSubs, frameSubs, chanSubs);
Fk = arrayfun( @gaussianSepFiltHorizKernel, rowSubs, colSubs, frameSubs, chanSubs);

% Fq = arrayfun(@gaussianStencilKernel, rowSubs, colSubs, frameSubs, chanSubs);

% RECAST OUTPUT TO SAME DATATYPE AS INPUT
F = cast(Fk, 'like', F);









% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################
	function fk = gaussianSepFiltHorizKernel( y0, x0, t0, c0 )
		
		fk = single(0);
		yk = y0;
		tk = t0;
		ck = c0;
		dx = -floor(hFiltSize/2);
		k = int32(0);
		
		while k < hFiltSize
			k = k + 1;
			
			% GET CURRENT VERTICAL INDEX
			xk = max(1, min( numCols, x0 + dx));
			
			% GET->MULTIPLY PIXEL & FILTER VALUES
			hk = hGauss(k);
			fk = fk + hk*Fk( yk, xk, tk, ck);
						
			% INCREMENT VERTICAL OFFSET COUNTER
			dx = dx + 1;
		end
		
	end
	function fk = gaussianSepFiltVertKernel( y0, x0, t0, c0 )
		
		fk = single(0);
		xk = x0;
		tk = t0;
		ck = c0;
		dy = -floor(vFiltSize/2);
		k = int32(0);
		
		while k < vFiltSize
			k = k + 1;
			
			% GET CURRENT VERTICAL INDEX
			yk = max(1, min( numRows, y0 + dy));
			
			% GET->MULTIPLY PIXEL & FILTER VALUES
			hk = vGauss(k);
			fk = fk + hk*Fk( yk, xk, tk, ck);
						
			% INCREMENT VERTICAL OFFSET COUNTER
			dy = dy + 1;
		end
		
		
	end
	function fq = gaussianStencilKernel( yq, xq, tq, cq, dy, dx)
		
		% GET CENTRAL LOCATION TO INTERPOLATE FROM (SUBPIXEL COORDINATE)
		y = single(yq) - dy;
		x = single(xq) - dx;
		
		% GET INTEGER SUBSCRIPTS SURROUNDING CENTER OF INTERPOLATION
		y0 = round(y);
		x0 = round(x);
		
		% GET DISTANCE BETWEEN NEAREST PIXEL-SAMPLE AND DESIRED COORDINATE
		sy = y - y0;
		sx = x - x0;
		
		% IF REQUESTED COORDINATE ALIGNS EXACTLY WITH A PIXEL -> SIMPLY RETURN THAT PIXEL
		if (abs(sx)+abs(sy)) > eps
			fq = single(resamplePixel(0,0));
			
		else
			% OTHERWISE PERFORM A 16-PIXEL BICUBIC INTERPOLATION OF SURROUNDING PIXELS
			ry0 =  0;
			rx0 =  0;
			
			% MAG/DIR VECTOR COMPONENTS TO REMAINING GRID POINTS
			%(   |x3|xL|x0|xR|      or      |xL|x0|xR|x3|   )
			ryU = -1;
			ryD =  1;
			ry3 =  2*sign(sy);
			rxL = -1;
			rxR =  1;
			rx3 =  2*sign(sx);
			
			% EVALUATE KERNEL OVER COLUMNS OF 4X4 SURROUNDING BLOCK OF PIXELS
			fL = catmullromcolkern(rxL);
			f0 = catmullromcolkern(rx0);
			fR = catmullromcolkern(rxR);
			f3 = catmullromcolkern(rx3);
			
			fq = single(0) ...
				+ fL * catmullkern(sx-rxL) ...
				+ f0 * catmullkern(sx-rx0) ...
				+ fR * catmullkern(sx-rxR) ...
				+ f3 * catmullkern(sx-rx3);
			
		end
		
		
		
		% SUBFUNCTIONS ================
		function fp = resamplePixel(ry,rx)
			% Selects pixel at specified (integer) input coordinates if that pixel is within the boarders
			% of F, in which case it replaces sample with 'global' input (background)
			yk = y0 + ry;
			xk = x0 + rx;
			frow = max(1, min(numRows, yk));
			fcol = max(1, min(numCols, xk));
			
			if (frow~=yk) || (fcol~=xk)
				fp = single( Fbg(max(1,min(numRows, y0)), max(1,min(numCols,x0)), 1, cq) );%chansubnew
				
			else
				fp = single( F(frow,fcol,tq,cq));
				
			end
			
		end
		function fcol = catmullromcolkern(rxk)
			% Takes an integer column-subscript (relative to x0) as input then accumulates kernel output
			% as it evaluates the kernel over all pixels in the specified column
			fcol = single(0) ...
				+ resamplePixel(ryU, rxk) * catmullkern(sy-ryU) ...
				+ resamplePixel(ry0 , rxk) * catmullkern(sy-ry0) ...
				+ resamplePixel(ryD, rxk) * catmullkern(sy-ryD) ...
				+ resamplePixel(ry3, rxk) * catmullkern(sy-ry3);
			
		end
		function g = catmullkern(s)
			% Catmull-Rom piecewise polynomial kernel function -> a function of distance between query
			% location and pixel-sample location
			s = abs(s);
			if s < 2
				s3 = s^3;
				s2 = s^2;
				g = .5*(0 ...
					+ (s<1) * (3*s3 - 5*s2 + 2) ...
					+ (s>=1) * (-s3 + 5*s2 - 8*s + 4));
			else
				g = single(0);
			end
			
		end
				
	end









end









% switch padType
% 	case 'symmetric' % 8.9ms
% 		% SYMMETRIC PADDING
% 		
% 	case 'replicate' % 10.5ms
% 		% REPLICATE PADDING
% 		
% 	case 'partial-symmetric' % 7.0ms
% 		% PARTIAL SYMMETRIC PADDING
% 		
% 	case 'none' % 5.0ms
% 		% NO PADDING
% 		
% 	case 'replace' % 6.9ms
% 		
% end

