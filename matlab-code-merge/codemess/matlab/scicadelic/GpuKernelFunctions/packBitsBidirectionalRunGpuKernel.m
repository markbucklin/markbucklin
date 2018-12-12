function BPrc = packBitsBidirectionalRunGpuKernel(BW)
% (TODO: pad to ensure dimensions are multiple of 32)


% GET DIMENSIONS OF INPUT
[numRows,numCols,numFrames,numChannels] = size(BW);
rowSubs = int32(gpuArray.colon(1,numRows)');
colSubs = int32(gpuArray.colon(1,numCols));
frameSubs = int32(reshape(gpuArray.colon(1, numFrames), 1,1,numFrames));
chanSubs =  int32(reshape(gpuArray.colon(1, numChannels), 1,1,1,numChannels));


% COMPUTE DIMENSIONS OF INPUT 
packSize = uint32(32);
numPixelsTotal = numRows*numCols*numChannels*numFrames;
packStride = numRows/packSize;
numPacks = numPixelsTotal/packSize;
% firstPackIdx = reshape(uint32(gpuArray.colon( 1, packStride, (numPixelsTotal-31))), [],1);
packIdx = reshape(uint32(gpuArray.colon( 1, numPacks)), [],1);
packDimensionCommand = uint8(reshape([1 2], 1, 2));
numPacksPerFrameChannel = numRows*numCols/packSize;

% RESHAPE & ROTATE FOR SIMULTANEOUS PACKING ACROSS ROWS & COLUMNS
BWc = permute(BW, [2 1 3 4]);
BWrc = cat(3, reshape(BW, packSize, []), reshape(BWc, packSize, []));

% RUN KERNEL
BPrc = arrayfun(@packBidirectKernel, packIdx, packDimensionCommand);

% RESHAPE TO PACKS X RC X FRAMES
BPrc = reshape(BPrc, numPacksPerFrameChannel, 2, []);




% ##################################################
% STENCIL-OP SUB-FUNCTION -> RUNS ON GPU
% ##################################################

	function bp = packBidirectKernel( idx0, dimcmd)
		
		% INITIALIZE PACKED BIT OUTPUT
		bp = uint32(BWrc( 1 , idx0, dimcmd));
		
		% SPLIT KERNEL BETWEEN ROW/COL COMMAND

			for k = 2:packSize
				bp = bitor( bitshift( uint32(BWrc( k , idx0, dimcmd)), k-1), bp);
			end
		
	end


end

















% 
% % OTHERWISE PERFORM A 16-PIXEL BICUBIC INTERPOLATION OF SURROUNDING PIXELS
% 			ry0 =  0;
% 			rx0 =  0;
% 			
% 			% MAG/DIR VECTOR COMPONENTS TO REMAINING GRID POINTS
% 			%(   |x3|xL|x0|xR|      or      |xL|x0|xR|x3|   )
% 			ryU = -1;
% 			ryD =  1;
% 			ry3 =  2*sign(sy);
% 			rxL = -1;
% 			rxR =  1;
% 			rx3 =  2*sign(sx);
% 			
% 			% EVALUATE KERNEL OVER COLUMNS OF 4X4 SURROUNDING BLOCK OF PIXELS
% 			fL = catmullromcolkern(rxL);
% 			f0 = catmullromcolkern(rx0);
% 			fR = catmullromcolkern(rxR);
% 			f3 = catmullromcolkern(rx3);
% 			
% 			fq = single(0) ...
% 				+ fL * catmullkern(sx-rxL) ...
% 				+ f0 * catmullkern(sx-rx0) ...
% 				+ fR * catmullkern(sx-rxR) ...
% 				+ f3 * catmullkern(sx-rx3);
% 			
% 		end
% 		
% 		
% 		
% 		% SUBFUNCTIONS ================
% 		function fp = resamplePixel(ry,rx)
% 			% Selects pixel at specified (integer) input coordinates if that pixel is within the boarders
% 			% of F, in which case it replaces sample with 'global' input (background)
% 			yk = y0 + ry;
% 			xk = x0 + rx;
% 			frow = max(1, min(numRows, yk));
% 			fcol = max(1, min(numCols, xk));
% 			
% 			if (frow~=yk) || (fcol~=xk)
% 				fp = single( Fbg(max(1,min(numRows, y0)), max(1,min(numCols,x0)), 1, cq) );%chansubnew
% 				
% 			else
% 				fp = single( BW(frow,fcol,tq,cq));
% 				
% 			end
% 			
% 		end
% 		function fcol = catmullromcolkern(rxk)
% 			% Takes an integer column-subscript (relative to x0) as input then accumulates kernel output
% 			% as it evaluates the kernel over all pixels in the specified column
% 			fcol = single(0) ...
% 				+ resamplePixel(ryU, rxk) * catmullkern(sy-ryU) ...
% 				+ resamplePixel(ry0 , rxk) * catmullkern(sy-ry0) ...
% 				+ resamplePixel(ryD, rxk) * catmullkern(sy-ryD) ...
% 				+ resamplePixel(ry3, rxk) * catmullkern(sy-ry3);
% 			
% 		end
% 		function g = catmullkern(s)
% 			% Catmull-Rom piecewise polynomial kernel function -> a function of distance between query
% 			% location and pixel-sample location
% 			s = abs(s);
% 			if s < 2
% 				s3 = s^3;
% 				s2 = s^2;
% 				g = .5*(0 ...
% 					+ (s<1) * (3*s3 - 5*s2 + 2) ...
% 					+ (s>=1) * (-s3 + 5*s2 - 8*s + 4));
% 			else
% 				g = single(0);
% 			end
% 			
% 		end









