function txt = readFileText(filename, linesToCell)
%READFILETEXT  Returns a text or cell array of text in a file
%
% >> txt = readFileText(filename, false)	% return char array
% >> txt = readFileText(filename, true)		% returns lines in cells
% >> txt = readFileText(filename)					% returns lines in cells

% DEFAULT RETURN-TYPE IS CHARACTER ARRAY
if nargin < 2
	linesToCell = true;
end

% INITIALIZE RETURN-TYPE
if linesToCell
	txt = {};
else
	txt = '';
end

% CHECK IF THIS IS VALID TEXT FILE (NON-BINARY)
isValid = ~isValidTextFile(filename);
if ~isValid
	return
end

% READ FILE AS CHARACTER ARRAY
charText = fileread(filename);

% CONVERT LINES TO CELLS IF SPECIFIED
if linesToCell	
	txt = strsplit(charText, {'\r\n','\n', '\r'}, 'CollapseDelimiters', false)';
else
	txt = charText;
end

end

function flag = isValidTextFile(filename)

flag = false;

% OPEN FILE
fid = fopen(filename,'r');

% SUCCESSFUL FILE OPEN
if fid < 0	
	return
end

% CHECK FOR ANY BYTES WITH 0
data = fread(fid,10000,'uint8=>uint8');
flag = any(data==0);

% CLOSE FILE
fclose(fid);

end



