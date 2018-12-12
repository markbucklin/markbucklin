function performance =  getTaskPerformance(frameidx)

Fs = 20;


% REACTION TIME
rx.all =  (frameidx.firstlick - frameidx.alltrials) ./ Fs;
rx.long = (frameidx.longlick - frameidx.longtrial) ./ Fs;
rx.short = (frameidx.shortlick - frameidx.shorttrial) ./ Fs;
performance.rxtime = rx;

% PERFORMANCE
fld = fields(rx);
for fn = 1:numel(fld)
   fln = fld{fn};
   rc.(fln).sub500 = rx.(fln) < .500;
   rc.(fln).sub1k = rx.(fln) < 1;
   rc.(fln).sub2k = rx.(fln) < 2;
end
performance.correct = rc;

