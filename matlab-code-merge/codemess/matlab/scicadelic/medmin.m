function bg = medmin(f)
% MEDMIN
% Background value estimation (fast)

% [~,~, numFrames, numChannels] %TODO

colMin = squeeze(min( f, [], 1));
rowMin = squeeze(min( f, [], 2));
bg = median( cat(1, colMin, rowMin), 1)';













