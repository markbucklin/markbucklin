function timeStamp = readAllHamamatsuTimestamps(fileName)
warning('readAllHamamatsuTimestamps.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')


% INITIALIZE OUTPUT
timeStamp = [];
varargout{1} = [];


% DEFINE TIME-STAMP READING FUNCTION FOR SINGLE FRAME (TIFF DIRECTORY)
timeStampFcn = @readHamamatsuTimeFromStart;


% USE CELL ARRAY TO HANDLE MULTI-FILE INPUT
if ischar(fileName)
	allTiffObj = {Tiff(fileName)};
	numFiles = 1;
elseif iscell(fileName)
	numFiles = numel(fileName);
	for kFile=1:numFiles
		allTiffObj{kFile} = Tiff(fileName{kFile});
	end
	
else
	error('readAllHamamatsuTimestamps:InvalidInput','Need Char or Cell Input')
	timeStamp = [];
	return
end


try
	
	parfor kFile = 1:numFiles
		
		warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning');
		idx = 0;
		localTiffObj = Tiff(fileName{kFile});
		t = [];
		
		while ~lastDirectory(localTiffObj) % idx < numFrames
			
			% GET CURRENT FRAME-INDEX (FILE-RELATIVE)
			idx = idx + 1;
			
			try
				% GET IMAGE-DESCRIPTION TAG FROM CURRENT DIRECTORY
				imDescription = localTiffObj.getTag(Tiff.TagID.ImageDescription);
				t(idx,1) = timeStampFcn(imDescription);
				
			catch me
				break
			end
			
			% INCREMENT FRAME OR USE NEXT TIFF OBJ
			nextDirectory(localTiffObj);
			
		end
		
		% STORE & CLEANUP
		allTimeStamps{kFile,1} = t;
		close(localTiffObj);
		
	end
	
	% CONCATENATE TIMESTAMPS FROM EACH FILE
	timeStamp = cat(1, allTimeStamps{:});
	
	
catch me
	close(tiffObj);
end


end




function t = readHamamatsuTimeFromStart(imageDescriptionTag)
% FUNCTION FOR EXTRACTING TIMESTAMP FROM 'ImageDescription' TIFF TAG
[idLines,~] = strsplit(imageDescriptionTag,'\r\n');
tfsLine = idLines{strncmp(' Time_From_Start',idLines,12)};
tfsNum = sscanf(tfsLine,' Time_From_Start = %d:%d:%f');
t = tfsNum(1)*3600 + tfsNum(2)*60 + tfsNum(3);
end



