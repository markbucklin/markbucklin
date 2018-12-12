function varargout = showMontage(data)
% data = double(data);
% sz = size(data);
dims = ndims(data);
if dims < 4
   data =  permute(shiftdim( data,-1),  [2, 3, 1, 4]);   
end
% datamed = median(median(data,1),2);
% datamedmean = mean(datamed,4);
% data = bsxfun(@minus, data, bsxfun(@plus,datamed,datamedmean));
% data = bsxfun(@rdivide, double(bsxfun(@minus, data, min(min(data,[],1),[], 2))), double(range(range(data,1),2)) );
figure
h.im = imaqmontage(data);
h.ax = h.im.Parent;
h.fig = h.ax.Parent;
% h.ax.CLim = [0, 1];
h.ax.LooseInset =  h.ax.TightInset;
h.ax.PlotBoxAspectRatioMode = 'manual';
if nargout > 0
   varargout{1} = h;
end








