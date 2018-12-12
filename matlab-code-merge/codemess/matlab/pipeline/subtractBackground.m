function vid = vidStruct2uint8(vid, varargin)
% Usage:
%	vid8bit = vidStruct2uint8(vid) ;
%	vid8bit = vidStruct2uint8(vid, [20 99.9]);

% Can also specify low and high limits of saturation
if nargin < 2
	P = [ 20 99.9];
else
	P = varargin{1};
end
if numel(P) ~=2
	P = [ 15 99.95];
	warning('vidStruct2uint8:InvalidSaturationLimits',...
		'Saturation limits set to 20th (low) and 99.9th (high) percentiles')
end

% to uint8
N = numel(vid);
nSampleFrames = min(N, 100);
s = cat(3,vid(round(linspace(1,N,nSampleFrames))).cdata);
Y = prctile(s(:), P);
fmin = Y(1);
fmax = Y(2);
frange = fmax - fmin;

v8 = arrayfun(@(x)(im2uint8( (x.cdata - fmin) ./ frange)), vid, 'UniformOutput',false);

[vid.cdata] = deal(v8{:});




% s = (s - fmin) .* (255/frange) + 1;
% s = uint8(s);
% for k = 1:numel(vid)
% 	vid(k).cdata = s(:,:,k);
% end


% ALTERNATIVE:
% nominalVidMax = max(max(cat(1,vid(round(linspace(1,N,nSampleFrames))).cdata),[],2),[],1);
% s = cat(3,vid.cdata);

