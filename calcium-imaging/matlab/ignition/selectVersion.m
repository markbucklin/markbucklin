

% [tbx.fullpath, ~, ~] = fileparts(mfilename('fullpath'));

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



[tbxPath, ~, ~] = fileparts(mfilename('fullpath'));

[~,tbxDirName,~] = fileparts(tbxPath);

tbxWhat = what(tbxPath);
tbxPkgList = tbxWhat.packages;
numPkg = numel(tbxPkgList);
if (numPkg == 1)
	tbxPkgName = tbxPkgList{1};
else
tbxMatch = strcmp(tbxDirName, tbxPkgList);
	if (sum(tbxMatch) == 1)
		tbxPkgName = tbxPkgList{tbxMatch};
	else
		tbxPkgName = listdlg(...
			'PromptString','Select the package(s) you would like to import',...
			'ListString',tbxPkgList, ...
			'SelectionMode','multiple',...
			'OKString','Import');
	end
end

tbxPkg = meta.package.fromName(tbxPkgName);
