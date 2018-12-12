function bg = medmean(f)
warning('medmean.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% MEDMEAN
% Background value estimation (fast)

% [~,~, numFrames, numChannels] %TODO

colMean = squeeze(mean( f, 1));
rowMean = squeeze(mean( f, 2));
bg = median( cat(1, colMean, rowMean), 1)';













