function out = alignVidRecursive(vid)
idx = 1:numel(vid);
% adapted from sbxalign.m ( http://scanbox.wordpress.com/tag/matlab/ )
if (length(idx)==1)
  out.cdata = vid.cdata; % mean
  out.T = [0 0]; % no translation (identity)
  out.n = 1; % # of frames
else
  idxLeft = idx(1:floor(end/2)); % split into two groups
  idxRight = idx(floor(end/2)+1 : end);
  
  outLeft = alignVidRecursive(vid(idxLeft)); % align each group
  outRight = alignVidRecursive(vid(idxRight));
  
  
  [yOffset xOffset] = alignTwoFrames(outLeft.cdata,outRight.cdata); % align their means
  

  outLeft.cdata = circshift(outLeft.cdata,[yOffset xOffset]);

  
  delta = outRight.cdata-outLeft.cdata; % online update of the moments (read the Pebay paper)
  nLeft = outLeft.n;
  nRight = outRight.n;
  nTotal = nLeft + nRight;
  
  out.cdata = outLeft.cdata+delta*nRight/nTotal;
  
  out.T = [(ones(size(outLeft.T,1),1)*[yOffset xOffset] + outLeft.T) ; outRight.T]; % transformations
  out.n = nTotal; % number of images in A+B
  
end