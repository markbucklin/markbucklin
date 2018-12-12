function F = resampleImageBicubicRunGpuKernel(F, uy, ux, Fbg)
% Resamples motion-shifted frame using bicubic interpolation, replacing/sampling missing pixels using those provided in Fbg

if nargin < 4
	Fbg = single(mean(F,3));
else
	Fbg = single(Fbg);
end
[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));

if numel(uy) < numRows
	uy = reshape(uy, 1, 1, numFrames, numChannels);
end
if numel(ux) < numCols
	ux = reshape(ux, 1, 1, numFrames, numChannels);
end


% ADD A VERY SMALL RANDOM IRREGULAR OFFSET TO REQUESTED DISPLACEMENT TO AVOID SAMPLING WHOLE NUMBERS (causes mysterious error)
uy = uy + .001111*sign(randn(size(uy)));
ux = ux + .001111*sign(randn(size(ux)));


% RESAMPLE/INTERPOLATE IMAGE USING BICUBIC INTERPOLATION ON GPU
Fq = arrayfun(@bicubicImageResampleKernel, rowSubs, colSubs, frameSubs, chanSubs, uy, ux);

% RECAST OUTPUT TO SAME DATATYPE AS INPUT
F = cast(Fq, 'like', F);



	function fq = bicubicImageResampleKernel( yq, xq, tq, cq, dy, dx)
		
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
	function fResamp = arbitraryResampleKernel( yq, xq, tq, cq, dy, dx)
		% needs a kernel supplied in parent workspace named kResampleKernel
		% ck = floor(size(kResampleKernel,1)/2) + 1 ?
		ck = kSampleSpan + 1;
		cy = yq - dy;
		cx = xq - dx;
		
		% RESAMPLE USING GAUSSIAN BLUR KERNEL GENERATED PREVIOUSLY
		fResamp = single(0) ...
			+ resamplePixel(-2,-2) ...
			+ resamplePixel(-1,-2) ...
			+ resamplePixel( 0,-2) ...
			+ resamplePixel( 1,-2) ...
			+ resamplePixel( 2,-2) ...
			+ resamplePixel(-2,-1) ...
			+ resamplePixel(-1,-1) ...
			+ resamplePixel( 0,-1) ...
			+ resamplePixel( 1,-1) ...
			+ resamplePixel( 2,-1) ...
			+ resamplePixel(-2, 0) ...
			+ resamplePixel(-1, 0) ...
			+ resamplePixel( 0, 0) ...
			+ resamplePixel( 1, 0) ...
			+ resamplePixel( 2, 0) ...
			+ resamplePixel(-2, 1) ...
			+ resamplePixel(-1, 1) ...
			+ resamplePixel( 0, 1) ...
			+ resamplePixel( 1, 1) ...
			+ resamplePixel( 2, 1) ...
			+ resamplePixel(-2, 2) ...
			+ resamplePixel(-1, 2) ...
			+ resamplePixel( 0, 2) ...
			+ resamplePixel( 1, 2) ...
			+ resamplePixel( 2, 2);
		
		function g = resamplePixel(yk,xk)
			krow = ck + yk;
			kcol = ck + xk;
			frow = max(1, min(numRows, cy + yk));
			fcol = max(1, min(numCols, cx + xk));
			g = kResampleKernel(krow,kcol,tq) * single(F(frow,fcol,tq));
			
		end
		
	end
	function fResamp = coarseResampleKernel( yq, xq, tq, cq, dy, dx)
		
		% NEAREST SINGLE PIXEL SUBSCRIPTS
		rowC = min(numRows, max(1, yq - dy));
		colC = min(numCols, max(1, xq - dx));
		
		% DISPLACED RESAMPLE
		fResamp = F( rowC, colC, tq, cq);
		
	end


end


















