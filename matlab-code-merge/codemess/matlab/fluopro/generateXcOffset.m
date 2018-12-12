function xc = correctMotionNormXcorrSubregion(vid, fcnparam)
% FLUOPRO

global FPOPTION

% ------------------------------------------------------------------------------------------
% CHECK INPUT - CONVERT DATA TO NUMERIC 3D-ARRAY
% ------------------------------------------------------------------------------------------
if isstruct(datainput)
   data = cat(3, datainput.cdata);
else
   data = datainput;
end

% ------------------------------------------------------------------------------------------
% DATA-DESCRIPTION VARIABLES
% ------------------------------------------------------------------------------------------
sz = size(data);
N = sz(3);
nPixPerFrame = sz(1) * sz(2);
inputDataType = class(data);

subPixelFactor = 10;
fixedPixCountMax = 3e5;
% maxOffset = 15;

if nargin < 2
	waitfor(msgbox(['Select a SMALL region to measure image movement.',...
		'Motion will be extrapolated and applied to the entire frame']))
	[~, crFixed] = imcrop(imadjust(vid(1).cdata));
	close(gcf)
	drawnow
else
	crFixed = varargin{1};
end
crFixed = round(crFixed);
%% ACCOMODATE A LARGE CORRELATION REGION BY REDUCING SUBPIXELATION
fixedWidth = crFixed(3)+1;
fixedHeight = crFixed(4)+1;
nFixedPix = fixedWidth*fixedHeight*subPixelFactor^2;
while (nFixedPix > fixedPixCountMax)
	subPixelFactor = subPixelFactor - 1;
	nFixedPix = fixedWidth*fixedHeight*subPixelFactor^2;
	fprintf('Reducing subpixellation factor used for xcorr motion correction,\n\tsubPixelFactor: %g\n',...
	subPixelFactor)
end

%% GENERATE FIXED TEMPLATE FROM FIRST FRAME
fixed = gpuArray(imcrop(im2single(vid(1).cdata),crFixed));
fixed = imresize(fixed, subPixelFactor);

% sz2 = size(fixed,2);
% sz1 = size(fixed,1);
sz = min(size(fixed));
N = numel(vid);
xc(N).cmax = [];
xc(N).xoffset = [];
xc(N).yoffset = [];
h = waitbar(0,  sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%f secs/frame)',1,N,0));
tic
p = crFixed(3:4);
crMoving = crFixed + [-p(1)/2 -p(2)/2 p(1) p(2)]; % added ./4
fprintf('Fixed ROI: %g %g %g %g\n', crFixed)
fprintf('Moving ROI: %g %g %g %g\n', crMoving)
% crMoving = crFixed + [-maxOffset -maxOffset p(1)+2*maxOffset p(2)+2*maxOffset];
%% REGISTER ALL FRAMES TO TEMPLATE BY FINDING PEAK OF CROSS-CORRELATION
for k = 1:N
	moving = gpuArray(imcrop(vid(k).cdata,crMoving));
	moving = im2single(moving);%nextfixed
	moving = imresize(moving, subPixelFactor);
	c = normxcorr2(fixed, moving);
	% find peak in cross correlation
	% make mask
	[cmax, imax] = max(abs(c(:)));
	[ypeak, xpeak] = ind2sub(size(c),imax(1));
	% account for offset from padding?
	%NEW
% 	xoffset = xpeak-sz2;
% 	yoffset = ypeak-sz1;
	yoffset = ypeak-sz;
	xoffset = xpeak-sz;
	%ENDNEW
	xc(k).cmax = gather(cmax);
	xc(k).xoffset = gather(xoffset)/subPixelFactor;
	xc(k).yoffset = gather(yoffset)/subPixelFactor;
	% check for impossibly large motion prediction
	if k>20
	  wildness(1) = abs(xc(k).xoffset - xc(k-1).xoffset) > 5*max(diff([xc(1:k-1).xoffset],1));
	  wildness(2) = abs(xc(k).yoffset - xc(k-1).yoffset) > 5*max(diff([xc(1:k-1).yoffset],1));
	  if any(wildness)
		 warning('Motion-correction using automated region selection failed. Switching to MANUAL')
		 keyboard
		 % 		 xc = generateXcOffset(vid);
		 % 		 return
	  end
	end
	
	waitbar(k/N, h, ...
		sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%f secs/frame)',k,N,toc));
	tic
end

%% SUBTRACT ANY LARGE SHIFT FROM BASELINE
x0 = mean(cat(1, xc.xoffset),1);
y0 = mean(cat(1, xc.yoffset),1); % note: previously used x0 = xc(1).yoffset 
for k = 1:N
	xc(k).xoffset = xc(k).xoffset - x0;
	xc(k).yoffset = xc(k).yoffset - y0;
end

delete(h)
h = handle(line(...
	'XData',[xc.xoffset],...
	'YData',[xc.yoffset],...
	'ZData',[xc.cmax],...
	'MarkerSize',4,...
	'Marker', '+'));
pause(.5)
close(gcf)
% plot([xc.cmax])







