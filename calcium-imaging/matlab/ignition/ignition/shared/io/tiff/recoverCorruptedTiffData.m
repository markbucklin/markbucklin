function tifFileOut = recoverCorruptedTiffData(save2disk)
%
% USAGE:
%			>> info = recoverCorruptedTiffData()
%			>> [info, vidData] = recoverCorruptedTiffData();
%
%

if nargin < 1
	save2disk = [];
end
if isempty(save2disk)
	save2disk = false;
end


try
	
	% CHOOSE FILES
	allFileNames = selectTiffFiles();
	numFiles = numel(allFileNames);
	h = waitbar(0,'File 0');
	
	% READ AVAILABLE INFO (WILL NOT RETRIEVE INFO FROM CORRUPTED FRAMES
	for kfile = 1:numFiles
		fullFileName = allFileNames{kfile};
		tif(kfile).filename = fullFileName;
		tif(kfile).obj = Tiff(fullFileName,'r');
		tif(kfile).info = imfinfo(fullFileName);
		tif(kfile).offset = int64(cat(1, tif(kfile).info.Offset));
		tif(kfile).numframes = numel(tif(kfile).info);
	end
	
	% GET GENERAL IMAGE INFO
	numRows = tif(1).info(1).Height;
	numCols = tif(1).info(1).Width;
	numFrames = max( [tif.numframes] );
	firstFrameData = tif(1).obj.read();
	imageDataNumBytes = int64(numRows*numCols* 2);
	
	% DETERMINE WHICH FILES ARE CORRUPTED
	hasMaxNumFrames = ([tif.numframes] == numFrames);
	isCorrupt = ~hasMaxNumFrames;
	isCorrupt(end) = false;
	
	% DETERMINE HEADER|DATA SIZES (SHOULD BE REPEATED PATTERN)
	allFrameOffset = [tif(hasMaxNumFrames).offset];
	fullFileFrameOffset = mode(allFrameOffset,2);
	allFrameBytes = diff(int64(fullFileFrameOffset));
	frameTagBytes = max(allFrameBytes) - imageDataNumBytes;
	
	% ASSUME HEADER & FRAME SIZE CONSTANT
	% frameEndOffset = tif(1).offset;
	
	
	% FOR EACH FILE -> READ HEADER BYTES & RAW DATA FROM EACH FRAME
	for kfile = 1:numFiles
		fullFileName = tif(kfile).filename;
		tif(kfile).iscorrupt = isCorrupt(kfile);
		
		% PREPARE TIFF REWRITE
		if save2disk
			[fpath,fname,~] = fileparts(fullFileName);
			outDir = [fpath,filesep,'uncorrupted'];
			if ~isdir(outDir)
				mkdir(outDir);
			end
		end
		
		% PREALLOCATE & DETERMINE NUMBER OF FRAMES TO EXPECT
		if kfile ~= numFiles
			vidFrame(numFrames).tagdata = zeros(frameTagBytes,1, 'uint8');
			vidFrame(numFrames).cdata = firstFrameData .* 0;
			N = numFrames;
		else
			N = tif(kfile).numframes;
		end
		
		% 	if ~isCorrupt(kfile)
		% 		frameEndOffset = tif(kfile).offset;
		% 	end
		% 	N = numel(frameEndOffset);
		
		% OPEN FILE
		fid = fopen(fullFileName, 'r');
		kframe = 0;
		waitbar(0, h, sprintf('File %i',kfile));
		
		% SKIP FIRST 8 BYTES -> 8-BYTE FILE HEADER (TIFF FILE IDENTIFIER 0X4d4d002a)
		fseek( fid, 8, 'bof');
		
		%  READ HEADER AND DATA FROM EACH FRAME
		while (kframe < N) && ~(feof(fid))
			kframe = kframe + 1;
			frameData = fread(fid, [numRows,numCols], '*uint16');
			frameTags = fread(fid, [frameTagBytes,1], '*uint8');
			vidFrame(kframe).tagdata = frameTags;
			vidFrame(kframe).cdata = frameData;
			waitbar(kframe/N,h);
		end
		vidFrame = vidFrame(1:N);
		
		% CLOSE FILE
		fclose(fid);
		
		if save2disk
			
			% COPY DATA TO NEW TIFF FILE (32-bit TIFF)
			% 	outFileName = [outDir,filesep,fname,fext];
			% 	writeTiffFile(vidFrame, outFileName);
			
			% OR ... WRITE TO BINARY DATA FILE & SCRAP HEADER INFO -> use readBinaryData() in pfgc package to read.
			outFileName = [outDir,filesep,fname];
			writeBinaryData(vidFrame, outFileName);
			
		end
		
		% GATHER INFO FOR RECONSTRUCTION
		tifFileOut(kfile).filename = tif(kfile).filename;
		tifFileOut(kfile).numframes = tif(kfile).numframes;
		tifFileOut(kfile).tagdata = {vidFrame.tagdata};
		tifFileOut(kfile).mminfo = tif(kfile).info;
		
		if ~save2disk
			tifFileOut(kfile).frame = vidFrame;
			% 			vidFileData{kfile} = vidFrame;
		end
		close(tif(kfile).obj);
		
	end
	
	% CLOSE FILES & PROGRESS BAR	
	close(h)
	
	% 	if nargout >=2
	% 		varargout{1} = vidFileData;
	% 	end
	
	% COPY DATA TO NEW TIFF FILE (64-bit 'BIG'TIFF)
	% bigFileName = [outDir,fname,fext];
	% writeTiffFile( [tif.frame], bigFileName);
	
	
catch me
	getReport(me)
	if exist('tifFileOut','var')
		assignin('base','tifFileOut',tifFileOut);
	end
	close(h)
	close([tif.obj]);
end


end



% WRITE-TIFF-FILE
function writeTiffFile(vidFrame, fullFileName)
% ------------------------------------------------------------------------------
% WRITETIFFFILE
% 7/30/2015
% Mark Bucklin
% ------------------------------------------------------------------------------
%
% DESCRIPTION:
%   Data may be any numeric type array of 3 or 4 dimensions
%
%
% USAGE:
%   >> writeTiffFile( data)
%   >> writeTiffFile( data, fileName)
%
%
% See also:
%	READBINARYDATA, PROCESSFAST, WRITEBINARYDATA, TIFF
% ------------------------------------------------------------------------------
% ------------------------------------------------------------------------------
% ------------------------------------------------------------------------------

t = Tiff(fullFileName,'w8');
try
	k = 1;
	imFrame = vidFrame(k).cdata;
	[numRows,numCols,numChannels] = size(imFrame);
	numFrames = numel(vidFrame);
	
	tagstruct.ImageLength = numRows;
	tagstruct.ImageWidth = numCols;
	tagstruct.Photometric = Tiff.Photometric.MinIsBlack;
	
	switch class(imFrame)
		case {'uint8','int8'}
			tagstruct.BitsPerSample = 8;
		case {'uint16','int16'}
			tagstruct.BitsPerSample = 16;
		otherwise
			tagstruct.BitsPerSample = 8;
	end
	tagstruct.SamplesPerPixel = numChannels;
	tagstruct.RowsPerStrip = numRows;
	tagstruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
	tagstruct.Software = 'MATLAB';
	
	% WRITE FIRST FRAME TAG (HEADER) & IMAGE DATA
	t.setTag(tagstruct)
	t.write(imFrame)
	tic
	
	% WRITE REMAINING FRAMES
	while (k < numFrames)
		%         if mod(k, 256) == 0
		%             fprintf('writing frame %g of %g\n',k,numFrames);
		%         end
		k = k + 1;
		t.writeDirectory();
		t.setTag(tagstruct);
		imFrame = vidFrame(k).cdata;
		t.write(imFrame);
		% 	t.nextDirectory
	end
	t.writeDirectory();
	t.close;
	toc
	
catch me
	disp(me.message)
	t.close
end

end
% SELECT-TIFF-FILES
function fullFilePath = selectTiffFiles(fdir)
% Returns a full file path or cell array of full file paths to TIFF files. Files are selected either
% by querying the user to choose files, or (if a valid directory string is given as input) by
% selecting all TIFF files from inside the given directory.
%
%			>> fullFileName = selectTiffFiles();
%			>> fullFileName = selectTiffFiles(pwd);
%			>> fullFileName = selectTiffFiles('Z:\Data\MyTiffFolder\');
%
% Mark Bucklin
% 02/2016
%

if (nargin < 1), fdir = []; end
if isempty(fdir) || ~isdir(fdir)
	% QUERY USER TO SELECT TIFF FILES
	[fname,fdir] = uigetfile('*.tif','MultiSelect','on');
	
else
	% GET TIFF FILES FROM GIVEN DIRECTORY
	tiffInDir = dir(fullfile(fdir, '*.tif'));
	fname = {tiffInDir.name};
	
end

fullFilePath = updateFullFilePathFromNameDir(fname,fdir);
fullFilePath = fullFilePath(:);

end
% UPDATE-FULL-FILE-PATH-FROM-NAME-DIR
function fullFilePath = updateFullFilePathFromNameDir(fname,fdir)
switch class(fname)
	case 'char'
		fullFilePath{1} = [fdir,fname];
	case 'cell'
		for n = numel(fname):-1:1
			% 						obj.FullFilePath{n} = [fdir,fname{n}];
			fullFilePath{n} = fullfile(fdir,fname{n});
		end
end
end
% WRITE-BINARY-DATA
function varargout = writeBinaryData(dataIn, fileName)
% ------------------------------------------------------------------------------
% WRITEBINARYDATA
% 7/30/2015
% Mark Bucklin
% ------------------------------------------------------------------------------
%
% DESCRIPTION:
%
%
% USAGE:
%		>> writeBinaryData(data)
%		>> writeBinaryData(data, fileName)
%
%
%
% See also:
%			PROCESSFAST, READBINARYDATA, WRITETIFFFILE
% ------------------------------------------------------------------------------
% ------------------------------------------------------------------------------
% ------------------------------------------------------------------------------


% EXAMINE DATA INPUT
if isstruct(dataIn) && isfield(dataIn,'cdata')
	data = cat(3,dataIn.cdata);
else
	data = dataIn;
end
saveSpeedEstimateMBPS = 350;
dataType = class(data);
dataSize = size(data);
numMegaBytes = MB(data);
numGigaBytes = GB(data);
fileExt = dataType;

% MANAGE FILE NAME
for dataDim = numel(dataSize):-1:1
	fileExt = [num2str(dataSize(dataDim)), '.', fileExt];
end
if nargin < 2
	[fname_fext, fdir] = uiputfile(['*.',fileExt]);
	fileName = fullfile(fdir,fname_fext);
else
	fileName = [fileName,'.',fileExt];
end

% QUERY USER IF A FILE ALREADY EXISTS
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
			fileName = [fileName,'(',num2str(copyNum),')'];
			writeMode = 'W';
	end
else
	writeMode = 'W';
end

% OPEN AND WRITE DATA TO BINARY FILE
tOpen = tic;
fid = fopen(fileName, writeMode);
fwrite(fid, data(:), dataType);

% CREATE TIMER THAT CLOSES FILE AFTER DELAY TO ALLOW ASYNCHRNOUS WRITE
estimatedSaveTime = numMegaBytes / saveSpeedEstimateMBPS;
closeTimer = timer(...
	'ExecutionMode', 'singleShot',...
	'StartDelay', 10*ceil(.1*estimatedSaveTime),...
	'TimerFcn', @closeFile, ...
	'StopFcn', @deleteTimer, ...
	'ErrorFcn', @sendFidToBase);

% MANAGE OUTPUT
if nargout
	varargout{1} = fileName;
end

% START TIMER
start(closeTimer)



% ################################################################
% SUBFUNCTIONS
% ################################################################
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








