function stat = getVidStats(vid, varargin)
if nargin < 2
	N = min(500, numel(vid));
else
	N = min(500, varargin{1});
end
if isa(vid,'struct')
   vidSample = getVidSample(vid, N);
   vidArray = cat(3,vidSample.cdata);
else
   vidArray = getDataSample(vid,N);
end

stat.Min = min(vidArray,[],3);
stat.Range = range(vidArray,3);
stat.Max = max(vidArray,[],3);
stat.Var = var(double(vidArray),1,3);
stat.Std = sqrt(stat.Var);
stat.Mean = mean(vidArray,3);
