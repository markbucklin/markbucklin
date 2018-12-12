function xc = correctMotionNormXcorrSubregion(datainput, fcnparam)
% FLUOPRO
global FPOPTION

% ------------------------------------------------------------------------------------------
% CHECK INPUT - CONVERT DATA TO NUMERIC 3D-ARRAY
% ------------------------------------------------------------------------------------------
if isstruct(datainput)
   loadFramesFromMappedMem = true;
   firstFrame = datainput(1).cdata;
   N = numel(datainput);
else
   loadFramesFromMappedMem = false;
   data = datainput;
   firstFrame = data(:,:,1);  
   N = size(data,3);
end

[nRows, nCols] = size(firstFrame);

% ------------------------------------------------------------------------------------------
% DATA-DESCRIPTION VARIABLES
% ------------------------------------------------------------------------------------------
if nargin < 2
   fcnparam.subPixelFactor = 10;
   fcnparam.maxDisplacement = ceil(min([nRows,nCols])/50);%11 pixels
   fcnparam.templateSize = ceil(min([nRows,nCols])/20);%41pixels
   fcnparam.nVerticalSubRegions = 2;
   fcnparam.nHorizontalSubRegions = 2;
   fcnparam.corrCoeffTolerance = .85;
end

% if nargin < 2
%    if FPOPTION.allInteractive
% 	  waitfor(msgbox(['Select a SMALL region to measure image movement.',...
% 		 'Motion will be extrapolated and applied to the entire frame']))
% 	  [~, crFixed] = imcrop(imadjust(datainput(1).cdata));
% 	  close(gcf)
% 	  drawnow
%    else
% 	  
%    end
% else
% 	crFixed = varargin{1};
% end
% crFixed = [floor(crFixed(1:2)) , ceil(crFixed(3:4))];
% ACCOMODATE A LARGE CORRELATION REGION BY REDUCING SUBPIXELATION
% fixedWidth = crFixed(3)+1;
% fixedHeight = crFixed(4)+1;
% nFixedPix = fixedWidth*fixedHeight*subPixelFactor^2;
% while (nFixedPix > fixedPixCountMax)
% 	subPixelFactor = subPixelFactor - 1;
% 	nFixedPix = fixedWidth*fixedHeight*subPixelFactor^2;
% 	fprintf('Reducing subpixellation factor used for xcorr motion correction,\n\tsubPixelFactor: %g\n',...
% 	subPixelFactor)
% end


% DEFINE FUNCTIONS FOR FILTERING
gaussFilt = @(X) imfilter(X,fspecial('gaussian', 15, 1.5));

%77777777 TODO: change cell-partitions to fcnhandle-indexed array
% PARTITION FRAMES INTO 3X3 SUBARRAY
srvec = @(d,srd) [floor(d/srd).*ones(srd-1,1) ; (floor(d/srd)+rem(d,srd))];
splitSubReg = @(I,srm,srn) mat2cell(I, srvec(size(I,1),srm), srvec(size(I,2),srn), ones(size(I,3),1));
% frameBoundaries = 
% getFrameBlock = @(k, m, n) 
% splitSubReg = @(I,nVertParts,nHorizParts) mat2cell(I, srvec(size(I,1),nVertParts), srvec(size(I,2),nHorizParts), ones(size(I,3),1));
% splitSubReg = @(I,srm,srn) mat2cell(I, srvec(size(I,1),srm), srvec(size(I,2),srn)); % (single-frame)
partitionedFrames = splitSubReg(data,fcnparam.nVerticalSubRegions ,fcnparam.nHorizontalSubRegions);
partFrameFixed = partitionedFrames(:,:,1);
partFrameFixed = partFrameFixed(:);
partFrameFirst = partFrameFixed;
nSubRegions = numel(partFrameFixed);

% FORM INITIAL SUBSCRIPTS INTO FIXED IMAGE (TEMPLATE) AND MOVING IMAGE
getSubsCenteredOn = @(csub,n) (floor(csub-n/2+1):floor(csub+n/2))'; 
maxShift = fcnparam.maxDisplacement;
fixedHeight = fcnparam.templateSize(1);
fixedWidth = fcnparam.templateSize(numel(fcnparam.templateSize));
movingHeight = fixedHeight + 2*maxShift;
movingWidth = fixedWidth + 2*maxShift;
[nSubRegionRows,nSubRegionCols] = cellfun(@size, partFrameFixed);
subRegionCenterPoint = [ceil(nSubRegionRows./2), ceil(nSubRegionCols./2)]; %[rowidx, colidx]
fixedRowSubs = repmat(getSubsCenteredOn(subRegionCenterPoint, fixedHeight),1,nSubRegions);
fixedColSubs = repmat(getSubsCenteredOn(subRegionCenterPoint, fixedWidth),1,nSubRegions);
movingRowSubs = repmat(getSubsCenteredOn(subRegionCenterPoint, movingHeight),1,nSubRegions);
movingColSubs = repmat(getSubsCenteredOn(subRegionCenterPoint, movingHeight),1,nSubRegions);
getNewCenterPoint = @() [...
floor(movingHeight/2+1) + floor(rand(1)*(min(nSubRegionRows)-movingHeight)) , ...
floor(movingWidth/2+1) + floor(rand(1)*(min(nSubRegionCols)-movingWidth))];
addShift2Subs = @(submat,cps,n) bsxfun(@plus, submat, circshift([cps,zeros(1,size(submat,2)-1,'like',cps)], n-1, 2));

% SUBSCRIPTS AND PREALLOCATION FOR OUTPUT
stationaryRow = (movingHeight+fixedHeight)/2 ;
stationaryCol = (movingWidth+fixedWidth)/2;
validRows = getSubsCenteredOn(stationaryRow,2*(maxShift-2));
validCols = getSubsCenteredOn(stationaryCol,2*(maxShift-2));
validMask = gpuArray.false(movingHeight+fixedHeight-1, movingWidth+fixedWidth-1);
validMask(validRows,validCols) = true;
invalidMask = ~validMask;
uLast = zeros(nSubRegions,2);
cMax = NaN(N,nSubRegions);
yPeak = NaN(N,nSubRegions);
xPeak = NaN(N,nSubRegions);
Uy =  NaN(N,nSubRegions);
Ux =  NaN(N,nSubRegions);
cpY = NaN(N,nSubRegions);
cpX = NaN(N,nSubRegions);

% SUBSCRIPTS FOR INTERPOLATION AROUND XCORR-PEAK -> SUBPIXEL ACCURACY
subPix = fcnparam.subPixelFactor; %10
pkR = 3;
[X,Y] = meshgrid(-pkR:pkR);
[Xq,Yq] = meshgrid(-pkR:1/subPix:pkR);
ccTol = fcnparam.corrCoeffTolerance;



hWait = waitbar(0,  sprintf('Detecting Motion using Normalized Cross-Correlation (NormXCorr) %g of %g (%f secs/frame)',1,N,0)); tic
for kFrame=1:N
   partFrameMoving = partitionedFrames(:,:,kFrame);
   partFrameMoving = partFrameMoving(:);
   for kSubReg = 1:nSubRegions
	  % LOAD SUBSCRIPTS INTO FIXED & MOVING IMAGE-PATCHES
	  mFix = fixedRowSubs(:,kSubReg);	  
	  nFix = fixedColSubs(:,kSubReg);
	  mMov = movingRowSubs(:,kSubReg);
	  nMov = movingColSubs(:,kSubReg);
	  % LOAD AND FILTER FIXED & MOVING IMAGE-PATCHES
	  fixedPatch = gaussFilt(gpuArray(partFrameFixed{kSubReg}(mFix,nFix)));
	  movingPatch = gaussFilt(gpuArray(partFrameMoving{kSubReg}(mMov,nMov)));
	  %*** TODO: repeat this until cmax > threshold
	  c = normxcorr2(fixedPatch, movingPatch);
	  c(invalidMask) = 0;	  
	  [cmax, imax] = max(abs(c(:)));
	  %***
	  [ypeak, xpeak] = ind2sub(size(c),imax(1));
	  % INTERPOLATE FOR SUBPIXEL ACCURACY
	  cPk3 = c(ypeak-pkR:ypeak+pkR, xpeak-pkR:xpeak+pkR);
	  cPkSubPix = interp2(X,Y,cPk3,Xq,Yq);
	  [~, iSubPixMax] = max(abs(cPkSubPix(:)));	  	  
	  [ypeakSubPix, xpeakSubPix] = ind2sub(size(cPkSubPix),iSubPixMax(1));
	  ySubPixComponent = (ypeakSubPix - pkR*subPix) / subPix;
	  xSubPixComponent = (xpeakSubPix - pkR*subPix) / subPix;
	  ypeak = ypeak + ySubPixComponent;
	  xpeak = xpeak + xSubPixComponent;
	  % RETRIEVE FROM GPU AND STORE RESULTS
	  cMax(kFrame,kSubReg) = gather(cmax);
	  yPeak(kFrame,kSubReg) = gather(ypeak);
	  xPeak(kFrame,kSubReg) = gather(xpeak);
   end
   
   % RECORD MOTION-VECTORS & CENTER-POINTS
   Uy(kFrame,:) = yPeak(kFrame,:) - stationaryRow;
   Ux(kFrame,:) = xPeak(kFrame,:) - stationaryCol;
   cpY(kFrame,:) = subRegionCenterPoint(:,1)';
   cpX(kFrame,:) = subRegionCenterPoint(:,2)';
   
   % CHECK CONCENSUS AND SHIFT POOR PERFORMERS
   cframe = cMax(kFrame,:);
   uy = Uy(kFrame,:);
   ux = Ux(kFrame,:);
   uxy = [uy',ux'];
   ut = uxy - uLast;
   utTol = std(uxy(:));
   for kSubReg = 1:nSubRegions
	  %    while any(cframe<.5)
	  % 	  kUglySub = find(cframe<.5, 1, 'first');
	  if sum(abs(ut(kSubReg,:))) > utTol ...
			|| cframe(1,kSubReg) < ccTol
		  %*** make a function
		  % 		 kUglySub = kSubReg;
		 cframe(1,kSubReg) = NaN;
		 oldCenterPoint = subRegionCenterPoint(kSubReg,:);
		 newCenterPoint = getNewCenterPoint();
		 cpShift = newCenterPoint - oldCenterPoint;%[rowidx colidx]
		 subRegionCenterPoint(kSubReg,:) = newCenterPoint;
		 fixedRowSubs = addShift2Subs(fixedRowSubs, cpShift(1),kSubReg);
		 fixedColSubs = addShift2Subs(fixedColSubs, cpShift(2),kSubReg);
		 movingRowSubs = addShift2Subs(movingRowSubs, cpShift(1),kSubReg);
		 movingColSubs = addShift2Subs(movingColSubs, cpShift(2),kSubReg);
	  end
   end
   uLast = uxy;
   % USE PARTITIONED MOVING FRAME AS TEMPLATE FOR NEXT FRAME
   partFrameFixed = partFrameMoving;
   waitbar(kFrame/N, hWait,  sprintf('Detecting Motion using Normalized Cross-Correlation (NormXCorr) %g of %g (%f secs/frame)',kFrame,N,toc));
   tic
end
close(hWait)

xc.cpx = cpX;
xc.cpy = cpY;
xc.ux = Ux;
xc.uy = Uy;
xc.xpeak = xPeak;
xc.ypeak = yPeak;
xc.ccmax = cMax;



% %% GENERATE FIXED TEMPLATE FROM FIRST FRAME
% 
% fixed = gpuArray(imcrop(im2single(datainput(1).cdata),crFixed));
% fixed = imresize(fixed, subPixelFactor);
% 
% % sz2 = size(fixed,2);
% % sz1 = size(fixed,1);
% sz = min(size(fixed));
% N = numel(datainput);
% xc(N).cmax = [];
% xc(N).xoffset = [];
% xc(N).yoffset = [];
% h = waitbar(0,  sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%f secs/frame)',1,N,0));
% tic
% p = crFixed(3:4);
% crMoving = crFixed + [-p(1)/2 -p(2)/2 p(1) p(2)]; % added ./4
% fprintf('Fixed ROI: %g %g %g %g\n', crFixed)
% fprintf('Moving ROI: %g %g %g %g\n', crMoving)
% % crMoving = crFixed + [-maxOffset -maxOffset p(1)+2*maxOffset p(2)+2*maxOffset];
% %% REGISTER ALL FRAMES TO TEMPLATE BY FINDING PEAK OF CROSS-CORRELATION
% for k = 1:N
% 	moving = gpuArray(imcrop(datainput(k).cdata,crMoving));
% 	moving = im2single(moving);%nextfixed
% 	moving = imresize(moving, subPixelFactor);
% 	c = normxcorr2(fixed, moving);
% 	% find peak in cross correlation
% 	% make mask
% 	[cmax, imax] = max(abs(c(:)));
% 	[ypeak, xpeak] = ind2sub(size(c),imax(1));
% 	% account for offset from padding?
% 	%NEW
% % 	xoffset = xpeak-sz2;
% % 	yoffset = ypeak-sz1;
% 	yoffset = ypeak-sz;
% 	xoffset = xpeak-sz;
% 	%ENDNEW
% 	xc(k).cmax = gather(cmax);
% 	xc(k).xoffset = gather(xoffset)/subPixelFactor;
% 	xc(k).yoffset = gather(yoffset)/subPixelFactor;
% 	% check for impossibly large motion prediction
% 	if k>20
% 	  wildness(1) = abs(xc(k).xoffset - xc(k-1).xoffset) > 5*max(diff([xc(1:k-1).xoffset],1));
% 	  wildness(2) = abs(xc(k).yoffset - xc(k-1).yoffset) > 5*max(diff([xc(1:k-1).yoffset],1));
% 	  if any(wildness)
% 		 warning('Motion-correction using automated region selection failed. Switching to MANUAL')
% 		 keyboard
% 		 % 		 xc = generateXcOffset(vid);
% 		 % 		 return
% 	  end
% 	end
% 	
% 	waitbar(k/N, h, ...
% 		sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%f secs/frame)',k,N,toc));
% 	tic
% end
% 
% %% SUBTRACT ANY LARGE SHIFT FROM BASELINE
% x0 = mean(cat(1, xc.xoffset),1);
% y0 = mean(cat(1, xc.yoffset),1); % note: previously used x0 = xc(1).yoffset 
% for k = 1:N
% 	xc(k).xoffset = xc(k).xoffset - x0;
% 	xc(k).yoffset = xc(k).yoffset - y0;
% end
% 
% delete(h)
% h = handle(line(...
% 	'XData',[xc.xoffset],...
% 	'YData',[xc.yoffset],...
% 	'ZData',[xc.cmax],...
% 	'MarkerSize',4,...
% 	'Marker', '+'));
% pause(.5)
% close(gcf)
% % plot([xc.cmax])
% 
% 
% 
% 



