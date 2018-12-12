function allDims = padDimensions(allDims, newDims, index) 
%PADDIMENSIONS Define the PADDIMENSIONS class.

%   Copyright 2010-2011 The MathWorks, Inc.

% If there is a dimension mismatch, pad the array before combining them
if size(newDims, 2) > size(allDims, 2)
    allDims = uiservices.padArray(allDims, 1, [size(allDims, 1) size(newDims, 2)]);
elseif size(newDims, 2) < size(allDims, 2)
    newDims = uiservices.padArray(newDims, 1, [1 size(allDims, 2)]);
end
allDims(index, :) = newDims;

% [EOF]
