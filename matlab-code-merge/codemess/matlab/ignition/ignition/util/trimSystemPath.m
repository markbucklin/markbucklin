function trimSystemPath()
% Queries user to select system path entries to keep, discarding the rest after backing up to
% temporary file.

% GET CURRENT PATH
[sysPath,sysPathStr] = ignition.util.getSystemPath();

% CHECK IF EACH PATH ENTRY IS VALID
pathFound = cellfun(@isdir, sysPath);
validIdx = find(pathFound);

% QUERY USER TO SELECT/DESELECT ENTRIES
[selectedIdx, ok] = listdlg(...
	'ListString',sysPath,...
	'SelectionMode','multiple',...
	'InitialValue',validIdx,...
	'Name','System Path Trim',...
	'ListSize',[480 18*nnz(pathFound)],...
	'PromptString','Select PATH entries to keep',...
	'OKString','Keep Selected');

if ok
	% BUILD & SET NEW PATH FROM SELECTED ENTRIES
	newSysPath = sysPath(selectedIdx);
	newSysPathStr = [sprintf('%s;',newSysPath{1:end-1}) , newSysPath{end}];
	setenv('PATH', newSysPathStr);
	
	% SAVE BACKUP OF OLD PATH IN TEMPORARY FILE
	backupFilePath = [tempdir,'SystemPath_BACKUP.txt'];
	fid = fopen(backupFilePath,'A');
	fileCloser = onCleanup( @() fclose(fid));
	fprintf(fid,'%s\n',sysPathStr);
	fprintf('Former system path backed up to:\n\t%s\n',backupFilePath);		
	
else
	fprintf('Path left unchanged\n')
end





