function [packagePath, packageName, packageParentPath] = getPackagePath()
% Mark Bucklin This function should be called retrieve names and directories for the package
% containing this file. Can be used to construct/find 'backup_' and/or 'notes_' directories to aid
% package develeopment.


currentFcnPath = fileparts(mfilename('fullpath'));
dirTree = textscan(currentFcnPath, '%s', 'Delimiter',filesep);
dirTree = dirTree{1};

isPackageDir = @ (dirname) dirname(1) == '+';
packageParentPath = currentFcnPath;
k=0;
while (k<numel(dirTree))
	nextDir = dirTree{end-k};
	if ~isPackageDir(nextDir)
		packageParentPath = fullfile(dirTree{1:(end-k)});
		break
	else
		k = k + 1;
	end
end

packagePath = fullfile(dirTree{1:(end-k+1)});
topPackageDir = dirTree{end-k+1};
packageName = topPackageDir(2:end);
