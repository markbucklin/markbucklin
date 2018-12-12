function addSuggestedToPath()

% todo: recursive search from given parent directory

env = dct_psfcns('environ');
m = regexp(env,'\W*=(\W)*','split');
curPath = ignition.util.getSystemPath;



% askUser = @(val,tag) questdlg(sprintf('Add %s to System Path?',val),tag, 'no', 'yes', 'open',
% 'select','no');
askUserSelect = @(val,tag) questdlg(sprintf('Select directory from: %s?',val),tag, 'no', 'select', 'open','no');
confirmYes = @(val,tag) questdlg(sprintf('Add %s to System Path?',val),tag, 'no', 'yes', 'open','no');

vals2add = {};

for k=1:numel(m)
	entry = m{k};
	if numel(entry)>2
		continue
	end
	tagStr = entry{1};
	dirStr = entry{2};
	
	if ischar(dirStr) && isdir(dirStr)
		
		% CHECK IF CURRENTLY ON PATH
		if any(strcmp(dirStr,curPath))
			continue
		end
		
		% CHECK IF ANY BINARY (EXECUTABLE) FILES EXIST IN FOLDER
		execFile = ignition.util.getExecutableFiles(dirStr);
		if isempty(execFile)
			continue
		else
			% 				uiwait(msgbox(strvcat(execFile{:}), sprintf('Executables in %s',dirStr),'modal'))
			uiwait(msgbox(...
				sprintf('DIRECTORY:\n%s\n\n%s', dirStr, sprintf('\t%s\n',execFile{:})),...
				'Executables Files','modal'))
		end
		
		% SELECT OR OPEN DIRECTORY
		response = askUserSelect(dirStr,tagStr);
		if ~ischar(response)
			break
		end
		
		if strcmpi(response, 'select')
			dirStr = uigetdir(dirStr);
		elseif strcmpi(response,'open')
			try
				winopen(dirStr)
			catch
				msgbox('Open failed')
				% todo windows only
			end
		else
			break
		end
		
		% CONFIRM DIRECTORY TO ADD FROM SELECTION OR OPENED DIRECTORY
		if ischar(dirStr)
			response = confirmYes(dirStr,tagStr);
			if ~ischar(response)
				break
			end
			if strcmpi(response,'yes')
				% ADD
				vals2add = [vals2add ; {dirStr} ];
				% todo -> is it necessary to check valStr(end) == filesep?
			end
		end
		
		
		
		
	end
end


if ~isempty(vals2add)
	sysPath = ignition.util.getSystemPath;
	newSysPath = vertcat(sysPath(:),vals2add(:));
	newSysPathStr = [sprintf('%s;',newSysPath{1:end-1}), newSysPath{end}];
	setenv('PATH',newSysPathStr);
	
end



end


















