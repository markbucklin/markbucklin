function trialdata = importTrialData(filename)
% For loading files saved by Huaan's LabView program. 
% Each row corresponds to a trial, and begins with a timestamp
% in the first column

% Format string for each line of text:
%   column1: double (%f) - TIMESTAMP
%	column2: double (%f) - TRIAL NUMBER
%   column3: double (%f) - STIMULUS NUMBER
%   >>before devalue only>>(column4: double (%f) - NUMBER OF CORRECT RESPONSES???)
%   column7 (column6 after devalue): double (%f) - INTERTRIAL-INTERVAL

% FIND FILE
if nargin < 1
   d = dir('Trial-*');
   if ~isempty(d)
	  filename = d(1).name;
   else
	  [fname, fdir] = uigetfile(...
		  {'*.*','All Files (*.*)'},...
		  'Please select a TRIAL file');
	  filename = fullfile(fdir,fname);
   end
end

% OPEN FILE
fileID = fopen(filename,'r');

% READ FIRST LINE TO DETERMINE NUMBER OF COLUMNS (varies before/after devalue)
firstRow = fgetl(fileID);
[~, colcount] = sscanf(firstRow, '%f\t');
frewind(fileID)

% INITIALIZE VARIABLES AND FORMAT SPEC
delimiter = '\t';
startRow = 1;
endRow = inf;
switch colcount
   case 7 % BEFORE DEVALUE
	  formatSpec = '%f%f%f%*s%*s%*s%f%[^\n\r]';
   case 6 % AFTER DEVALUE
	  formatSpec = '%f%f%f%*s%*s%f%[^\n\r]';
   otherwise
	  error('file is messed up')
end



% READ COLUMNS
dataArray = textscan(fileID, formatSpec, endRow(1)-startRow(1)+1,...
   'Delimiter', delimiter, 'EmptyValue' ,NaN,...
   'HeaderLines', startRow(1)-1, 'ReturnOnError', false);
% DEAL WITH ERRORS (doesn't run)
for block=2:length(startRow)
   frewind(fileID);
   dataArrayBlock = textscan(fileID, formatSpec,...
	  endRow(block)-startRow(block)+1, 'Delimiter', delimiter,...
	  'EmptyValue' ,NaN,'HeaderLines', startRow(block)-1,...
	  'ReturnOnError', false);
   for col = 1:length(dataArray)
	  dataArray{col} = [dataArray{col};dataArrayBlock{col}];
   end
end

% CLOSE FILE
fclose(fileID);

% ORGANIZE OUTPUT IN A TABLE (newer version of Matlab only, change to struct if necessary)
trialdata = table(dataArray{1:end-1}, 'VariableNames', {'tstart','num','stim','iti'});
