function dataSize = getPaddedDataSize(data)
dataSize = ones(1,4);
sz = size(data);
dataSize(1:numel(sz)) = sz(:);

end