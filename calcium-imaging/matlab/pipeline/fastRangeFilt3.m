function rfDataMean = fastRangeFilt3(data, nTemp, nSpat)
if nargin < 2
   nTemp = 5;
end
if nargin < 3
   nSpat = 5;
end
[nrows, ncols, N] = size(data);
inputDataType = class(data);
% ON-PHASE
nChunk1 = floor(N/nTemp);
data1 = permute(reshape( data(:,:,1:nChunk1*nTemp), nrows, ncols, nTemp, []), [3 1 2 4]);
cdata1 = imfilter(single(squeeze(range(data1, 1))), fspecial('average',nSpat), 'replicate');
rfMean1 = mean(cdata1,3);
% OFF-PHASE
offset = ceil(nTemp/2);
nChunk2 = floor((N-offset)/nTemp);
data2 = permute(reshape( data(:,:,offset+1:nChunk2*nTemp+offset), nrows, ncols, nTemp, []), [3 1 2 4]);
cdata2 = imfilter(single(squeeze(range(data2, 1))), fspecial('average',nSpat), 'replicate');
rfMean2 = mean(cdata2,3);
rfDataMean = cast( .5*rfMean1 + .5*rfMean2, inputDataType);   
end

% 
% function rfDataMean = fastRangeFilt3(data, nTemp, nSpat)
% if nargin < 2
%    nTemp = 5;
% end
% if nargin < 3
%    nSpat = 5;
% end
% [nrows, ncols, N] = size(data);
% inputDataType = class(data);
% nChunk = floor(N/nTemp);
% data = permute(reshape( data(:,:,1:nChunk*nTemp), nrows, ncols, nTemp, []), [3 1 2 4]);
% cdata = imfilter(single(squeeze(range(data, 1))), fspecial('average',nSpat), 'replicate');
% rfDataMean = cast(mean(cdata, 3), inputDataType);   
% end