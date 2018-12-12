warning('importAllPackages.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
warning('importAllPackages.m being called from scrap directory: Z:\Files\ignition\ignition\scrap')





[tbx.fullpath, ~, ~] = fileparts(mfilename('fullpath'));
addpath(genpath(tbx.fullpath))
[~,tbx.dirname,~] = fileparts(tbx.fullpath);

tbx.meta = meta.package.fromName(tbx.dirname);

tbx.what = what(tbx.fullpath);
tbx.pkglist = tbx.what.packages;
tbx.numpkg = numel(tbx.pkglist);

for kpkg = 1:tbx.numpkg	
	import([tbx.pkglist{kpkg},'.*'])
end
% clearvars tbx kpkg
