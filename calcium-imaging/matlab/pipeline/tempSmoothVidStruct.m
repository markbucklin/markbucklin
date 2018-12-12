function vid = tempSmoothVidStruct(vid, varargin)
try
  vidClass = class(vid(1).cdata);
  if nargin < 2
	 winReach = 3;
  else
	 winReach = varargin{1};
  end
  
  if isfield(vid,'issmoothed') && vid(1).issmoothed
	 warning('Video has already been temporally smoothed')
	 return
  end
  N = numel(vid)
  t=hat;
  h = waitbar(0,  sprintf('Temporally smoothing'));
  for k = 1:numel(vid),
	 im = mean(cat(3,vid(max(1,k-winReach):min(numel(vid),k+winReach)).cdata),3);
	 vid(k).cdata = cast(im,vidClass);
	 vid(k).issmoothed = true;
	 waitbar(k/N, h, sprintf('Temporally smoothing video. Frame: %g of %g (%f ms/frame)',...
		k, N, 1000*(hat-t)));
	 t=hat;
  end
catch me
  
end
delete(h)