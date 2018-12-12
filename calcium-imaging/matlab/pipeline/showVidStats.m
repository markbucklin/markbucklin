function stat = getVidStats(vid, varargin)
if nargin < 2
	N = min(500, numel(vid));
else
	N = min(500, varargin{1});
end
vidSample = getVidSample(vid, N);
stat.Min = min(cat(3,vidSample.cdata),[],3);
stat.Range = range(cat(3,vidSample.cdata),3);
stat.Max = max(cat(3,vidSample.cdata),[],3);
stat.Var = var(double(cat(3,vidSample.cdata)),1,3);
stat.Std = sqrt(stat.Var);

% im.red = uint8(255*double(stat.Range)./double(max(stat.Range(:))));
im.red = uint8(255*double(stat.Var)./double(max(stat.Var(:))));
im.green = uint8(255*double(stat.Max)./double(max(stat.Max(:))));
im.blue = uint8(255*double(stat.Min)./double(max(stat.Min(:))));
imshow(cat(3, im.red, im.green, im.blue))
% text(10, 15, sprintf('Range: %i to %i', min(stat.Range(:)), max(stat.Range(:))), 'Color','red');
text(10, 15, sprintf('Variance: %0.2f to %0.2f', min(stat.Var(:)), max(stat.Var(:))), 'Color','red');
text(10, 30, sprintf('Max: %i to %i', min(stat.Max(:)), max(stat.Max(:))), 'Color','green')
text(10, 45, sprintf('Min: %i to %i', min(stat.Min(:)), max(stat.Min(:))), 'Color','blue')