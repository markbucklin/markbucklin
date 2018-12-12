function F = discoverRegionsRunGpuKernel(F)
% Resamples motion-shifted frame using bicubic interpolation, replacing/sampling missing pixels using those provided in Fbg



[numRows,numCols,numFrames,numChannels] = size(F);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));





% RESAMPLE/INTERPOLATE IMAGE USING BICUBIC INTERPOLATION ON GPU
Fq = arrayfun(@bicubicImageResampleKernel, rowSubs, colSubs, frameSubs, chanSubs, uy, ux);

% RECAST OUTPUT TO SAME DATATYPE AS INPUT
F = cast(Fq, 'like', F);









% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

% ============================================================
% SURFACE-CLASSIFICATION & INTERMEDIATE RESULTS ONLY #########
% ============================================================
function [k1, k2, w1] = structureTensorEigDecompKernel(yq, xq, tq, cq)
		
		% GET CENTRAL PIXEL (current frame & previous frame)
		f = single(F(yq, xq, tq, cq));
		
		% COMPUTE 1ST ORDER GRADIENTS (CENTRAL-DIFFERENCE APPROX.)
		fx = .5*(fCR - fCL);
		fy = .5*(fDC - fUC);
		
		% COMPUTE 2ND ORDER GRADIENTS
		fxx = fCR + fCL - 2*f;
		fyy = fUC + fDC - 2*f;
		fxy = .25*(fUL + fDR - fDL - fUR);
		
		% INTERMEDIATE TENSOR OPERANDS
		fx2 = fx^2;
		fy2 = fy^2;
		fxy2 = fxy^2;
		Jtrace = 1 + fx2 + fy2;
		
		% GAUSSIAN CURVATURE (direction independent)
		K = (fxx*fyy - fxy2) / (Jtrace)^2;
		
		% MEAN CURVATURE (direction independent) & CURVATURE MAGNITUDE
		H = ( (1+fy2)*fxx + (1+fx2)*fyy - 2*fx*fy*fxy ) / (2*(Jtrace)^(3/2));
		CM = realsqrt( 1 + max(0, H^2 - K)) - 1;
		
		% PRINCIPAL CURVATURE k1, k2 (associated with direction)
		k1 = H + CM;
		k2 = H - CM;
		
		% ALSO RETURN DIRECTION OF PRINCIPAL EIGEN VECTOR		
		if fxy == 0
			w1 = single(0);
		else
			u1 = k1 - fyy;
			v1 = fxy;
			w1 = atan2(v1,u1);
			% 			u2 = k2 - fyy;
			% 			v2 = fxy;
			
		end
		
		
		
		
	end

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


end


















