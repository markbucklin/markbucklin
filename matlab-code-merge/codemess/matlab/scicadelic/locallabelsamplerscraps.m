
% lfs = accumarray(nonzeros(L(:)), double(F(nonzeros(L(:)))), [numPixels*numFrames 1], @sum,0, true);


		% GET LOCAL FLUORESCENCE-INTENSITY GRADIENTS
		dlUC = lPxUC - lPx;
		dlUR = lPxUR - lPx;
		dlCR = lPxCR - lPx;
		dlDR = lPxDR - lPx;
		dlDC = lPxDC - lPx;
		dlDL = lPxDL - lPx;
		dlCL = lPxCL - lPx;
		dlUL = lPxUL - lPx;
		
		% GET SIGNIFICANT-DIFFERENCE-COUNT GRADIENTS
		dcUC = cPxUC - cPx;
		dcUR = cPxUR - cPx;
		dcCR = cPxCR - cPx;
		dcDR = cPxDR - cPx;
		dcDC = cPxDC - cPx;
		dcDL = cPxDL - cPx;
		dcCL = cPxCL - cPx;
		dcUL = cPxUL - cPx;
				
		
pLookup = bitor(uint8(pPxUL>pPx), ...
				bitor( bitshift(uint8(pPxUC>pPx), 1), ...
				bitor( bitshift(uint8(pPxUR>pPx), 2), ...
				bitor( bitshift(uint8(pPxCR>pPx), 3), ...
				bitor( bitshift(uint8(pPxDR>pPx), 4), ...
				bitor( bitshift(uint8(pPxDC>pPx), 5), ...
				bitor( bitshift(uint8(pPxDL>pPx), 6), ...
				bitshift(uint8(pPxCL>pPx), 7)))))))) ;
			
			pMax = pPx;
			pMax = pPxUL.*(pPxUL>pPx) ...
				| bitshift(pPxUC>pPx, -1) ...
				| bitshift(pPxUR>pPx, -2) ...
				| bitshift(pPxCR>pPx, -3) ...
				| bitshift(pPxDR>pPx, -4) ...
				| bitshift(pPxDC>pPx, -5) ...
				| bitshift(pPxDL>pPx, -6) ...
				| bitshift(pPxCL>pPx, -7) ;

max(pPx, max( max(max(pPxUL,pPxUC),max(pPxUR,pPxDL)), max(max(pPxDC,pPxDR),max(pPxCL,pPxCR))))
% GET IMMEDIATELY ADJACENT NEIGHBOR PIXEL LABELS
		lPxUL = L(rowU, colL, n);
		lPxUC = L(rowU, colC, n);
		lPxUR = L(rowU, colR, n);
		lPxDL = L(rowD, colL, n);
		lPxDC = L(rowD, colC, n);
		lPxDR = L(rowD, colR, n);
		lPxCL = L(rowC, colL, n);
		lPxCR = L(rowC, colR, n);
		
		% ... AND LABEL PROBABILITY
		pPxUL = P(rowU, colL, n);
		pPxUC = P(rowU, colC, n);
		pPxUR = P(rowU, colR, n);
		pPxDL = P(rowD, colL, n);
		pPxDC = P(rowD, colC, n);
		pPxDR = P(rowD, colR, n);
		pPxCL = P(rowC, colL, n);
		pPxCR = P(rowC, colR, n);
		
		% ... AND REGIONAL-DIFFERENCE COUNTS
		cPxUL = C(rowU, colL, n);
		cPxUC = C(rowU, colC, n);
		cPxUR = C(rowU, colR, n);
		cPxDL = C(rowD, colL, n);
		cPxDC = C(rowD, colC, n);
		cPxDR = C(rowD, colR, n);
		cPxCL = C(rowC, colL, n);
		cPxCR = C(rowC, colR, n);
		
		% GET LOCAL FLUORESCENCE-INTENSITY GRADIENTS
		dlUC = lPxUC - lPx;
		dlUR = lPxUR - lPx;
		dlCR = lPxCR - lPx;
		dlDR = lPxDR - lPx;
		dlDC = lPxDC - lPx;
		dlDL = lPxDL - lPx;
		dlCL = lPxCL - lPx;
		dlUL = lPxUL - lPx;
		
		% GET SIGNIFICANT-DIFFERENCE-COUNT GRADIENTS
		dcUC = cPxUC - cPx;
		dcUR = cPxUR - cPx;
		dcCR = cPxCR - cPx;
		dcDR = cPxDR - cPx;
		dcDC = cPxDC - cPx;
		dcDL = cPxDL - cPx;
		dcCL = cPxCL - cPx;
		dcUL = cPxUL - cPx;
		
% F = int16(bitshift(F,-1));
% Fsplit = int16(bitshift(uint16(F), -1)) .* fix(rsdCount/countThresh);
% [Fx,Fy,Ft] = gradient(Fsplit);
% pUnstable = abs(Fx)/mean(abs(Fx(:))) + abs(Fy)/mean(abs(Fy(:)));
% pUnstable = 1/2 * (single(abs(Fx))/max(single(abs(Fx(:)))) + single(abs(Fy))/max(single(abs(Fy(:)))));
% bw = rsdCount>26 & pUnstable<.1;
% [Fx,Fy,Ft] = gradient(int16(bitshift(F,-1));
% Fpack = typecast(
% [Px,Py] = arrayfun( @rideGradientPeak2Edge,...
% 	F, rsdCount, rowSubs, colSubs, frameSubs);

% Px = arrayfun( @hybridMedFiltPx,...
% 	Px, rowSubs, colSubs, frameSubs);
% 
% Py = arrayfun( @hybridMedFiltPy,...
% 	Py, rowSubs, colSubs, frameSubs);


% ==================================================
% LABEL-PROBABILITY ESTIMATION & PROPAGATION
% ==================================================
	function [peakDx,peakDy] = rideGradientPeak2Edge(fPx, cPx, rowC, colC, n)
		
		% 		fPx = int16(fPx);
		maxR = 8;
		
		edgeDx = int16(0);
		edgeDy = int16(0);
		
		peakDx = int16(0);
		peakDy = int16(0);
		
		r = int16(1);
		
		bPeakL = true;
		bPeakR = true;
		bPeakU = true;
		bPeakD = true;
		
		bEdgeL = true;
		bEdgeR = true;
		bEdgeU = true;
		bEdgeD = true;
		
		dfL = int16(0);
		dfR = int16(0);
		dfU = int16(0);
		dfD = int16(0);
		dcL = int16(0);
		dcR = int16(0);
		dcU = int16(0);
		dcD = int16(0);
		
		while r<maxR
			
			% CALCULATE SUBSCRIPTS FOR SURROUNDING-PIXELS TO SAMPLE
			rowU = max( 1, rowC-r);
			rowD = min( numRows, rowC+r);
			colL = max( 1, colC-r);
			colR = min( numCols, colC+r);
			
			% GET EXTENDING NEIGHBOR PIXEL INTENSITIES
			fPxUL = F(rowU, colL, n);
			fPxUC = F(rowU, colC, n);
			fPxUR = F(rowU, colR, n);
			fPxDL = F(rowD, colL, n);
			fPxDC = F(rowD, colC, n);
			fPxDR = F(rowD, colR, n);
			fPxCL = F(rowC, colL, n);
			fPxCR = F(rowC, colR, n);
			
			% COMPUTE FLUORESCENCE-INTENSITY GRADIENTS
			dfUC = fPxUC - fPx;
			dfUR = fPxUR - fPx;
			dfCR = fPxCR - fPx;
			dfDR = fPxDR - fPx;
			dfDC = fPxDC - fPx;
			dfDL = fPxDL - fPx;
			dfCL = fPxCL - fPx;
			dfUL = fPxUL - fPx;
			
			% UPDATE DIRECTIONAL FLUORESCENCE INTENSITY GRADIENTS
			dfUpdateL = (max(dfUL,dfCL) + max(dfCL,dfDL))/2;
			dfUpdateR = (max(dfUR,dfCR) + max(dfCR,dfDR))/2;
			dfUpdateU = (max(dfUL,dfUC) + max(dfUC,dfUR))/2;
			dfUpdateD = (max(dfDL,dfDC) + max(dfDC,dfDR))/2;
			
			% GET REGIONAL-DIFFERENCE COUNTS
			cPxUL = rsdCount(rowU, colL, n);
			cPxUC = rsdCount(rowU, colC, n);
			cPxUR = rsdCount(rowU, colR, n);
			cPxDL = rsdCount(rowD, colL, n);
			cPxDC = rsdCount(rowD, colC, n);
			cPxDR = rsdCount(rowD, colR, n);
			cPxCL = rsdCount(rowC, colL, n);
			cPxCR = rsdCount(rowC, colR, n);
			
			% COMPUTE SIGNIFICANT-DIFFERENCE-COUNT GRADIENTS
			dcUC = cPxUC - cPx;
			dcUR = cPxUR - cPx;
			dcCR = cPxCR - cPx;
			dcDR = cPxDR - cPx;
			dcDC = cPxDC - cPx;
			dcDL = cPxDL - cPx;
			dcCL = cPxCL - cPx;
			dcUL = cPxUL - cPx;
			
			% UPDATE DIRECTIONAL DIFF-COUNT GRADIENTS
			dcUpdateL = (max(dcUL,dcCL) + max(dcCL,dcDL))/2;
			dcUpdateR = (max(dcUR,dcCR) + max(dcCR,dcDR))/2;
			dcUpdateU = (max(dcUL,dcUC) + max(dcUC,dcUR))/2;
			dcUpdateD = (max(dcDL,dcDC) + max(dcDC,dcDR))/2;
			
			bPeakL = bPeakL && (dfUpdateL > dfL) && (dcUpdateL >= dcL);
			bPeakR = bPeakR && (dfUpdateR > dfR) && (dcUpdateR >= dcR);
			bPeakU = bPeakU && (dfUpdateU > dfU) && (dcUpdateU >= dcU);
			bPeakD = bPeakD && (dfUpdateD > dfD) && (dcUpdateD >= dcD);
			
			
			dfX = int16(xor(bPeakL,bPeakR)) * (int16(bPeakR)-int16(bPeakL));
			dfY = int16(xor(bPeakU,bPeakD)) * (int16(bPeakD)-int16(bPeakU));
			
			% UPDATE
			if (dfX ~= 0)
				peakDx = r*dfX;
			end
			if (dfY ~= 0)
				peakDy = r*dfY;
			end
			r = r + 1;
			dfL = dfUpdateL;
			dfR = dfUpdateR;
			dfU = dfUpdateU;
			dfD = dfUpdateD;
			dcL = dcUpdateL;
			dcR = dcUpdateR;
			dcU = dcUpdateU;
			dcD = dcUpdateD;
			
			
		end
		
		
	end

	function peakDx = hybridMedFiltPx(peakDx, rowC, colC, n)
		
		% GET CURRENT/CENTER PIXEL FROM F (read-only)
		% 		fPx = F(rowC, colC, n)
		
		% ------------------------------------------------
		% CALCULATE SUBSCRIPTS FOR ADJACENT/NEIGHBORING-PIXELS (8-CONNECTED)
		rowU = max( 1, rowC-1);
		rowD = min( numRows, rowC+1);
		colL = max( 1, colC-1);
		colR = min( numCols, colC+1);
		
		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
		fPxUL = Px(rowU, colL, n); % X
		fPxUC = Px(rowU, colC, n); % +
		fPxUR = Px(rowU, colR, n); % X
		fPxDL = Px(rowD, colL, n); % X
		fPxDC = Px(rowD, colC, n); % +
		fPxDR = Px(rowD, colR, n); % X
		fPxCL = Px(rowC, colL, n); % +
		fPxCR = Px(rowC, colR, n); % +
		
		% APPLY HYBRID MEDIAN FILTER (X+)
		mmHV = (max(min(fPxUC,fPxDC),min(fPxCL,fPxCR)) ...
			+ min(max(fPxUC,fPxDC),max(fPxCL,fPxCR))) / 2;
		mmXX = (max(min(fPxUL,fPxDL),min(fPxUR,fPxDR)) ...
			+ min(max(fPxUL,fPxDL),max(fPxUR,fPxDR))) / 2;
		peakDx = min( min(max(peakDx,mmHV),max(peakDx,mmXX)), max(mmHV,mmXX));
		
	end

	function peakDy = hybridMedFiltPy(peakDy, rowC, colC, n)
		
		% GET CURRENT/CENTER PIXEL FROM F (read-only)
		% 		fPx = F(rowC, colC, n)
		
		% ------------------------------------------------
		% CALCULATE SUBSCRIPTS FOR ADJACENT/NEIGHBORING-PIXELS (8-CONNECTED)
		rowU = max( 1, rowC-1);
		rowD = min( numRows, rowC+1);
		colL = max( 1, colC-1);
		colR = min( numCols, colC+1);
		
		% GET IMMEDIATELY ADJACENT NEIGHBOR PIXELS
		fPxUL = Py(rowU, colL, n); % X
		fPxUC = Py(rowU, colC, n); % +
		fPxUR = Py(rowU, colR, n); % X
		fPxDL = Py(rowD, colL, n); % X
		fPxDC = Py(rowD, colC, n); % +
		fPxDR = Py(rowD, colR, n); % X
		fPxCL = Py(rowC, colL, n); % +
		fPxCR = Py(rowC, colR, n); % +
		
		% APPLY HYBRID MEDIAN FILTER (X+)
		mmHV = (max(min(fPxUC,fPxDC),min(fPxCL,fPxCR)) ...
			+ min(max(fPxUC,fPxDC),max(fPxCL,fPxCR))) / 2;
		mmXX = (max(min(fPxUL,fPxDL),min(fPxUR,fPxDR)) ...
			+ min(max(fPxUL,fPxDL),max(fPxUR,fPxDR))) / 2;
		peakDy = min( min(max(peakDy,mmHV),max(peakDy,mmXX)), max(mmHV,mmXX));
		
	end


end






% gradient -> [Fx,Fy,Ft] = gradient(single(F))		n8[10ms]  n2[6ms]		n4[7.5ms]
% gradient -> [Fx,Fy] = gradient(F)								n8[10ms]   t = 4.4 + 1.4n
% del2 ->			Dxy = del2(F)												n8[74ms]



% P = int8(...
% 			sign(regPxUL) * single(abs(regPxUL)>b) ...
% 			+ sign(regPxUC) * single(abs(regPxUC)>b) ...
% 			+ sign(regPxUR) * single(abs(regPxUR)>b) ...
% 			+ sign(regPxCL) * single(abs(regPxCL)>b) ...
% 			+ sign(regPxCR) * single(abs(regPxCR)>b) ...
% 			+ sign(regPxDL) * single(abs(regPxDL)>b) ...
% 			+ sign(regPxDC) * single(abs(regPxDC)>b) ...
% 			+ sign(regPxDR) * single(abs(regPxDR)>b) );










% INCREMENT DISTANCE TO PEAK OR EDGE
% 			dfL = dfL && ((fPxUL>fPx)||(fPxCL>fPx)||(fPxDL>fPx));
% 			dfR = dfR && ((fPxUR>fPx)||(fPxCR>fPx)||(fPxDR>fPx));
% 			dfU = dfU && ((fPxUL>fPx)||(fPxUC>fPx)||(fPxUR>fPx));
% 			dfD = dfD && ((fPxDL>fPx)||(fPxDC>fPx)||(fPxDR>fPx));
% 			dfL = dfL && ((dfUL>0)||(dfCL>0)||(dfDL>0));
% 			dfR = dfR && ((dfUR>0)||(dfCR>0)||(dfDR>0));
% 			dfU = dfU && ((dfUL>0)||(dfUC>0)||(dfUR>0));
% 			dfD = dfD && ((dfDL>0)||(dfDC>0)||(dfDR>0));




% 			dfLmaxNew = max(max(dfUL,dfCL),dfDL) - dfLmax;
% 			dfRmaxNew = max(max(dfUR,dfCR),dfDR) - dfRmax;
% 			dfUmaxNew = max(max(dfUL,dfUC),dfUR) - dfUmax;
% 			dfDmaxNew = max(max(dfDL,dfDC),dfDR) - dfDmax;

% P = single(pdcData)./single(abs(pxData)+abs(pyData)+32).*single(pdcData>26);
% Pmean = mean(P,3);
% Pml = bsxfun(@min, Pmean, P);
% rowPeak = bsxfun(@plus, int16(1:1024)', int16(pyData));
% colPeak = bsxfun(@plus, int16(1:1024), int16(pxData));
% Plabel = watershed(1-Pmean);
% rowPeak = reshape(rowPeak, 1024*1024,[]);
% colPeak = reshape(colPeak, 1024*1024,[]);

% 	[L, labelMax] = bwlabel(bwmorph( sum(rsdCount>countThresh, 3) > (numFrames/2), 'close'));
	% else
% 	labelMax = max(L(:));