function showBehaviorPerformance(md)
histbinedge = 0:.1:2;
for k=1:8
   rxtime(k).all =  (md(k).bhv.frameidx.firstlick - md(k).bhv.frameidx.alltrials) ./ 20;
   rxtime(k).long = (md(k).bhv.frameidx.longlick - md(k).bhv.frameidx.longtrial) ./ 20;
   rxtime(k).short = (md(k).bhv.frameidx.shortlick - md(k).bhv.frameidx.shorttrial) ./ 20;
   subplot(2,4,k)
   histogram(rxtime(k).long, histbinedge)
   hold on
   histogram(rxtime(k).short, histbinedge)
end
% title('Reaction Time for Each Day (6-Pre- 2-Post-Devalue)')


% for k=1:8
%    for n = 1:md(k).bhv.trialidx.long
% 	  if md(k).bhv.frameidx.longlick(n) - 
%    correct(k).long(n) = 
%    
%    
% end