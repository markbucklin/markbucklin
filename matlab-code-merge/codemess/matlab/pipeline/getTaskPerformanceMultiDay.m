function performance =  getTaskPerformanceMultiDay(md)
if nargin < 1
   md = loadMultiDayRoi;
end
nExp = numel(md);
Fs = 20;

for k=1:nExp
   % REACTION TIME
   rx.all =  (md(k).bhv.frameidx.firstlick - md(k).bhv.frameidx.alltrials) ./ Fs;
   rx.long = (md(k).bhv.frameidx.longlick - md(k).bhv.frameidx.longtrial) ./ Fs;
   rx.short = (md(k).bhv.frameidx.shortlick - md(k).bhv.frameidx.shorttrial) ./ Fs;
   performance(k).rxtime = rx;
   % PERFORMANCE
   fld = fields(rx);
   for fn = 1:numel(fld)
	  fln = fld{fn};
	  rc.(fln).sub500 = rx.(fln) < .500;
	  rc.(fln).sub1k = rx.(fln) < 1;
	  rc.(fln).sub2k = rx.(fln) < 2;
   end
   performance(k).correct = rc;
end

% 
% for k=1:8
%    for n = 1:md(k).bhv.trialidx.long
% 	  if md(k).bhv.frameidx.longLick(n) - 
%    correct(k).long(n) = 
%    
%    
% end