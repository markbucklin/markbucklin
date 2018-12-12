bhv = loadBehaviorData;
rxtime.long = (bhv.frameidx.longlick - bhv.frameidx.longtrial) ./ 20;
rxtime.short = (bhv.frameidx.shortlick - bhv.frameidx.shorttrial) ./ 20;
clf
histogram(rxtime.long, 0:.1:2)
hold on
histogram(rxtime.short, 0:.1:2)