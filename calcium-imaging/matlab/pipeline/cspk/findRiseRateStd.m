function riseRateStd = findRiseRateStd(x,winsize)
% Returns maximum slope of a line fit to data in a sliding window using least-squares estimation. Returned rate is
% per-sample.
if nargin < 2
   winsize = 10;
end
if numel(winsize) ==1
   Xf = zeroShiftedWinMat(x, winsize);
   Xlin = [ones(winsize,1), cumsum(ones(winsize,1))];   
   C = (Xlin' * Xlin) \ Xlin' * Xf;
   riseRateStd = std(C(2,:))*winsize;
else   
   maxwinsize = max(winsize);
   Xf = zeroShiftedWinMat(x, maxwinsize);
   Xlin = [ones(maxwinsize,1), cumsum(ones(maxwinsize,1))];
   for k=1:numel(winsize)
	  xlin = Xlin(1:winsize(k),:);
	  xf = Xf(1:winsize(k),:);
	  c = (xlin' * xlin) \ xlin' * xf;	  
	  riseRateStd(k) = std(c(2,:))*winsize(k);
   end

end

% riseRate = mean(diff(x(maxind:maxind+maxwinsize-1)));



