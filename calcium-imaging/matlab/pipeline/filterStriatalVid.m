function vid = filterStriatalVid(vid, varargin)
% vid = vc.prefilt
if nargin > 1
  minmax = varargin{1};
  imin = minmax(1);
  imax = minmax(2);
else
  stat = getVidStats(vid);
  imin = single(min(stat.Min(:)));
  imax = max(stat.Max(:));
end
iscale = single(getrangefromclass(vid(1).cdata)/double(imax));
iscale = iscale(2);
N=21;
s1 = 1.5;
s2 = s1 + 3;
% USE SIMPLE DIFFERENCE OF GAUSSIANS
H = fspecial('gaussian',[N N], s1) - fspecial('gaussian',[N N], s2);
H = H./max(H(:));
% USE FWIND2
% [f1,f2] = freqspace(21,'meshgrid');
% Hd = ones(21); 
% r = sqrt(f1.^2 + f2.^2);
% Hd((r<0.1)|(r>.5)) = 0;
% win = fspecial('gaussian',N,2);
% win = win ./ max(win(:));  % Make the maximum window value be 1.
% H = fwind2(Hd,win);
% freqz2(H)
H = gpuArray(H);

h = waitbar(0, 'Filtering video data');
runningMin = 0;
for k=1:numel(vid)
  waitbar(k/numel(vid), h);
  im = gpuArray(vid(k).cdata);
  im = (single(im) - imin) * iscale;
  im = imfilter(im, H, 'replicate');
  % Set min to 0 (not doing so apparently produces a higher contrast image...? but loses lower end of data)
  %   thisMin = min(im(:));
  %   if thisMin < runningMin
  % 	 runningMin = thisMin;
  %   end
  %   im = im - runningMin;
  vid(k).cdata = gather(uint16(im));
end
delete(h)
% playVidStruct(vid)