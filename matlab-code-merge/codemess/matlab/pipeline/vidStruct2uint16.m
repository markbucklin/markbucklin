function vid = vidStruct2uint16(vid,varargin)
% Usage:
%	vid16bit = vidStruct2uint16(vid) ;
%	vid16bit = vidStruct2uint16(vid, [20 99.9]);

% Can also specify low and high limits of saturation
if nargin < 2
	P = [ 20 99.995];
else
	P = varargin{1};
end
if numel(P) ~=2
	P = [ 20 99.9];
	warning('vidStruct2uint16:InvalidSaturationLimits',...
		'Saturation limits set to 20th (low) and 99.9th (high) percentiles')
end

% back to int16
offset = 100;
N = numel(vid);
nSampleFrames = min(N, 100);
s = cat(3,vid(round(linspace(1,N,nSampleFrames))).cdata);
Y = prctile(s(:), P);
fmin = Y(1) + offset/65535;
fmax = Y(2);
frange = fmax - fmin;

% Use arrayfun to apply a 2-step function to each frame (element) in the structure array
%	- Step 1: stretch the pixel intensity values to fill the range between 0 and 1
%	- Step 2: use im2uint16 to convert pixel intensity values to integers between 'offset' and 65535
v16 = arrayfun(...
	@(x)( im2uint16( (x.cdata - fmin) ./ frange) ),...
	vid, 'UniformOutput',false);

[vid.cdata] = deal(v16{:});


% (the old way... memory intensive)
% s = (s - fmin) .* ((65535-offset)/frange) + offset;
% s = uint16(s);
% for k = 1:numel(vid)
% 	vid(k).cdata = s(:,:,k);
% end