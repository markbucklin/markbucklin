function subs = chansubs(numChannels)
warning('chansubs.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

subs = reshape(1:numChannels, 1, 1, 1, numChannels);
