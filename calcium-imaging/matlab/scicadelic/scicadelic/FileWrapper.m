classdef (CaseInsensitiveProperties, TruncatedProperties)...
		FileWrapper < scicadelic.Object & handle
	
	
	
	
	
	properties
		FileName
		FileDirectory
		FileExtension = '*'
		FullFilePath
	end
	properties
		DataSetName = ''
	end
	properties (SetAccess = protected)
		NumFiles
	end
	
	
	properties (SetAccess = ?scicadelic.Object, GetAccess = protected)
	end
	
	
	
	
		% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = FileWrapper(varargin)
			
			% PARSE INPUT
			parseConstructorInput(obj,varargin{:});
			
			% CHECK VALIDITY OF SPECIFIED INPUT
			checkFileInput(obj)
			
		end
	end
	
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
	methods
		function checkFileInput(obj)
			try
				% SET DEFAULT DIRECTORY TO CURRENT DIRECTORY IF NOT SPECIFIED
				if isempty(obj.FileDirectory)
					obj.FileDirectory = pwd;
				end
				
				% UPDATE FULLY QUALIFIED PATHS TO FILES
				if ~isempty(obj.FileDirectory) ...
						&& isdir(obj.FileDirectory) ...
						&& ~isempty(obj.FileName)
					updateFullFilePathFromNameDir(obj,obj.FileName,obj.FileDirectory)
				end
				
				% QUERY USER IF FULLY QUALIFIED PATH STILL HASN'T BEEN SPECIFIED
				if isempty(obj.FullFilePath)
					queryFileInput(obj)
					return
				end
				
				% CHECK FOR EXISTENCE OF ALL FILES
				if ~isempty(obj.FullFilePath)
					for k=1:numel(obj.FullFilePath)
						assert(logical(exist(obj.FullFilePath{k}, 'file')))
					end
				end
				
				% UPDATE NUM-FILES PROPERTY
				obj.NumFiles = numel(obj.FileName);
				
				% CONSTRUCT A DESCRIPTIVE NAME FOR THIS SET OF FILES
				% 				obj.DataSetName = ignition.io.getNameFromFileSequence(...
				obj.DataSetName = obj.getNameFromFileSequence(...
					obj.FileName, obj.FileDirectory);
				
			catch me
				rethrow(me)
			end
			
		end
		function queryFileInput(obj,fileExtension)
			
			% USE DEFAULT WILDCARD FILE EXTENSION IF NO INPUT GIVEN
			if (nargin<2)
				fileExtension = obj.FileExtension;
			end
			fileSpec = ['*.',fileExtension]; % '*.tif'
			
			% QUERY USER -> ASK TO SELECT ONE OR MULTIPLE FILES
			[fname,fdir] = uigetfile(fileSpec,'MultiSelect','on');
			
			% UPDATE PROPERTIES USING SELECTED FILES
			updateFullFilePathFromNameDir(obj,fname,fdir)
			obj.FileDirectory = fdir;
			obj.FileName = fname;
			
			% CHECK THAT SPECIFIED FILES ARE ACCESSIBLE
			checkFileInput(obj)
			
		end
		function updateFullFilePathFromNameDir(obj,fname,fdir)
			
			% UPDATE FULL-FILE-PATH (CELL ARRAY)
			switch class(fname)
				case 'char'
					obj.FullFilePath{1} = [fdir,fname];
				case 'cell'
					for n = numel(fname):-1:1
						obj.FullFilePath{n} = fullfile(fdir,fname{n});
					end
			end
			
			% UPDATE FILE EXTENSION
			[~,~,dotfext] = fileparts(obj.FullFilePath{1});
			obj.FileExtension = dotfext(2:end);
			
		end
	end
	methods (Static)
		function dataSetName = getNameFromFileSequence(fileName, fileDir)
			% Define data set name
			% >> dataSetName = scicadelic.FileWrapper.getNameFromFileSequence(fileName, fileDir)
			
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
	end
	
	
	
	% ##################################################
	% PROPERTY-SET METHODS
	% ##################################################
	methods
		function set.FileName(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				class(obj), 'FileName');
			if ischar(value)
				obj.FileName = {value};
			else
				obj.FileName = value;
			end
		end
		function set.FileDirectory(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				class(obj), 'FileDirectory');
			if ischar(value)
				obj.FileDirectory = value;
			else
				obj.FileDirectory = value{1};
			end
		end
		function set.FullFilePath(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				class(obj), 'FullFilePath');
			if ischar(value)
				obj.FullFilePath = {value};
			else
				obj.FullFilePath = value;
			end
		end
	end
	
	
	
	
	
	
	
	
end
