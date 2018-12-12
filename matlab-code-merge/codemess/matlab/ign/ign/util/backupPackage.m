function backupPackage()
% Mark Bucklin
% This function should be called to save a project as a zip file containing all mfiles in the
% project folder and all subfolders.

% 
% currentFcnPath = fileparts(mfilename('fullpath'));
% dirTree = textscan(currentFcnPath, '%s', 'Delimiter',filesep);
% dirTree = dirTree{1};
% 
% isPackageDir = @ (dirname) dirname(1) == '+';
% packageParentPath = currentFcnPath;
% k=0;
% while (k<numel(dirTree))
% 	nextDir = dirTree{end-k};
% 	if ~isPackageDir(nextDir)
% 		packageParentPath = fullfile(dirTree{1:(end-k)});
% 		break
% 	else
% 		k = k + 1;
% 	end
% end
% 
% packagePath = fullfile(dirTree{1:(end-k+1)});
% topPackageDir = dirTree{end-k+1};
% packageName = topPackageDir(2:end);


[packagePath, packageName, packageParentPath] = ign.util.getPackagePath();


packageBackupPath = [packageParentPath, filesep, packageName, '_backup'];

if ~isdir(packageBackupPath)
	mkdir(packageBackupPath)
end


defaultZipFileName = [packageName,'_backup',' (',datestr(now,'yyyymmmdd_HHMMPM'),').zip'];


if ~isdir(packagePath)		
		packagePath =  uigetdir(pwd,'Select Package Directory to Zip:');
end

[zipFileName,zipPath] = uiputfile('*.zip',...
		'Save Zip File to: ', ...
		fullfile(packageBackupPath,defaultZipFileName));

if ~isempty(zipFileName) ...
				&& ~isempty(zipPath) ...
				&& ~isempty(packageParentPath)
		zip(fullfile(zipPath,zipFileName), packagePath)
end
