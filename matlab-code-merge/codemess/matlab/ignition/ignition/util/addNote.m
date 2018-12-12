function addNote( )
%ADDNOTE Summary of this function goes here
%   Detailed explanation goes here


% backupDirectory = ...
% 	'Z:\Files\ImageProcessing\ProjectBackups';
% 		'C:\Users\monkey\Documents\MATLAB\Project Backups';


[packagePath, packageName, packageParentPath] = ignition.util.getPackagePath();
packageBackupPath = [packageParentPath, filesep, packageName, '_backup'];



if ~isdir(packageBackupPath)
	mkdir(packageBackupPath)
end
%defaultZipFileName = [packageName,'_backup',' (',datestr(now,'yyyymmmdd_HHMMPM'),').zip'];
if ~isdir(packagePath)		
		packagePath =  uigetdir(pwd,'Select Package Directory to Zip:');
end


notesFileName = 'Bucklin_ProjectNotes.txt';


dateStamp = datestr(now,'yyyymmmdd_HHMMPM');

options = struct(...
		'Resize','on',...
		'WindowStyle','normal');
prompt = ['Record a project note to file: ',notesFileName];
name = ['Project Note Addition: ',dateStamp];
numlines = [4 60];
		
uiNote = char(inputdlg(prompt, name, numlines ,{''}, options));

fid = fopen(fullfile(packageBackupPath,notesFileName),'a');
if fid <0
		[notesFileName, packageBackupPath] = uiputfile(...
				'*.txt','Find or make notes file: ',fullfile(packageBackupPath,notesFileName));
		fid = fopen(fullfile(packageBackupPath,notesFileName),'a');
end
try
		fprintf(fid,'%s\r\n%s\r\n\r\n',dateStamp,uiNote);
		fclose(fid);
catch me
		warning(me.message)
end
end

