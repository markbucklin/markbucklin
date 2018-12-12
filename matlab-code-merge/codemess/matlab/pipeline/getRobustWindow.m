function winRectangle = selectWindowForMotionCorrection(vid, winsize)

if numel(winsize) <2
  winsize = [winsize winsize];
end

sz = size(vid(1).cdata);
win.edgeOffset = round(sz/4);
win.rowSubs = win.edgeOffset(1):sz(1)-win.edgeOffset(1);
win.colSubs =  win.edgeOffset(2):sz(2)-win.edgeOffset(2);

vidSample = getVidSample(vid);
stat.Range = range(cat(3,vidSample.cdata), 3);
stat.Min = min(cat(3,vidSample.cdata), [], 3);

imRobust = imfilter(rangefilt(stat.Min),ones(50)) ./ imfilter(stat.Range, ones(50));
imRobust = imRobust(win.rowSubs, win.colSubs);
[~, maxInd] = max(imRobust(:));
[win.rowMax, win.colMax] = ind2sub([length(win.rowSubs) length(win.colSubs)], maxInd);
win.rowMax = win.rowMax + win.edgeOffset(1);
win.colMax = win.colMax + win.edgeOffset(2);
win.rows = win.rowMax-winsize(1)/2+1 : win.rowMax+winsize(1)/2;
win.cols = win.colMax-winsize(2)/2+1 : win.colMax+winsize(2)/2;

winRectangle = [win.cols(1) , win.rows(1) , win.cols(end)-win.cols(1) , win.rows(end)-win.rows(1)];


