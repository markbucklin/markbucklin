function [data, minImage] = subtractRunningMin(data, minImage)

if nargin < 2
  minImage = data(:,:,1);
end
N = size(data,3);
% inputDataType = class(data);

multiWaitbar('Generating difference image',0);

for k=1:N,
 im = data(:,:,k);
 minImage = min(cat(3,im, minImage),[],3);
 im = im - minImage;
 %    im(im<0) = 0;
 %   vid(k).cdata = gather(single( im ./ maxImage ));
 %   maxImage = maxImage+mean(maxImage(:));
 %   im = single( im ./ maxImage );
 %  im(im>1) = 1;
 data(:,:,k) = im;
  
  multiWaitbar('Generating difference image',k/N);
end
multiWaitbar('Generating difference image','Close');


% ~18 ms/frame on CPU vs 12.5 ms/frame on GPU