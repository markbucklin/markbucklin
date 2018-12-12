



for k=1:numel(md), md(k).xs = getActivationState(md(k).roi, md(k).bhv.t); disp(k), end
for k=1:numel(md), md(k).te.total = fastTE(md(k).xs, md(k).xs, 10, 5); disp(k); end