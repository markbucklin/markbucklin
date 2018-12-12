function vid = generateDifferenceImage(vid, varargin)

if nargin < 2
  impc = prctile(single(cat(3,vid.cdata)),1:100,3);
else
  impc = varargin{1};
end
N = numel(vid);
inputDataType = class(vid(1).cdata);
if isa(vid(1).cdata, 'integer')
   inputRange = getrangefromclass(vid(1).cdata);
else
   inputRange = [min(min( cat(1,vid.cdata), [],1), [],2) , max(max( cat(1,vid.cdata), [],1), [],2)];
end

% minImage = min(cat(3,vid.cdata),[],3);
% minImage = cast( mean(impc(:,:,1:20),3), inputDataType);
% maxImage = cast( mean(impc(:,:,99:100),3), inputDataType);
minImage = mat2gray(mean(impc(:,:,1:10),3), inputRange);
maxImage = mat2gray(mean(impc(:,:,99:100),3), inputRange);
minDiffOffset = mean(maxImage(:));
h = waitbar(0,  sprintf('Generating difference image. Frame %g of %g (%0.1f ms/frame)',1,N,0));
t=hat;
for k=1:N,
  % 	vid(k).cdata = imlincomb(1,vid(k).cdata, -1, minImage, 1);
  %   im = mat2gray(gpuArray(vid(k).cdata), inputRange);
  im = mat2gray(vid(k).cdata, inputRange);
  im = imlincomb(1, im, -1, minImage, minDiffOffset);  
  im(im<0) = 0;
  %   vid(k).cdata = gather(single( im ./ maxImage ));
%   maxImage = maxImage+mean(maxImage(:));
%   im = single( im ./ maxImage );
%   im(im>1) = 1;
  vid(k).cdata = im;
  
  waitbar(k/N, h, ...
	 sprintf('Generating difference image. Frame %g of %g (%0.1f ms/frame)',k,N,1000*(hat-t)));
  t=hat;
end
delete(h)

% ~18 ms/frame on CPU vs 12.5 ms/frame on GPU