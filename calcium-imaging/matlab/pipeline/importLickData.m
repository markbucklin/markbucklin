function lickdata = importLickData(filename)
% For loading files saved by Huaan's LabView program. Each row corresponds to a lick, and begins with a timestamp
% in the first column

% Format string for each line of text:
%   column1: double (%f) - TIMESTAMP
%	column3: double (%f) - TRIAL NUMBER
%   column4: double (%f) - OCCURRED DURING TONE
%	column5: double (%f) - OCCURRED DURING RESPONSE WINDOW
%   column6: double (%f) - OCCURRED DURING INTERTRIAL-INTERVAL
%	column8: double (%f) - STIMULUS NUMBER

% FIND FILE
if nargin < 1
   d = dir('*-lick-*');
   if ~isempty(d)
	  filename = d(1).name;
   else
	  [fname, fdir] = uigetfile(...
		  {'*.*','All Files (*.*)'},...
		  'Please select a LICK file');
	  filename = fullfile(fdir,fname);
   end
end

% INITIALIZE VARIABLES AND FORMAT SPEC
delimiter = '\t';
   startRow = 1;
   endRow = inf;
formatSpec = '%f%*s%f%f%f%f%*s%f%[^\n\r]';

% OPEN FILE
fileID = fopen(filename,'r');

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
lickdata = table(dataArray{1:end-1}, 'VariableNames',...
   {'tlick','trialnumber','duringsound','duringwindow','duringiti','stim'});
