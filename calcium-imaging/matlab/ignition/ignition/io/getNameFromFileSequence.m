function dataSetName = getNameFromFileSequence(fileName, fileDir)
% DEFINE DATA SET NAME
% TODO: delete because moved to static method in FileWrapper class

% IF COMMON-DIRECTORY ISN'T GIVEN TRY TO EXTRACT FROM FILENAME
if nargin<2
	fileDir = '';
end

try
	
	if ischar(fileName)
		% FILE-NAME IS A CHARACTER STRING
		firstFileName = fileName;
		dataSetName = fileName;
		
		
	elseif iscell(fileName)
		% FILE-NAME IS IN CELL ARRAY
		
		if numel(fileName) == 1
			% SINGLE FILE
			firstFileName = fileName{1};
			dataSetName = fileName{1};
			
			
		elseif numel(fileName) > 1
			% MULTIPLE FILES -> CONSTRUCT STRING INDICATING SEQUENCE (FIRST-LAST)
			firstFileName = fileName{1};
			
			% FIND INCONSISTENCIES BETWEEN FILE-NAMES IN SET
			[~, nameA, ~] = fileparts(fileName{1});
			nameLength = length(nameA);
			consistentNameParts = true(1,nameLength);
			for k = 2:numel(fileName)
				[~, nameK, ~] = fileparts(fileName{k});
				nameLength = min( nameLength, length(nameK));
				consistentNameParts = consistentNameParts(1:nameLength) ...
					& (nameA(1:nameLength) == nameK(1:nameLength));
			end
			inconsistentPart = find(~consistentNameParts);
			
			% CONSTRUCT CONSISTENT FILE NAME THAT INDICATES RANGE
			consistentFileName = [ nameA(1:inconsistentPart(end)) ,...
				' - ' , nameK(inconsistentPart) ,...
				nameK((inconsistentPart(end)+1):end) ];
			
			dataSetName = consistentFileName;
			
			% TODO: remove leading zeros??			
		end
	end
	
	% ADD COMMON-DIRECTORY NAME TO DATA-SET-NAME IN SQUARE BRACKETS
	if isempty(fileDir)
		[fileDir,~,~] = fileparts(firstFileName);
	end
	if fileDir(end) == filesep
		fileDir = fileDir(1:end-1);
	end	
	[~,dataLocationName] = fileparts(fileDir);
	if ~isempty(dataLocationName)
		dataSetName = ['[',dataLocationName,'] ', dataSetName];
	end
	
catch 
	% 	warning() % TODO
end

end









			% TODO: a bit more complex, this only handles sequential numbering
			% 						consistentFileName = [ nameA(1:(inconsistentPart(1)-1)) ,...
			% 														' - ' , nameB(inconsistentPart) ,...
			% 														nameB((inconsistentPart(end)+1):end) ];
