function addScrapWarning()
warning('addScrapWarning.m being called from scrap directory: Z:\Files\rtsci\rtsci\scrap')

scrapDir = fileparts(which(mfilename));
allFiles = dir(scrapDir);
allFiles = allFiles(~[allFiles(:).isdir]);

makeWarning = @ (name) sprintf('warning(''%s being called from scrap directory: %s'')',name, scrapDir);

for k=1:numel(allFiles)
	fileName = allFiles(k).name;
	warningString = makeWarning(fileName);
	fullFilePath = [scrapDir, filesep, fileName];
	
	try
		fid = fopen(fullFilePath);
		if fid < 1
			continue
		end
		currentFileText = textscan(fid,'%s','delimiter','\n','whitespace','');
		fclose(fid);
		currentFileText = currentFileText{1};
		newFileText = currentFileText;
		
		if isempty(currentFileText)
			continue
		end
		
		try
			fileCallInfo = getcallinfo(fullFilePath);
			fileType = fileCallInfo.type.char;
			
		catch
			if ~isempty(findstr(currentFileText{1}, 'function'))
				fileType = 'function';
			elseif ~isempty(findstr(currentFileText{1}, 'classdef'))
				fileType = 'class';
			else
				fileType = 'script';
			end
			
	end
		
	switch fileType
		case 'script'
			if ~strcmp(currentFileText{1}, warningString)
				newFileText = cat(1, {warningString}, currentFileText);
			end
		case 'function'
			if ~strcmp(currentFileText{2}, warningString)
				newFileText = cat(1, currentFileText(1), {warningString}, currentFileText(2:end));
			end
		case 'class'
			
		otherwise
	end
		
		writeFile(fullFilePath, newFileText)
		
	catch me
		getReport(me)
	end
	
end





end

function writeFile( fname, txt)
fid = fopen(fname,'w+');
fprintf(fid,'%s\n',txt{:});
fclose(fid);
end
