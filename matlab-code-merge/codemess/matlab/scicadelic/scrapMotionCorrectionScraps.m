
			
			% BEGIN WITH LAST CORRECTION FOR GENERATING CHANGE (1st Moment)
			% 			lastUxy = onCpu(obj, obj.UxyCurrent);
			
			% RUN FAST FRAME-CORRELATION TO DETERMINE WHICH FRAMES NEED CORRECTION (if threshold-setting is non-zero)
			
			for k=1:numFrames
				
				% INITIALIZE FIRST FRAME WITH ALL ZEROS
				if (N+k) == 1
					Uxy = [0 0];
					info.ux(1) = 0;
					info.uy(1) = 0;
					info.dir(1) = 0;
					info.mag(1) = 0;
					info.dux(1) = 0;
					info.duy(1) = 0;
					info.ddir(1) = 0;
					info.dmag(1) = 0;
					info.stable(1) = true;
					dmag = 0;
				else
					% RUN PROCEDURE: RETURN CORRECTED FRAME AND FRAME-DISPLACEMENT
					fdata = F(:,:,k);
					[fdata, Uxy] = findFrameShift(obj, fdata);
					
					% SPLIT X-Y COMPONENTS OF APPLIED CORRECTION AND CALCULATE MAGNITUDE/DIRECTION
					uy = Uxy(1);
					ux = Uxy(2);
					umag = hypot(ux,uy);
					udir = atan2d(uy,ux);
					
					% ALSO SAVE DIFFERENTIAL DISPLACEMENT (1st Moment?)
					duy = uy - lastUxy(1);
					dux = ux - lastUxy(2);
					dmag = hypot(dux, duy);
					ddir = atan2d(duy, dux);
					lastUxy = Uxy;
					
					% FILL INFO STRUCTURE
					info.ux(k,1) = ux;
					info.uy(k,1) = uy;
					info.dir(k,1) = udir;
					info.mag(k,1) = umag;
					info.dux(k,1) = dux;
					info.duy(k,1) = duy;
					info.ddir(k,1) = ddir;
					info.dmag(k,1) = dmag;
					info.stable(k,1) = dmag < obj.pMotionMagDiffStableThreshold;
					F(:,:,k) = fdata;
				end
				
				% ADD FRAMES WITH MINIMAL MOTION TO MOVING AVERAGE
				if dmag < obj.pMotionMagDiffStableThreshold
					addToFixedFrame(obj, F(:,:,k));
				end				
			end
			
			
			
			
			
			
			
			
			
			adjunctData = varargin{1};
				for k=1:numFrames
					Uxy = [info.ux(k) info.uy(k)];
					adjunctData(:,:,k) = applyFrameShift(obj, adjunctData(:,:,k), Uxy);
				end
				obj.AdjunctFrames = adjunctData;
				
				
				
				function addToFixedFrame(obj,fixedFrame)
				% FIXED MEAN
			nf = min(obj.CurrentNumBufferedFrames, obj.MaxNumBufferedFrames);
			nt = nf / (nf + 1);
			na = 1/(nf + 1);
			obj.FixedMean = obj.FixedMean*nt + single(fixedFrame)*na;
			nf = nf + 1;
			% FIXED MAX & MIN
			obj.FixedMax = max(obj.FixedMax, fixedFrame);
			obj.FixedMin = min(obj.FixedMin, fixedFrame);
			obj.CurrentNumBufferedFrames = nf;
				
				
				
				
				
				function Uxy = findFrameShift(obj, moving, fixed)
			% Computes the mean frame displacement vector between unregistered frames MOVING (ND) & registered frame FIXED (2D) using phase correlation.
			
			% COPY PROPERTIES TO LOCAL VARIABLES FOR FASTER REUSE
			subPix = obj.pSubPixelPrecision;			
			rowSubs = obj.SubWinRowSubs;
			colSubs = obj.SubWinColSubs;
			subWinSize = length(rowSubs);			
			freqWinSize = subWinSize;
			subCenter = floor(freqWinSize/2 + 1);
			antiEdgeWin = obj.SubWinAntiEdgeWin;
			xcMask = obj.XcMask;
			
			% ALIGN WITH PREVIOUS-FRAME
			moving = single(data(rowSubs, colSubs));
			fixed = single(obj.FixedReference(rowSubs, colSubs));
			[uy, ux] = getSubWinDisplacement(moving, fixed);
			% 			UxyPrev = applyTranslationLimits(obj, [uy ux]);
			% 			obj.CorrectionToPrecedingFrame = UxyPrev;
			UxyPrev = [uy ux];
			data = applyFrameShift(obj, data, UxyPrev);
			dr = abs(uy) + abs(ux);
			
			
			
			% DECIDE IF CORRECTION TO MOVING AVERAGE IS NECESSARY (OR CAN BE SKIPPED FOR SPEED)
			if (obj.AlwaysAlignToMovingAverage) || (dr > obj.DoubleAlignmentThreshold)
				
				% ALIGN WITH MEAN-FRAME (GLOBAL MOVING AVERAGE)
				moving = single(data(rowSubs, colSubs));
				fixed = single(obj.FixedMean(rowSubs, colSubs));
				[uy, ux] = getSubWinDisplacement(moving, fixed);
				UxyMean = [uy ux];
				% 				UxyMean = applyTranslationLimits(obj, [uy ux]);
				obj.CorrectionToMovingAverage = UxyMean;
				
				% CHECK VALIDITY OF ALIGNMENT WITH MEAN-FRAME BEFORE APPLYING
				if all((abs(UxyMean + UxyPrev) - min(abs(UxyPrev),abs(UxyMean))) > -1) %all(abs(UxyMean) <= max(abs(UxyPrev),[1 1]))
					% (this check must be true IF the previous frame was successfully aligned to mean)
					Uxy = UxyPrev + UxyMean;
					data = applyFrameShift(obj, data, UxyMean);
				else
					Uxy = UxyPrev;
					fprintf('only using previous shift\n')
				end
			else
				
				Uxy = UxyPrev;
			end
			
% 			obj.FixedReference = data;
% 			obj.UxyReference = Uxy;
			if isa(Uxy,'gpuArray')
				Uxy = gather(Uxy);
			end
			
			% SUBFUNCTIONS
			function [xcRow, xcCol] = getSubWinDisplacement(moving, fixed)
				% Returns the row & column shift that one needs to apply to MOVING to align with FIXED
				moving = bsxfun(@times, moving , antiEdgeWin); % moving = moving  .* antiEdgeWin;
				fixed = fixed  .* antiEdgeWin;
				fMoving = fft2(moving);
				fFixed = fft2(fixed);
				% 				fMoving = fft2(rot90(moving,2), freqWinSize, freqWinSize);
				% 				fFixed = fft2(fixed, freqWinSize, freqWinSize);
				fX = bsxfun(@times, fFixed , conj(fMoving)); % fX = fFixed .* conj(fMoving);
				% xc = fftshift(ifft2( fX ./ max(abs(fMoving),abs(fFixed)), 'symmetric'));
				xc = fftshift(ifft2( fX ./ bsxfun(@max, abs(fMoving), abs(fFixed)), 'symmetric'));
				if any(isnan(xc(:))) % NEW - to avoid errors
					xcRow = zeros(1,'like',moving);
					xcCol = zeros(1,'like',moving);
					% TODO: Provide warning of non-singular result - failed phase correlation
				else					
					xc(~xcMask) = 0; % TODO: ditch if possible
					[~, idx] = max(xc(:));
					[maxRow, maxCol] = ind2sub(size(xc), idx);
					% SUBPIXEL
					y = single((maxRow-2) : (maxRow+2));
					yq = single(y(1):(1/subPix):y(end));
					x = single((maxCol-2) : (maxCol+2));
					xq = single(x(1):(1/subPix):x(end));
					[X,Y] = meshgrid(x,y);
					[Xq,Yq] = meshgrid(xq,yq);
					% 				xcSubPix = spGaussFilt(interp2(X,Y, xc(y,x)./maxval, Xq, Yq, 'linear')); % gputimeit -> .0028
					% 				xcSubPix = interp2(X,Y, xc(y,x), Xq, Yq, 'linear'); % gputimeit -> .0028
					% 				xcSubPix = imgaussfilt(interp2(X,Y, xc(y,x), Xq, Yq, 'linear'), 5, 'Padding', 'replicate');%TODO find best size or use imfilter
					xcSubPix = imfilter(interp2(X,Y, xc(y,x), Xq, Yq, 'linear'), double(ones(subPix,'like',xc)), 'replicate');
					%TODO: Use polyfit instead -> ORRRRRRRRRR, could definitely speed this up with custom GPU kernel
					%OR Use: spline
					[~, idx] = max(xcSubPix(:));
					maxRow = Yq(idx);
					maxCol = Xq(idx);
					xcRow = maxRow - subCenter;
					xcCol = maxCol - subCenter;
				end
			end
			% 			function subwin = padAndFiltSubwin(subwin)
			% 				subwin(padIdx, :) = 0;
			% 				subwin(:, padIdx) = 0;
			% 				subwin = subWinGaussFilt(subwin);
			% 			end
				end
	
			
			
			
				
				
				function Uxy = applyTranslationLimits(obj, Uxy)
			pThrottle = .95;
			% CHECK INTER-FRAME SMOOTHNESS
			lastUxy = cast(obj.UxyReference, 'like', Uxy);
			if isempty(lastUxy)
				lastUxy = Uxy;
				lastUxy(:) = 0;
			end
			maxInter = cast(obj.pMaxInterFrameTranslation,'like',Uxy);
			uy = Uxy(1);
			dUy = uy-lastUxy(1);
			if dUy > maxInter
				uy = maxInter*pThrottle;
			elseif dUy < -maxInter
				uy = -maxInter*pThrottle;
			end
			ux = Uxy(2);
			dUx = ux - lastUxy(2);
			if dUx > maxInter
				ux = maxInter*pThrottle;
			elseif dUx < -maxInter
				ux = -maxInter*pThrottle;
			end
			Uxy = [uy ux];
				end
				
			xc(~xcMask) = 0; % TODO: ditch if possible
				
	
			
			
			% FIND PEAK ROW & COLUMN (WITHIN MASK-DEFINED BOUNDARY)
					xc = bsxfun(@times, xc, cast(xcMask, 'like', xc));
					[colMaxVal, colMaxIdx] = max(xc,[],1); % colmaxidx = idx of row with max pixel in column
					[rowMaxVal, rowMaxIdx] = max(xc,[],2); % rowmaxidx = idx of column with max value in each row
					[colRowMaxVal, colRowMaxIdx] = max(colMaxVal, [], 2); % colRowMaxIdx -> rowSub
					[rowColMaxVal, rowColMaxIdx] = max(rowMaxVal, [], 1); % rowColMaxIdx -> colSub
					maxRow = colRowMaxIdx;
					maxCol = rowColMaxIdx;
			
			
			[colRowMaxVal, colRowMaxIdx] = max(max(xcSubPix, [],1), [], 2);
					[rowColMaxVal, rowColMaxIdx] = max(max(xcSubPix, [],2), [], 1);
					maxRow = colRowMaxIdx;
					maxCol = rowColMaxIdx;
			
			
			
					% FIND PEAK ROW & COLUMN
					xc(~xcMask) = 0; % TODO: ditch if possible
			
			[~, idx] = max(xc(:));
					[maxRow, maxCol] = ind2sub(size(xc), idx);
			
			
				% INTERPOLATE AREA SURROUNDING PEAK FOR SUBPIXEL ACCURACY
					if subPix > 1
					y = single((maxRow-2) : (maxRow+2));
					yq = single(y(1):(1/subPix):y(end));
					x = single((maxCol-2) : (maxCol+2));
					xq = single(x(1):(1/subPix):x(end));
					[X,Y,K] = ndgrid(x,y,frameSubs);
					[Xq,Yq,Kq] = ndgrid(xq,yq,frameSubs);
					xcSubPix = imfilter(interpn(X,Y,K, xc(y,x,:), Xq,Yq,Kq, 'linear'), double(ones(subPix,'like',xc)), 'replicate');
					
					
					[~, idx] = max(xcSubPix(:));
					maxRow = Yq(idx);
					maxCol = Xq(idx);
					
					end
					
					
					xcRow = bsxfun(@minus, maxRow , centerRow);
					xcCol = bsxfun(@minus, maxCol , centerCol);
			
					% 					[X,Y] = meshgrid(x,y);
					% 					[Xq,Yq] = meshgrid(xq,yq);
					
					% 				xcSubPix = spGaussFilt(interp2(X,Y, xc(y,x)./maxval, Xq, Yq, 'linear')); % gputimeit -> .0028
					% 				xcSubPix = interp2(X,Y, xc(y,x), Xq, Yq, 'linear'); % gputimeit -> .0028
					% 				xcSubPix = imgaussfilt(interp2(X,Y, xc(y,x), Xq, Yq, 'linear'), 5, 'Padding', 'replicate');%TODO find best size or use imfilter
					% 					xcSubPix = imfilter(interp2(X,Y, xc(y,x), Xq, Yq, 'linear'), double(ones(subPix,'like',xc)), 'replicate');
% 					xcSubPix = obj.PeakFilterFcn(interp2(X,Y, xc(y,x,:), Xq, Yq, 'linear'));

					
					
					
					%TODO: Use polyfit instead -> ORRRRRRRRRR, could definitely speed this up with custom GPU kernel
					%OR Use: spline
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					
					[~, maxRowSub] = max(max(xc, [],1), [], 2);
					[~, maxColSub] = max(max(xc, [],2), [], 1);
					
					
					% INTERPOLATE AREA SURROUNDING PEAK FOR SUBPIXEL ACCURACY
					if subPix > 1
						% 						if isempty(obj.PeakSurroundCoarseRadius)
						%
						% 						else
						%
						% 						end
						peakSurrCoarseRadius = 2;
						peakSurrCoarseIdx = -peakSurrCoarseRadius:peakSurrCoarseRadius;
						peakSurrFineRadius = peakSurrCoarseRadius;% - 1; % TODO: remove the -1??
						peakSurrFineIdx =  -peakSurrFineRadius:1/subPix:peakSurrFineRadius;
						
						% CONSTRUCT COARSE & FINE SUBSCRIPTS
						coarseRowSubs = single(bsxfun(@plus, maxRowSub, peakSurrCoarseIdx));		% y
						coarseColSubs = single(bsxfun(@plus, maxColSub, peakSurrCoarseIdx'));		% x
						fineRowSubs = single(bsxfun(@plus, maxRowSub, peakSurrFineIdx));	% yq
						fineColSubs = single(bsxfun(@plus, maxColSub, peakSurrFineIdx'));	% xq
						numFineSubs = numel(peakSurrFineIdx);
						
						% RUN INTERPOLATION LOOP ON INDIVIDUAL FRAMES (or replace with gpu-kernel)
						for k = 1:numFrames
							x = coarseColSubs(:,:,k);
							y = coarseRowSubs(:,:,k);
							xq = fineColSubs(:,:,k);
							yq = fineRowSubs(:,:,k);
							xcSubK = interp2(x,y, xc(:,:,k), xq,yq, 'linear');
							xcSubPix(:,:,k) = xcSubK;
						end
						
						% APPLY GAUSSIAN FILTER (TRY TO COMBINE WITH INTERPOLATION
						xcSubPix = obj.PeakFilterFcn(xcSubPix);
						
						% FIND PEAK OF INTERPOLATED SUB-PIXEL APPROXIMATION OF AREA AROUND PEAK
						[~, rowIdx] = max(max(xcSubPix, [],1), [], 2);
						[~, colIdx] = max(max(xcSubPix, [],2), [], 1);
						maxRowSub = yq(rowIdx);
						maxColSub = xq(colIdx);
						
						% 						maxIdx = sub2ind(size(xcSubK), maxRowSub, maxColSub);						
						% 						maxRowSub = reshape(yq(maxIdx(:)), 1,1,numFrames);
						% 						maxColSub = reshape(xq(maxIdx(:)), 1,1,numFrames);
						
						% SELECT AREA TO CONSIDER
						% 						coarseFrameIdx = bsxfun(@plus, numSubWinRows.*(coarseColSubs-1), coarseRowSubs);
						% 						coarseStackIdx = bsxfun(@plus, numSubWinPixels.*(frameSubs-1), coarseFrameIdx); % TODO: STORE THESE & UPDATE AS NEEDED LIKE IN PIXELGROUPCONTROLLER
						% 						xcPeakCoarse = reshape(xc(coarseStackIdx(:)), 2*peakSurrCoarseRadius+1, 2*peakSurrCoarseRadius+1, numFrames);
						
						
						% GENERATE/INTERPOLATE SUB-PIXEL APPROXIMATION OF AREA AROUND PEAK
						
						
						% FIND FINE ROW/COL INDEX OF PHASE-CORRELATION PEAK
						% 						[~, maxRowIdx] = max(max(xcSubPix, [],1), [], 2);
						% 						[~, maxColIdx] = max(max(xcSubPix, [],2), [], 1);
						
						
						
						% 						[X,Y,K] = ndgrid(coarseColSubs,coarseRowSubs,frameSubs);
						% 						[X,Y] = meshgrid(coarseColSubs,coarseRowSubs);
						% 						[Xq,Yq] = meshgrid(fineColSubs,fineRowSubs);
						% 						[Xq,Yq,Kq] = ndgrid(xq,yq,frameSubs);
						% RESHAPE MATRICES & USE SUBSCRIPT TO INDEX CONVERSIONS
						% 						xcSubPix = imfilter(interpn(X,Y,K, xc(y,x,:), repmat(xq,1,401,1),repmat(yq,401,1,1),repmat(frameSubs,401,401,1), 'linear'), single(ones(subPix,'like',xc)), 'replicate');
						% 						xcSubPix = imfilter(interpn(X,Y,K, xc(y,x,:), Xq,Yq,Kq, 'linear'), double(ones(subPix,'like',xc)), 'replicate');
						% 						imsc(imresize(xc(y(:,:,k),x(:,:,k),k), 10,'cubic'))
						% 						[~, maxRowIdx] = max(max(xcSubPix, [],1), [], 2);
						% 						[~, maxColIdx] = max(max(xcSubPix, [],2), [], 1);
						% 					[~, idx] = max(xcSubPix(:));
						% 					maxRow = Yq(idx);
						% 					maxCol = Xq(idx);
						
					end
					
					
					duRow = bsxfun(@minus, maxRowSub , centerRow) - 1; % TODO: Need the +1??????????????
					duCol = bsxfun(@minus, maxColSub , centerCol) - 1;
					
					
				end
				
				
				
				
				
				
				
				
				
				
				
					
					
					[~, maxRowSub] = max(max(xc, [],1), [], 2);
					[~, maxColSub] = max(max(xc, [],2), [], 1);
					
					
					
					
					% INTERPOLATE AREA SURROUNDING PEAK FOR SUBPIXEL ACCURACY
					if subPix > 1
						% 						if isempty(obj.PeakSurroundCoarseRadius)
						%
						% 						else
						%
						% 						end
						peakSurrCoarseRadius = 2;
						peakSurrCoarseIdx = -peakSurrCoarseRadius:peakSurrCoarseRadius;
						peakSurrFineRadius = peakSurrCoarseRadius;% - 1; % TODO: remove the -1??
						peakSurrFineIdx =  -peakSurrFineRadius:1/subPix:peakSurrFineRadius;
						
						% CONSTRUCT COARSE & FINE SUBSCRIPTS
						coarseRowSubs = single(bsxfun(@plus, maxRowSub, peakSurrCoarseIdx));		% y
						coarseColSubs = single(bsxfun(@plus, maxColSub, peakSurrCoarseIdx'));		% x
						fineRowSubs = single(bsxfun(@plus, maxRowSub, peakSurrFineIdx));	% yq
						fineColSubs = single(bsxfun(@plus, maxColSub, peakSurrFineIdx'));	% xq
						numFineSubs = numel(peakSurrFineIdx);
						
						% RUN INTERPOLATION LOOP ON INDIVIDUAL FRAMES (or replace with gpu-kernel)
						for k = 1:numFrames
							x = coarseColSubs(:,:,k);
							y = coarseRowSubs(:,:,k);
							xq = fineColSubs(:,:,k);
							yq = fineRowSubs(:,:,k);
							xcSubK = interp2(x,y, xc(:,:,k), xq,yq, 'linear');
							xcSubPix(:,:,k) = xcSubK;
						end
						
						% APPLY GAUSSIAN FILTER (TRY TO COMBINE WITH INTERPOLATION
						xcSubPix = obj.PeakFilterFcn(xcSubPix);
						
						% FIND PEAK OF INTERPOLATED SUB-PIXEL APPROXIMATION OF AREA AROUND PEAK
						[~, rowIdx] = max(max(xcSubPix, [],1), [], 2);
						[~, colIdx] = max(max(xcSubPix, [],2), [], 1);
						maxRowSub = yq(rowIdx);
						maxColSub = xq(colIdx);
						
						% 						maxIdx = sub2ind(size(xcSubK), maxRowSub, maxColSub);						
						% 						maxRowSub = reshape(yq(maxIdx(:)), 1,1,numFrames);
						% 						maxColSub = reshape(xq(maxIdx(:)), 1,1,numFrames);
						
						% SELECT AREA TO CONSIDER
						% 						coarseFrameIdx = bsxfun(@plus, numSubWinRows.*(coarseColSubs-1), coarseRowSubs);
						% 						coarseStackIdx = bsxfun(@plus, numSubWinPixels.*(frameSubs-1), coarseFrameIdx); % TODO: STORE THESE & UPDATE AS NEEDED LIKE IN PIXELGROUPCONTROLLER
						% 						xcPeakCoarse = reshape(xc(coarseStackIdx(:)), 2*peakSurrCoarseRadius+1, 2*peakSurrCoarseRadius+1, numFrames);
						
						
						% GENERATE/INTERPOLATE SUB-PIXEL APPROXIMATION OF AREA AROUND PEAK
						
						
						% FIND FINE ROW/COL INDEX OF PHASE-CORRELATION PEAK
						% 						[~, maxRowIdx] = max(max(xcSubPix, [],1), [], 2);
						% 						[~, maxColIdx] = max(max(xcSubPix, [],2), [], 1);
						
						
						
						% 						[X,Y,K] = ndgrid(coarseColSubs,coarseRowSubs,frameSubs);
						% 						[X,Y] = meshgrid(coarseColSubs,coarseRowSubs);
						% 						[Xq,Yq] = meshgrid(fineColSubs,fineRowSubs);
						% 						[Xq,Yq,Kq] = ndgrid(xq,yq,frameSubs);
						% RESHAPE MATRICES & USE SUBSCRIPT TO INDEX CONVERSIONS
						% 						xcSubPix = imfilter(interpn(X,Y,K, xc(y,x,:), repmat(xq,1,401,1),repmat(yq,401,1,1),repmat(frameSubs,401,401,1), 'linear'), single(ones(subPix,'like',xc)), 'replicate');
						% 						xcSubPix = imfilter(interpn(X,Y,K, xc(y,x,:), Xq,Yq,Kq, 'linear'), double(ones(subPix,'like',xc)), 'replicate');
						% 						imsc(imresize(xc(y(:,:,k),x(:,:,k),k), 10,'cubic'))
						% 						[~, maxRowIdx] = max(max(xcSubPix, [],1), [], 2);
						% 						[~, maxColIdx] = max(max(xcSubPix, [],2), [], 1);
						% 					[~, idx] = max(xcSubPix(:));
						% 					maxRow = Yq(idx);
						% 					maxCol = Xq(idx);
						