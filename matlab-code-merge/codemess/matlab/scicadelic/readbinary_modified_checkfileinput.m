function varargout = readbinary(fileNameInput)
% >>  data = readbinary();
% >>  data = readbinary(fileName);

% FIND FILE TO READ
if nargin < 1
	fileNameInput = '';
end
if ~exist(fileNameInput,'file')
	[fname_fext, fdir] = uigetfile('*.*');
	fileName = fullfile(fdir,fname_fext);
else
	fileName = which(fileNameInput);
	if isempty(fileName)
		fileName = fileNameInput;
	end
	[~, fname,fext] = fileparts(fileNameInput);
	if isempty(fext)
		fname_fext = fname;
	else
		fname_fext = [fname,fext];
	end
end

% DETERMINE SIZE & TYPE OF DATA
[fname, rem] = strtok(fname_fext,'.');
arraySizeString = strtok(regexp(rem, '(\d+)\.','match'),'.');
dataNumDimensions = numel(arraySizeString);
charIdx = regexp(rem, '(\d+)\.','end');
for k=dataNumDimensions:-1:1	
	dimString = arraySizeString{k};
	dataSize(k) = str2double(dimString);
end
dataType = rem(1+charIdx(end):end);

% READ
fid = fopen(fileName, 'r');
data = fread(fid, inf, ['*',dataType]);
fclose(fid);

% RESHAPE
try
	data = reshape(data, dataSize);
catch
	try
		dataSizeCell = num2cell(dataSize);
		data = reshape(data, dataSizeCell{1:end-1}, []);
	catch
		
	end
end
if nargout
	varargout{1} = data;
else
	assignin('base',fname,data);
end
end



