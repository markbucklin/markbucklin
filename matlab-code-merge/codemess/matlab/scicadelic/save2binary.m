function varargout = save2binary(data, fileName) % TODO: add saveSpeedEstimateMBPS
% SAVE2BINARY
%		>> save2binary(data)
%		>> save2binary(data, fileName)
%
% Mark Bucklin
% 10/17/2015

saveSpeedEstimateMBPS = 350;
dataType = class(data);
dataSize = size(data);
numMegaBytes = MB(data);
numGigaBytes = GB(data);
fileExt = dataType;
for dataDim = numel(dataSize):-1:1
	fileExt = [num2str(dataSize(dataDim)), '.', fileExt];
end
if nargin < 2
	[fname_fext, fdir] = uiputfile(['*.',fileExt]);
	fileName = fullfile(fdir,fname_fext);
else
	fileName = [fileName,'.',fileExt];
end

copyNum = 0;
if exist( fileName, 'file')
	userChoice = questdlg('Would you like to append to, replace, or keep the existing file?',...
		'File with same name exists',...
		'Append','Replace','Keep', 'Keep');
	switch userChoice
		case 	'Append'
			writeMode = 'A';
		case 'Replace'
			writeMode = 'W';
		case 'Keep'
			copyNum = copyNum + 1;
			fileName = [fileName,'(',num2str(copyNum),')']; %TODO
			writeMode = 'W';
	end
	
else
	writeMode = 'W';
	
end

tOpen = tic;

fid = fopen(fileName, writeMode);
fwrite(fid, data(:), dataType);

estimatedSaveTime = numMegaBytes / saveSpeedEstimateMBPS;
closeTimer = timer(...
	'ExecutionMode', 'singleShot',...
	'StartDelay', estimatedSaveTime,...
	'TimerFcn', @closeFile, ...
	'StopFcn', @deleteTimer, ...
	'ErrorFcn', @sendFidToBase);

if nargout
	varargout{1} = fileName;
end

start(closeTimer)

	function closeFile(~, ~)
		fclose(fid);
		tElapsed = toc(tOpen);
		writeSpeedMBPS = numMegaBytes/tElapsed;
		fprintf(['Binary file write to disk completed:\n\t',...
			'%d GB written in %3.4g seconds (or better)\n\t',...
			'--> %3.4g MB/s\n\n'], numGigaBytes, tElapsed, writeSpeedMBPS)
	end

	function deleteTimer(src, ~)
		delete(src)
	end

	function sendFidToBase(~,~)
		fprintf('An error occurred while attempting to close binary file: fid sent to base workspace\n')
		assignin('base','fid',fid);
	end
	function nGB = GB(varname)
		% GB: RETURNS THE NUMBER OF GIGABYTES HELD IN MEMORY BY GIVEN INPUT
		m = whos('varname');
		nGB = m.bytes/2^30;
	end
	function nMB = MB(varname)
		% GB: RETURNS THE NUMBER OF GIGABYTES HELD IN MEMORY BY GIVEN INPUT
		m = whos('varname');
		nMB = m.bytes/2^20;
	end

end






