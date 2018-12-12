function [vid, xc, prealign] = alignVid2Mean(vid, varargin)
sz = min(size(vid(1).cdata));

try
  if nargin < 2
	 cropBox = getRobustWindow(vid, sz/3); % 1024/3 -> 44ms/frame
	 template = [];
  else
	 prealign = varargin{1};
	 template = gpuArray( prealign.template );
	 cropBox = prealign.cropBox;
  end
  croppedVid = arrayfun(@(x)(imcrop(x.cdata, cropBox)), vid, 'UniformOutput',false);
	 	 
  maxOffset = floor(min(size(croppedVid{1}))/10);
  ysub = maxOffset+1 : size(croppedVid{1},1)-maxOffset;
  xsub = maxOffset+1 : size(croppedVid{1},2)-maxOffset;
  yFrameSub = maxOffset+1 : size(vid(1).cdata,1)+maxOffset;
  xFrameSub = maxOffset+1 : size(vid(1).cdata,2)+maxOffset;
  
  if isempty(template)
	 vidMean = croppedVid{1};
	 template = gpuArray(im2single(vidMean(ysub,xsub)));
  end
  
%   [vidCropped(1:numel(croppedVid)).cdata] = deal(croppedVid{:});
%   [vidCropped(1:numel(croppedVid)).frame] = deal(vid.frame);

  offsetShift = min(size(template)) + maxOffset;
  if isfield(vid,'frame')
	 frameMeanContribution = 1./[vid.frame];
  else
	 frameMeanContribution = 1./[1:numel(vid)];
  end
  
  validMaxMask = [];
  N = numel(vid);
  xc(N).cmax = zeros(N,1);
  xc(N).xoffset = zeros(N,1);
  xc(N).yoffset = zeros(N,1);
  h = waitbar(0,  sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%f secs/frame)',1,N,0));
  t=hat;
  
  for k = 1:numel(vid)
	 try
		movingFrame = gpuArray(croppedVid{k});
		movingFrame = im2single(movingFrame);
		c = normxcorr2(template, movingFrame);
		% Restrict available peaks in xcorr matrix
		if isempty(validMaxMask)
		  validMaxMask = false(size(c));
		  validMaxMask(offsetShift-maxOffset:offsetShift+maxOffset, offsetShift-maxOffset:offsetShift+maxOffset) = true;
		end
		c(~validMaxMask) = false;
		c(c<0) = false;
		% find peak in cross correlation
		[cmax, imax] = max(abs(c(:)));
		[ypeak, xpeak] = ind2sub(size(c),imax(1));
		% account for offset from padding?
		xoffset = xpeak - offsetShift;
		yoffset = ypeak - offsetShift;
		% APPLY OFFSET TO TEMPLATE AND ADD TO VIDMEAN
		adjustedFrame = movingFrame(ysub+yoffset , xsub+xoffset);
% 		imagesc(circshift(movingFrame(ysub,xsub),-[yoffset xoffset]) - template), colorbar
		ndt = frameMeanContribution(k);
		template = adjustedFrame*ndt + template*(1-ndt);
		xc(k).cmax = gather(cmax);
		dx = gather(xoffset);
		dy = gather(yoffset);
		xc(k).xoffset = dx;
		xc(k).yoffset = dy;
		% APPLY OFFSET TO VIDEO STRUCT
		padFrame = padarray(vid(k).cdata, [maxOffset maxOffset], 'replicate', 'both');
		vid(k).cdata = padFrame(yFrameSub+yoffset, xFrameSub+xoffset);
		waitbar(k/N, h, ...
		  sprintf('Generating normalized cross-correlation offset. Frame %g of %g (%0.1f ms/frame)',...
		  k,N,1000*(hat-t)));
		t=hat;
	 catch me
		disp(me.message)
		keyboard
	 end
  end
  delete(h);
  prealign.template = gather( template );
  prealign.cropBox = cropBox;
  
catch me
  disp(me.message);
  keyboard
end



% hTranslate = vision.GeometricTranslator( ...
%                               'OutputSize', 'Same as input image', ...
%                               'OffsetSource', 'Input port');
% Stabilized = step(hTranslate, input, fliplr(Offset));