warning('importSelectPackages.m being called from scrap directory: Z:\Files\rtsci\rtsci\scrap')


[tbx.fullpath, ~, ~] = fileparts(mfilename('fullpath'));
addpath(genpath(tbx.fullpath))
[~,tbx.dirname,~] = fileparts(tbx.fullpath);

tbx.what = what(tbx.fullpath);
tbx.pkglist = tbx.what.packages;
tbx.numpkg = numel(tbx.pkglist);

tbx.selectpkg = listdlg(...
	'PromptString','Select the package(s) you would like to import',...
	'ListString',tbxPkgList, ...
	'SelectionMode','multiple',...
	'OKString','Import');

for kpkg = 1:numel(tbx.selectpkg
	import([tbx.selectpkg{kpkg},'.*'])
end
clearvars tbx kpkg

% tbxPkg = meta.package.fromName(tbx.selectpkg);
