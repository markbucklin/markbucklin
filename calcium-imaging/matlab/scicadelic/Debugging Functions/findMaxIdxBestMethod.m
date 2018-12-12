function findMaxIdxBestMethod(XC)

[numRows,numCols,numFrames,numChannels] = size(XC);
numPixels = numRows*numCols;
rowSubs = gpuArray.colon(int32(1),int32(numRows))';
colSubs = gpuArray.colon(int32(1),int32(numRows));


[maxRowIdx,maxColIdx] = reshapeMaxIdxMethod(XC);
t = gputimeit(@()reshapeMaxIdxMethod(XC),2);
fprintf('Method 1: %03.4g ms\n',t*1000)
disp(maxRowIdx(:)')
disp(maxColIdx(:)')

[maxRowIdx,maxColIdx] = compareMaxValIdxMethod(XC);
t = gputimeit(@()reshapeMaxIdxMethod(XC),2);
fprintf('Method 2: %03.4g ms\n',t*1000)
disp(maxRowIdx(:)')
disp(maxColIdx(:)')

[maxRowIdx,maxColIdx] = rowColIdxMethod(XC);
t = gputimeit(@()reshapeMaxIdxMethod(XC),2);
fprintf('Method 3: %03.4g ms\n',t*1000)
disp(maxRowIdx(:)')
disp(maxColIdx(:)')

	function [maxRow,maxCol] = reshapeMaxIdxMethod(f)
		[~, maxIdx] = max(reshape(f, numPixels, numFrames),[],1);
		[maxRow, maxCol] = ind2sub([numRows, numCols], maxIdx);
	end
	function [maxRow,maxCol] = compareMaxValIdxMethod(f)
		maxColVal = max(f,[],1);
		maxRowVal = max(f,[],2);
		maxFrameVal = max(maxRowVal,[],1);		
		isRowMax = bsxfun(@ge, maxRowVal, maxFrameVal);
		isColMax = bsxfun(@ge, maxColVal, maxFrameVal);
		isPixelMax = bsxfun(@ge, f, maxFrameVal);
		maxRow = max(bsxfun(@times, rowSubs, cast(isRowMax,'like',rowSubs)),[],1);
		maxCol = max(bsxfun(@times, colSubs, cast(isColMax,'like',colSubs)),[],2);
	end
	function [maxRow,maxCol] = rowColIdxMethod(f)
		maxColVal = max(f,[],1);
		maxRowVal = max(f,[],2);
		[~,maxRow] = max(maxColVal,[],2);
		[~,maxCol] = max(maxRowVal,[],1);
	end




end