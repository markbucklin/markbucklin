function [data, varargout] = correctMotionNormXcorrSequential(datainput, fcnparam)
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




% ------------------------------------------------------------------------------------------
% FUNCTION PARAMETERS (AUTO-GENERATED IF NOT PROVIDED AS INPUT)
% ------------------------------------------------------------------------------------------
if nargin < 2
   fcnparam.templateWindowSize = ceil(sz(1:2)./3);
   fcnparam.cropBox = selectWindowForMotionCorrection(data,fcnparam.templateWindowSize);
   fcnparam.maxOffset = ceil(min(fcnparam.templateWindowSize(1:2))/10);
   fcnparam.n = 0;
end

% ------------------------------------------------------------------------------------------
% CROP VIDEO - X/Y SUBSCRIPTS INTO LARGER FRAME (TODO)
% ------------------------------------------------------------------------------------------
ySubs = round(fcnparam.cropBox(2): (fcnparam.cropBox(2)+fcnparam.cropBox(4)-1)');
xSubs = round(fcnparam.cropBox(1): (fcnparam.cropBox(1)+fcnparam.cropBox(3)-1)');
if FPOPTION.useGpu
   croppedVid = gpuArray(data(ySubs,xSubs,:));
else
   croppedVid = data(ySubs,xSubs,:);
end
cropSize = size(croppedVid);

% ------------------------------------------------------------------------------------------
% CROP TEMPLATE - X/Y SUBSCRIPTS INTO SMALLER FRAME
% ------------------------------------------------------------------------------------------
edgeSep = floor(fcnparam.maxOffset);
ysub = edgeSep+1 : cropSize(1)-edgeSep;
xsub = edgeSep+1 : cropSize(2)-edgeSep;
yPadSub = edgeSep+1 : sz(1)+edgeSep;
xPadSub = edgeSep+1 : sz(2)+edgeSep;
if ~isfield(fcnparam, 'consistent') || ~isfield(fcnparam.consistent, 'template')
   vidMean = single(croppedVid(:,:,1));%im2single?
   templateFrame = vidMean(ysub,xsub);
else   
   templateFrame = fcnparam.consistent.template;
end
if FPOPTION.useGpu
	  templateFrame = gpuArray(templateFrame);   
end
offsetShift = min(size(templateFrame)) + edgeSep;
validMaxMask = [];

% ------------------------------------------------------------------------------------------

% ------------------------------------------------------------------------------------------
cmax = zeros(N,1);
xshift = zeros(N,1);
yshift = zeros(N,1);
n0 = fcnparam.n;
nf = fcnparam.n; % used to weight contribution to moving average for repeat function calls

% ------------------------------------------------------------------------------------------

% ------------------------------------------------------------------------------------------
hWaitBar = waitbar(0, 'Correcting Motion using Normalized Cross-Correlation');
for k = 1:N
   waitbar(k/N, hWaitBar)
   movingFrame = single(croppedVid(:,:,k));%im2single?
   c = normxcorr2(templateFrame, movingFrame);
   % Restrict available peaks in xcorr matrix
   if isempty(validMaxMask)
	  if FPOPTION.useGpu
		 validMaxMask = gpuArray.false(size(c));
	  else
		 validMaxMask = false(size(c));
	  end
	  validMaxMask(offsetShift-edgeSep:offsetShift+edgeSep, offsetShift-edgeSep:offsetShift+edgeSep) = true;
   end
   c(~validMaxMask) = false;
   c(c<0) = false;
   % find peak in cross correlation
   [maxccval, imax] = max(abs(c(:)));
   [ypeak, xpeak] = ind2sub(size(c),imax(1));
   % account for offset from padding?
   xoffset = xpeak - offsetShift;
   yoffset = ypeak - offsetShift;
   % APPLY OFFSET TO TEMPLATE AND ADD TO VIDMEAN 
   adjustedFrame = movingFrame(ysub+yoffset , xsub+xoffset);
   % 		imagesc(circshift(movingFrame(ysub,xsub),-[yoffset xoffset]) - templateFrame), colorbar
   nt = nf / (nf + 1);
   na = 1/(nf + 1);
   templateFrame = templateFrame*nt + adjustedFrame*na;
   nf = nf + 1;
   dx = gather(xoffset);
   dy = gather(yoffset);
   cmax(k) = gather(maxccval);
   xshift(k) = dx;
   yshift(k) = dy;
   % APPLY OFFSET TO FRAME
   if dx~=0 || dy~=0
	  padFrame = padarray(data(:,:,k), [edgeSep edgeSep], 'replicate', 'both');%could also using vision padder system object
	  data(:,:,k) = padFrame(yPadSub+dy, xPadSub+dx);
   end
end
close(hWaitBar)

% ------------------------------------------------------------------------------------------
% STORE CONSISTENT VALUES FOR SUBSEQUENT CALLS AND RETURN
% ------------------------------------------------------------------------------------------
fcnparam.n = nf;
fcnparam.consistent.template = gather(templateFrame);
fcnparam.consistent.dx(n0+1:nf) = xshift(:);
fcnparam.consistent.dy(n0+1:nf) = yshift(:);
fcnparam.consistent.cmax(n0+1:nf) = cmax(:);
if nargout > 1
   varargout{1} = fcnparam;
end









% ################################################################
   function winRectangle = selectWindowForMotionCorrection(data, winsize)
	  if numel(winsize) <2
		 winsize = [winsize winsize];
	  end	  
	  winsize = ceil(winsize);
	  win.edgeOffset = round(sz(1:2)./4);
	  win.rowSubs = win.edgeOffset(1):sz(1)-win.edgeOffset(1);
	  win.colSubs =  win.edgeOffset(2):sz(2)-win.edgeOffset(2);
	  stat.Range = range(data, 3);
	  stat.Min = min(data, [], 3);
	  win.filtSize = min(winsize)/2;
	  imRobust = double(imfilter(rangefilt(stat.Min),fspecial('average',win.filtSize))) ./ double(imfilter(stat.Range, fspecial('average',win.filtSize)));	  
	  gaussmat = fspecial('gaussian', size(imRobust), 1);
	  gaussmat = gaussmat * (mean2(imRobust) / max(gaussmat(:)));
	  imRobust = imRobust .*gaussmat;
	  imRobust = imRobust(win.rowSubs, win.colSubs);
	  [~, maxInd] = max(imRobust(:));
	  [win.rowMax, win.colMax] = ind2sub([length(win.rowSubs) length(win.colSubs)], maxInd);
	  win.rowMax = win.rowMax + win.edgeOffset(1);
	  win.colMax = win.colMax + win.edgeOffset(2);
	  win.rows = win.rowMax-winsize(1)/2+1 : win.rowMax+winsize(1)/2;
	  win.cols = win.colMax-winsize(2)/2+1 : win.colMax+winsize(2)/2;
	  winRectangle = [win.cols(1) , win.rows(1) , win.cols(end)-win.cols(1) , win.rows(end)-win.rows(1)];
   end




if nargout > 1
   varargout{1} = fcnparam;
end
end








% mccomp = cat(3, permute(shiftdim(mcdata,-1),[2 3 1 4]), permute(shiftdim(data,-1),[2 3 1 4]), repmat(cast(mean(data, 3),'like',data),[1 1 1 size(data,3)]));






