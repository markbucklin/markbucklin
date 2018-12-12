function baseline = getBaselineFromSummary(filepath)

if nargin < 1
   d = dir('Processing_Summary_*');
   filepath = fullfile(pwd, d.name);
end
load(filepath)
normpre = cat(1,vidProcSum.normpre);
baseline.cell = squeeze(cat(3,normpre.cellBaseline));
baseline.neuropil = squeeze(cat(3,normpre.npBaseline));