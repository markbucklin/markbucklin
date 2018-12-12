function L = roiArray2LabelMatrix(roiArray, imageSize)
% Converts an array of simple "roi" structures to a label matrix
% 
% "roi" is a struct with fields:
% 
%       idx: [M×1 double]
%     trace: [1×1 struct] (containing traces from different video sources)
%     props: [1×1 struct] (from regionprops function)

cc = struct('Connectivity', 8,'ImageSize', imageSize, 'NumObjects', numel(roiArray), 'PixelIdxList', []);
cc.PixelIdxList = {roiArray.idx};
L = labelmatrix(cc);
