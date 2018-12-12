function [data, presubtract] = subtractRunningMean(data, presubtract)

if nargin < 2
  presubtract.meanImage = double(data(:,:,1));
  presubtract.nAv = 0;
  presubtract.offset = 1000;
%   dmr = range(data,3);
%   presubtract.offset = mean(dmr(:),'double');
end
N = size(data,3);
% inputDataType = class(data);
multiWaitbar('Generating difference image',0);
n = presubtract.nAv;
for k=1:N,
 im = double(data(:,:,k));
 nt = n / (n + 1);
 na = 1/(n + 1);
 presubtract.meanImage = na .*im + nt.*presubtract.meanImage;
 im = im - presubtract.meanImage + presubtract.offset;
 n = n + 1;
 %    im(im<0) = 0;
 %   vid(k).cdata = gather(double( im ./ maxImage ));
 %   maxImage = maxImage+mean(maxImage(:));
 %   im = double( im ./ maxImage );
 %  im(im>1) = 1;
 data(:,:,k) = uint16(im);
  
  multiWaitbar('Generating difference image',k/N);
end
multiWaitbar('Generating difference image','Close');
presubtract.nAv = n;

% ~18 ms/frame on CPU vs 12.5 ms/frame on GPU
% dmean = mean(data,3);
% difdata = bsxfun(@minus, data + circshift(data,1,3)./2 + circshift(data,-1,3)./2, uint16(dmean));
% difdatamc = bsxfun(@minus, data + circshift(data,1,3)./2 + circshift(data,-1,3)./2, uint16(dmean.*2)).*3;
% difdatamcs = difdatamc + cat(3,difdatamc(:,:,1),difdatamc(:,:,1:end-1)) + cat(3,difdatamc(:,:,2:end),difdatamc(:,:,end));
% difdatamcs = difdatamc + cat(3,difdatamc(:,:,1),difdatamc(:,:,1:end-1)) + cat(3,difdatamc(:,:,2:end),difdatamc(:,:,end));
% subdatasm = subdata + cat(3,subdata(:,:,1),subdata(:,:,1:end-1)) + cat(3,subdata(:,:,2:end),subdata(:,:,end));
% subdatasm = subdata + cat(3,subdata(:,:,1),subdata(:,:,1:end-1))./2 + cat(3,subdata(:,:,2:end),subdata(:,:,end))./2;
% difdatamcs = difdatamc + cat(3,difdatamc(:,:,1),difdatamc(:,:,1:end-1)) + cat(3,difdatamc(:,:,2:end),difdatamc(:,:,end));
