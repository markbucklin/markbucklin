classdef TiffLoaderFP < FluoProFunction
	
	
	
	properties
		fileName
		fileDirectory
		fullFilePath
		fileFrameIdx
	end
	properties (SetAccess = protected)
		nFiles
		nFramesInFiles
		tifFile
		inputDataType
	end
	properties
		readTimeStampFcn = @(tag) getHcTimeStamp(tag)		
	end
	
	
	methods
		function obj = TiffLoaderFP(varargin)
			checkFluoProOptions(obj);
			% 			obj = obj@FluoProFunction(varargin{:});
			if nargin
				fname = varargin{1};
				switch class(fname)
					case 'char'
						obj.fileName = cellstr(fname);
					case 'cell'
						obj.fileName = fname;
				end
				[obj.fileDirectory,~] = fileparts(which(obj.fileName{1}));
			else
				obj.isInteractive = true;
				[fname,fdir] = uigetfile('*.tif','MultiSelect','on');
				switch class(fname)
					case 'char'
						obj.fileName{1} = [fdir,fname];
					case 'cell'
						obj.fileName = cell(numel(fname),1);
						for n = 1:numel(fname)
							obj.fileName{n} = [fdir,fname{n}];
						end
				end
				obj.fileDirectory = fdir;
			end			
			[~,obj.dataSetName] = fileparts(fileparts(obj.fileDirectory));
			obj.nFiles = numel(obj.fileName);
			obj.usePct = false;
			obj.canUseGpu = false;
			obj.canUsePct = true;			
		end
		function obj = checkInput(obj)
			% >> obj = checkInput(obj)
			
			%TODO: check fileName and fileDirectory and compare/update fullFilePath (cell array)
			% ------------------------------------------------------------------------------------------
			% GET INFO FROM EACH TIF FILE
			% ------------------------------------------------------------------------------------------
			obj.nFiles = numel(obj.fileName);
			obj.tifFile = struct(...
				'fileName',obj.fileName(:),...
				'tiffTags',repmat({struct.empty(0,1)},obj.nFiles,1),...
				'nFrames',repmat({0},obj.nFiles,1),...
				'frameSize',repmat({[1024 1024]},obj.nFiles,1));
			obj = setStatus(obj,0,'Aquiring Information from Each TIFF File');
			for n = 1:obj.nFiles
				obj.tifFile(n).fileName = obj.fileName{n};
				obj.tifFile(n).tiffTags = imfinfo(obj.fileName{n});
				obj.tifFile(n).nFrames = numel(obj.tifFile(n).tiffTags);
				obj.tifFile(n).frameSize = [obj.tifFile(n).tiffTags(1).Height obj.tifFile(n).tiffTags(1).Width];
			end
			obj.nFramesInFiles = sum([obj.tifFile(:).nFrames]);
			obj.fileFrameIdx.last = cumsum([obj.tifFile(:).nFrames]);
			obj.fileFrameIdx.first = [0 obj.fileFrameIdx.last(1:end-1)]+1;
			for n = 1:obj.nFiles
				obj = setStatus(obj,n/obj.nFiles);
				obj.tifFile(n).firstIdx = obj.fileFrameIdx.first(n);
				obj.tifFile(n).lastIdx = obj.fileFrameIdx.last(n);
			end
			switch obj.tifFile(1).tiffTags(1).BitDepth
				case 16
					obj.inputDataType = 'uint16';
				case 8
					obj.inputDataType = 'uint8';
				otherwise
					obj.inputDataType = 'single';
			end
		end
		function obj = loadInput(obj)
			% TIFFLOADERFP
			% >> obj = loadInput(obj)
			
			% ------------------------------------------------------------------------------------------
			% PREALLOCATE STRUCTURE FOR FRAME INFO
			% ------------------------------------------------------------------------------------------
			obj.info = struct(...
				'frame',repmat({0},obj.nFramesInFiles,1),...
				'subframe',repmat({0},obj.nFramesInFiles,1),...
				'tiffTag',repmat({obj.tifFile(1).tiffTags(1)},obj.nFramesInFiles,1),...
				't',NaN,...
				'timestamp',struct('hours',NaN,'minutes',NaN,'seconds',NaN));
			% ------------------------------------------------------------------------------------------
			% FILL INFO STRUCTURE INCLUDING NON-UNIVERSAL TIMESTAMP READ  % TODO: Separate???
			% ------------------------------------------------------------------------------------------
			tryCustomTimeStampFcn = ~isempty(obj.readTimeStampFcn) ...
				&& isa(obj.readTimeStampFcn, 'function_handle');
			for n=1:numel(obj.tifFile)
				firstFrame = obj.fileFrameIdx.first(n);
				lastFrame = obj.fileFrameIdx.last(n);
				tifInfo = obj.tifFile(n).tiffTags;
				subk = 1;
				for k = firstFrame:lastFrame
					obj.info(k).frame = k;
					obj.info(k).subframe = subk;
					obj.info(k).tiffTag = tifInfo(subk);
					if tryCustomTimeStampFcn
						try
							obj.info(k).timestamp = obj.readTimeStampFcn(obj.info(k).tiffTag);
							obj.info(k).t = obj.info(k).timestamp.seconds;
						catch me
							warndlg(sprintf(...
								'TiffLoaderFP encountered an error while attempting to retrieve time-stamps from TIFF tags (%s)',...
								me.message));
							obj.info(k).t = NaN;
						end
					else
						% TODO: Will need to survey formats to see what people tend to use
					end
					subk = subk + 1;
				end
			end			
			% ------------------------------------------------------------------------------------------
			% CUSTOMIZE WAITBAR STRING
			% ------------------------------------------------------------------------------------------
			[fp,~] = fileparts(obj.tifFile(1).fileName);
			[~,fp] = fileparts(fp);
			obj = setStatus(obj,0, sprintf('Loading %s from %i files (%i frames)', fp, obj.nFiles, obj.nFramesInFiles));			
			% ------------------------------------------------------------------------------------------
			% PREALLOCATE ARRAY FOR IMAGE DATA
			% ------------------------------------------------------------------------------------------
			blankFrame = zeros(obj.tifFile(1).frameSize, obj.inputDataType); % TODO: which tag??
			[nrows,ncols] = size(blankFrame);
			% 			setData(:,:,obj.nFramesInFiles) = blankFrame; %TODO: repoint to memory map
			obj.nFrames = obj.nFramesInFiles;
			obj.frameIdx = [1:obj.nFrames]';
			obj.frameProcessed = false(obj.nFramesInFiles,1);
			% ------------------------------------------------------------------------------------------
			% LOAD RAW DATA FROM TIFF FILES
			% ------------------------------------------------------------------------------------------
			if obj.usePct				
				if isempty(gcp('nocreate'))
					parpool(4);
				end
				parfor n = 1:numel(obj.tifFile)
					warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
					warning off MATLAB:tifflib:TIFFReadDirectory:libraryWarning
					tiffFileName = obj.tifFile(n).fileName;
					tifObj = Tiff(tiffFileName,'r');
					nSubFrames = obj.tifFile(n).nFrames;
					fileData = zeros([nrows,ncols, nSubFrames], obj.inputDataType);
					fileDataIdx = zeros(nSubFrames,1);
					for ksf = 1:nSubFrames						
						kFrame = obj.fileFrameIdx.first(n) + ksf - 1;
						fileDataIdx(ksf) = kFrame;
						fileData(:,:,ksf) = tifObj.read();						
						if tifObj.lastDirectory()
							break
						else
							tifObj.nextDirectory();
						end
					end
					close(tifObj);
					setData{n} = fileData;
				end
				obj.data = cat(3,setData{:});
			else
				obj.data = zeros([nrows,ncols,obj.nFramesInFiles], obj.inputDataType);
				for n = 1:numel(obj.tifFile)
					warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
					warning off MATLAB:tifflib:TIFFReadDirectory:libraryWarning
					tiffFileName = obj.tifFile(n).fileName;
					tifObj = Tiff(tiffFileName,'r');					
					nSubFrames = obj.tifFile(n).nFrames;
					for ksf = 1:nSubFrames
						obj = setStatus(obj, ksf/nSubFrames);
						kFrame = obj.fileFrameIdx.first(n) + ksf - 1;
						obj.data(:,:,kFrame) = tifObj.read();
						obj.frameProcessed(kFrame) = true;
						if tifObj.lastDirectory()
							break
						else
							tifObj.nextDirectory();
						end
					end
					close(tifObj);
				end
			end
			if obj.useMemoryMap
				obj = mapDataOnDisk(obj);
			end
			obj = setStatus(obj,inf);			
		end
	end
	
	
	
	
	
	
	
	
end



































