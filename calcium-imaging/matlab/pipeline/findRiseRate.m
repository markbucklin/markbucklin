function riseRate = findRiseRate(x)
winsize = 5;
maxval = 1;
while maxval > 0
   winsize = winsize + 1;
   xiw = diff(shiftedWinMat(x, winsize),1,1);
   %    xiw(xiw<0) = 10 * xiw(xiw<0);
   xiw(xiw<0) = -10*std(xiw(:)) ;
   [maxval, maxind] = max(sum(xiw,1));
end
winsize = winsize - 1;
xiw = diff(shiftedWinMat(x, winsize),1,1);
xiw(xiw<0) = -10*std(xiw(:));
[maxval, maxind] = max(sum(xiw,1));

riseRate = mean(diff(x(maxind:maxind+winsize-1)));



