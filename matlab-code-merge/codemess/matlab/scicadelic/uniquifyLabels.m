function uLabMat = uniquifyLabels(labelMatrix)
if size(labelMatrix,3) > 1
	labelFrameMax = max(max(labelMatrix));
	uLabMat = bsxfun(@plus, labelMatrix, cumsum(cat(3, 0, labelFrameMax(1,1,1:end-1)),3));
	uLabMat(~logical(labelMatrix)) = 0;
else
	uLabMat = labelMatrix;
end

end