randomPick = @(n) sort(randi([1,numel(roi)], n, 1));

% roiPixelTracePlotFcn( randomPick(25), 'red')

sz = size(L);
mat = zeros(sz);
add2LabelMat = @(n, mat) max(reshape(accumarray(roi(n).idx, n, [1024*1024 1]), 1024, 1024), mat);




prop = [roi.props]; 
[~,szSortIdx] = sort(cat(1, prop.Area));
roiPixelTracePlotFcn( szSortIdx(end-10:end), 'intensity')


% idxCount = arrayfun( @(r) length(r.idx), roi);
% idxCell = arrayfun( @(x) {x}, idxCount(:));


% roiIdx = 1:numel(roi);
roiIdx = szSortIdx(end-10:end);
for k = roiIdx(:)'
    mat = add2LabelMat(k, mat);    
end



% out.bg = data(:,:,2,end);
% getRed = @(frame) max( data(:,:,1,(frame-5:frame+5)), [], 4);
% out.peaks = {getRed(1968), getRed(1882), getRed(1812), getRed(1726), getRed(1649)}
% imwrite(out.bg, './export/bg.png')
% for k=1:numel(out.peaks), imwrite(out.peaks{k}, sprintf('./export/ch%3d.png',k)), end