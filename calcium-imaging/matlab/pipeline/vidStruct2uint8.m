function vid = vidStruct2uint8(vid, varargin)
% Usage:
%	vid8bit = vidStruct2uint8(vid) ;
%	vid8bit = vidStruct2uint8(vid, [20 99.9]);

% Can also specify low and high limits of saturation
if nargin < 2
   P = [ 10 99.95];
else
   P = varargin{1};
end
if numel(P) ~=2
   P = [ 10 99.95];
   warning('vidStruct2uint8:InvalidSaturationLimits',...
      'Saturation limits set to 10th (low) and 99.95th (high) percentiles')
end


% to uint8
N = numel(vid);
inputDataType = class(vid(1).cdata);
nSampleFrames = min(N, 100);
s = cat(3,vid(round(linspace(1,N,nSampleFrames))).cdata);
Y = prctile(double(s(:)), P);
fmin = Y(1);
fmax = Y(2);
inputRange = [fmin fmax];

t=hat;
h = waitbar(0,  sprintf('Converting video frames from %s to %s: %g of %g (%f ms/frame)',...
   inputDataType, 'uint8', 1,N, 1000*(hat-t)));
for k=1:numel(vid)
   im = mat2gray( gpuArray(vid(k).cdata), inputRange);
   im = cast(im*255, 'uint8');
   vid(k).cdata = gather(im);
   waitbar(k/N, h, sprintf('Converting video frames from %s to %s: %g of %g (%f ms/frame)',...
      inputDataType, 'uint8', k,N, 1000*(hat-t)));
   t=hat;
end
delete(h)


% frange = fmax - fmin;




% v8 = arrayfun(@(x)(im2uint8( (x.cdata - fmin) ./ frange)), vid, 'UniformOutput',false);

% [vid.cdata] = deal(v8{:});




% s = (s - fmin) .* (255/frange) + 1;
% s = uint8(s);
% for k = 1:numel(vid)
% 	vid(k).cdata = s(:,:,k);
% end


% ALTERNATIVE:
% nominalVidMax = max(max(cat(1,vid(round(linspace(1,N,nSampleFrames))).cdata),[],2),[],1);
% s = cat(3,vid.cdata);

