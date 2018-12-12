function [labelMatrix, varargout] = createLabelMatrix(obj, imSize) % 3ms
% Will return INTEGER LABELED IMAGE from a single ROI or Array of ROI objects with labels
% assigned based on the order in which RegionPropagation objects are passed in (by index). A second
% output can be specified, providing a second label matrix where the labels assigned are the
% unique ID number for each respective object passed as input.

% WILL ALLOCATE IMAGE WITH MOST EFFICIENT DATA-TYPE POSSIBLE
N = numel(obj);
if N <= intmax('uint8')
	outClass = 'uint8';
elseif N <= intmax('uint16')
	outClass = 'uint16';
elseif N <= intmax('uint32')
	outClass = 'uint32';
else
	outClass = 'double';
end

% CONSTRUCT INDICES FOR EFFICIENT LABEL ASSIGMENT
pxIdx = cat(1, obj.PixelIdxList);
lastIdx = cumsum(round(cat(1, obj.Area)));
roiIdxPxLabel = zeros(size(pxIdx), outClass);
roiIdxPxLabel(lastIdx(1:end-1)+1) = 1;
roiIdxPxLabel = cumsum(roiIdxPxLabel) + 1;

% ASSIGN LABELS IN THE ORDER OBJECTS WERE PASSED TO THE FUNCTION
if nargin < 2
	imSize = 2^nextpow2(sqrt(double(max(pxIdx(:)))));
end
labelMatrix = zeros(imSize, outClass);
labelMatrix(pxIdx) = roiIdxPxLabel;

if nargout > 1
	roiUid = cat(1, obj.UID);
	roiUidPxLabel = roiUid(roiIdxPxLabel);
	uidLabelMatrix = zeros(imSize, 'like', roiUid);
	uidLabelMatrix(pxIdx) = roiUidPxLabel;
	varargout{1} = uidLabelMatrix;
end
end