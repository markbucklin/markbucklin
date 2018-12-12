classdef (CaseInsensitiveProperties, TruncatedProperties)  BufferedTiffStackLoader <  scicadelic.System ...
		& matlab.system.mixin.FiniteSource
	% BufferedTiffStackLoader
	
	
	
	% SETTINGS
	properties (Nontunable)
		FileName
		FileDirectory
		FullFilePath
		ParseFrameInfoFcn = @parseHamamatsuTiffTag
		DataSetName = ''
		MaxLatency = 1
		NumFramesPerBufferBlock = 8
		NumFramesPerStep = 8 % FramesAvailableFcnCnt
		FrameIdxList
		FirstFrameIdx
		LastFrameIdx
	end
	properties
		MaxFrameRate = 100
	end
	
	% OUTPUT SETTINGS
	properties (Nontunable, Logical)
		FrameDataOutputPort = true
		FrameTimeOutputPort = true
		FrameInfoOutputPort = true
		FrameIdxOutputPort = false
	end
	
	% HIDDEN SETTINGS
	properties (Constant, PositiveInteger, Hidden)
		MinSampleNumber = 100
	end
	
	% CURRENT STATE (Frame & File Index)
	properties (SetAccess = ?scicadelic.System)
		NextFrameIdx = 0
		NextBufferIdx = 0
	end
	properties (SetAccess = ?scicadelic.System)
		InitializedFlag @logical scalar = false
		FinishedFlag @logical scalar = false
		IsLastFile = false;
	end
	
	% OUTPUT
	properties (SetAccess = ?scicadelic.System)
		FrameData
		FrameTime
		FrameInfo
		FrameIdx
	end
	
	% TIFF-STACK -FILE & -FRAME INFO
	properties (SetAccess = ?scicadelic.System, Nontunable)
		TiffObj @Tiff vector
		StackInfo
		FileInfo
		TagIDs
		TagNames
		FirstFrameTag
		FirstFrameTime
		FirstFrameInfo
		LastFrameTag
		LastFrameTime
		LastFrameInfo
	end
	properties (SetAccess = ?scicadelic.System, Nontunable)
		FrameSize
		NumRows
		NumCols
		NumChannels
		NumFrames
		NumFiles
	end
	
	% EMULATE IMAQ.VIDEODEVICE
	properties (SetAccess = ?scicadelic.System, Nontunable)
		ReturnedDataType
		BytesPerPixel
		MegaBytesPerFrame
		ReturnedColorSpace
		VideoFormat
	end
	
	% PARALLEL COMPUTING PROPS
	properties (SetAccess = ?scicadelic.System, Nontunable, Hidden)
		ParallelFutureObj
		NumBufferBlocks
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = ?scicadelic.System, Nontunable, Hidden)
		FileIdxLUT
		RelativeFrameIdxLUT
		BufferedFrameIdx
		IsUnreadFrameIdx
	end
	properties (SetAccess = ?scicadelic.System, Hidden)
		StartFrameIdx = 1
		CurrentLoadedFrameIdx = 0
	end
	
	% FRAME-IDX MAPPING FUNCTION-HANDLES
	properties (SetAccess = ?scicadelic.System, Nontunable, Hidden)
		IsValidIdx
		GetValidIdx
		LookupFileIdx
		LookupRelIdx
	end
	
	% FRAME DISPATCH/LOAD & FETCH FUNCTION-HANDLES
	properties (SetAccess = ?scicadelic.System, Nontunable, Hidden)
		ReadFrameFcn
	end
	
	
	
	events
		Start
		Load
		Data
		Pause
		OnLast
		Stop
		Error
	end
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = BufferedTiffStackLoader(varargin)
			
			obj.CanUseGpu = false; % todo
			obj.CanUseParallel = true;
			obj.CanUseBuffer = true;
			obj.CanUseInteractive = true;
			
			parseConstructorInput(obj,varargin(:));
			
			initialize(obj)
			
		end
	end
	
	
	% ##################################################
	% INTERNAL SYSTEM METHODS
	% ##################################################
	methods (Access = protected)
		
		% ============================================================
		% SETUP
		% ============================================================
		function setupImpl(obj)
			fprintf('TiffLoader Setup\n')
			
			% 			if ~obj.InitializedFlag
			initialize(obj)
			% 			end
			
			% 			initializeBuffer(obj)
			
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function varargout = stepImpl(obj)
			
			% LOAD FRAME/FRAMES
			% 			[frameData, frameTime, frameInfo, frameIdx] = fillNextBufferBlock(obj);
			[frameData, frameTime, frameInfo, frameIdx] = fillNextBufferBlock(obj);
			
			% todo: implement with timer or loop for multi framesperstep/framesperbuffer ratio
			% 			if numel(obj.FrameData) > 1
			% 				frameData = obj.FrameData{1};
			% 				obj.FrameData = obj.FrameData{2:end};
			% 				frameInfo = obj.FrameInfo{1};
			% 				obj.FrameInfo = obj.FrameInfo{2:end};
			% 				frameTime = obj.FrameTime{1};
			% 				obj.FrameTime = obj.FrameTime{2:end};
			% 			elseif (numel(obj.FrameData) == 1)
			% 				frameData = obj.FrameData{1};
			% 				obj.FrameData = {};
			% 				frameTime = obj.FrameTime{1};
			% 				obj.FrameTime = {};
			% 				frameInfo = obj.FrameInfo{1};
			% 				obj.FrameInfo = {};
			% 			else
			% 				frameData = [];
			% 				frameTime = [];
			% 				frameInfo = struct.empty;
			% 				%frameIdx
			% 			end
			
			
			% RETURN VARIABLE OUTPUT ARGUMENTS
			if nargout
				requestedOutput = [...
					obj.FrameDataOutputPort,...
					obj.FrameTimeOutputPort,...
					obj.FrameInfoOutputPort,...
					obj.FrameIdxOutputPort];
				availableOutput = {frameData, frameTime, frameInfo, frameIdx};
				varargout = availableOutput(requestedOutput);
			end
			
			
			% 			numArgsOut = nargout;
			% 			numOutputs = getNumOutputsImpl(obj);
			% 			argsOut = cell(numOutputs,1);
			% 			[argsOut{:}] = outputImpl(obj);
			% 			varargout = argsOut(1:min(numOutputs,numArgsOut));
			
			
			
		end
		function resetImpl(obj)
			
			fprintf('TiffLoader Reset\n')
			
			% KEEP TRACK OF COMPLETED FRAMES
			obj.FinishedFlag = false;
			% 			obj.InitializedFlag = false;
			
			% SET FRAME TO LOAD IN FIRST BUFFER
			% 			setFrameIdx(obj, 0)
			
			initialize(obj)
			
			% SET FRAME IDX TO LOAD IN FOLLOWING BUFFER
			if isempty(obj.NumFramesPerBufferBlock)
				obj.NumFramesPerBufferBlock = 8;
			end
			
			obj.NextFrameIdx = obj.StartFrameIdx;
			initializeBuffer(obj)
			obj.StartFrameIdx = 1;
			
		end
		function releaseImpl(obj)
			fprintf('TiffLoader Release\n')
			obj.InitializedFlag = false;
			
			% CLEAR TIFF OBJECT
			if ~isempty(obj.TiffObj)
				closeTiffObj(obj);
			end
			
			% DELETE BUFFERS (PARALLEL FUTURES OBJECTS) todo
			bufferFuture = obj.ParallelFutureObj;
			if ~isempty(bufferFuture)
				% 				cancel(bufferFuture)
				delete(bufferFuture)
			end
			
			obj.StartFrameIdx = 1;
			% 			obj.StartFrameIdx = obj.CurrentLoadedFrameIdx(end) + 1;			
			
			% 			if ~isempty(obj.FrameIdx);
			% 				lastReadFrameIdx = obj.FrameIdx{end};			
			% 				obj.NextFrameIdx = lastReadFrameIdx(end) + 1;
			% 			end
			
		end
		function numOutputs = getNumOutputsImpl(obj)
			numOutputs = nnz([...
				obj.FrameDataOutputPort,...
				obj.FrameTimeOutputPort,...
				obj.FrameInfoOutputPort,...
				obj.FrameIdxOutputPort]);
		end
		function numInputs = getNumInputsImpl(obj)
			numInputs = 0;
		end
		function flag = isDoneImpl(obj)
			flag = obj.FinishedFlag;
		end
	end
	
	% ##################################################
	% RUN-TIME HELPER FUNCTIONS
	% ##################################################
	methods (Access = protected, Hidden)
		function varargout = fillNextBufferBlock(obj)
			
			if isempty(obj.ParallelFutureObj) % (obj.NextFrameIdx(1) < 1) ||
				fprintf('call reset from fillnextbufferblock\n')
				reset(obj)
			end
			
			nextFrameIdx = obj.NextFrameIdx;
			bufferIdx = obj.NextBufferIdx;
			numPerBlock = obj.NumFramesPerBufferBlock;
			
			% LOAD DATA FROM REMOTE PARALLEL FUTURE OBJECT
			[~, frameData, frameTime, frameInfo] = fetchNext(obj.ParallelFutureObj(bufferIdx));%, .5);
			if ~isempty(frameInfo)
				frameIdx = cat(1, frameInfo.FrameNumber);
				obj.CurrentLoadedFrameIdx = frameIdx;
			else
				frameIdx = [];
			end
			
			
			% CHECK IF FINISHED
			if isempty(frameData) || (frameIdx(end) >= obj.LastFrameIdx)
				setStateFinished(obj)
				return
			else
				obj.FinishedFlag = false;
			end
			
			if nargout < 1
				
				% FILL MULTI-BLOCK CAPABLE CLIENT SIDE BUFFERS
				if ~isempty(obj.FrameInfo)
					obj.FrameData = cat(1, obj.FrameData, {frameData});
					obj.FrameTime = cat(1, obj.FrameTime, {frameTime});
					obj.FrameInfo = cat(1, obj.FrameInfo, {frameInfo});
					obj.FrameIdx = cat(1, obj.FrameIdx, {frameIdx});
				else
					obj.FrameData = {frameData};    %{bufferIdx}
					obj.FrameTime = {frameTime};
					obj.FrameInfo = {frameInfo};
					obj.FrameIdx = {frameIdx};
				end
			else
				availableArgs = {frameData, frameTime, frameInfo, frameIdx};
				varargout = availableArgs(1:nargout);
			end
			
			% DISPATCH REMOTE READ FUNCTION
			if ~isempty(nextFrameIdx)
				readFrameFcn = obj.ReadFrameFcn;
				obj.ParallelFutureObj(bufferIdx) = parfeval( obj.ParallelPoolObj, readFrameFcn, 3, obj.StackInfo, nextFrameIdx);
				obj.BufferedFrameIdx{bufferIdx,1} = nextFrameIdx;
				nextFrameIdx = nextFrameIdx(end)+(1:numPerBlock);
				nextFrameIdx = nextFrameIdx(nextFrameIdx <= obj.LastFrameIdx);
			end
			obj.NextFrameIdx = nextFrameIdx;
			obj.NextBufferIdx = mod(bufferIdx, obj.NumBufferBlocks) + 1;
			
			% todo: notify
			
		end
		function closeTiffObj(obj)
			for n = 1:numel(obj.TiffObj)
				if ~isempty(obj.TiffObj(n)) && isvalid(obj.TiffObj(n))
					close(obj.TiffObj(n));
				end
			end
		end
		function varargout = makeTiffObj(obj)
			
			suppressTiffWarnings()
			
			for n = 1:numel(obj.FullFilePath)
				tiffFileName = obj.FullFilePath{n};
				obj.TiffObj(n) = Tiff(tiffFileName,'r');
				addlistener(obj.TiffObj(n), 'ObjectBeingDestroyed', @(src,~) close(src));
			end
			
			if nargout
				varargout{1} = obj.TiffObj;
			end
			
		end
		function fileIdx = lookupFileIdx(obj, frameIdx)
			if ~isempty(obj.LookupFileIdx)
				fileIdx = obj.LookupFileIdx(frameIdx);
			else
				fileIdx = 1;
			end
		end
	end
	
	methods (Access = protected, Hidden)
		function setStateFinished(obj)
			obj.FinishedFlag = true;
		end
		function setStatePreInitialized(obj)
			obj.InitializedFlag = false;
		end
		function flag = isInitialized(obj)
			flag = obj.InitializedFlag;
		end
	end
	
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
	methods (Hidden)
		function initialize(obj)
			
			if isInitialized(obj)
				return
			end
			
			% START PARALLEL POOL
			if obj.UseParallel && isempty(obj.ParallelPoolObj)
				pool = gcp('nocreate');
				if isempty(pool)
					numCores = str2double(getenv('NUMBER_OF_PROCESSORS'));
					pool = parpool(numCores);
				end
				obj.ParallelPoolObj = pool;
			end
			
			% SELECT/CHECK INPUT SPECIFICATIONS (File Names & Paths)
			checkFileInput(obj)
			if isempty(obj.DataSetName) && ~isempty(obj.FileDirectory)
				[~,obj.DataSetName] = fileparts(fileparts(obj.FileDirectory));
			end
			numFiles = obj.NumFiles;
			fullFilePath = obj.FullFilePath(:);
			
			% DEFINE TAG PARSING FUNCTION (CUSTOM DEPENDING ON SOURCE)
			parseFrameInfoFcn = obj.ParseFrameInfoFcn;
			
			% CONSTRUCT LINKS TO TIFF FILES (MOVED FROM BELOW)
			allTiffObj = makeTiffObj(obj);
			
			% READ INITIAL TIFF-FILE INFO (FROM FIRST DIRECTORY)
			[stackInfo, fileInfo, ~] = initializeTiffStack(allTiffObj, parseFrameInfoFcn);
			
			% COPY STRUCTURED OUTPUT TO PROPERTIES
			obj.StackInfo = stackInfo;
			obj.FileInfo = fileInfo;
			fillPropsFromStruct(obj, stackInfo);
			
			% SET DEFAULT FIRST & LAST FRAME IDX
			% 			if isempty(obj.FirstFrameIdx) || (obj.FirstFrameIdx > obj.NumFrames)
			obj.FirstFrameIdx = 1;
			% 			end
			% 			if isempty(obj.LastFrameIdx) || (obj.LastFrameIdx > obj.NumFrames);
			obj.LastFrameIdx = obj.NumFrames;
			% 			end
			obj.FrameIdxList = (obj.FirstFrameIdx:obj.LastFrameIdx)';
			
			% DEFINE READING FUNCTION
			obj.ReadFrameFcn = @readFrameFromTiffStack;
			
			% CHUNK/BUFFER OUTPUT
			% 			numFramesPerBufferBlock = obj.NumFramesPerBufferBlock;
			obj.NumBufferBlocks = obj.ParallelPoolObj.NumWorkers;
			
			% SET UNREAD & BUFFERED IDX LUTS
			obj.BufferedFrameIdx = cell(obj.NumBufferBlocks,1);
			obj.IsUnreadFrameIdx = true( size(obj.FrameIdxList));
						
			obj.InitializedFlag = true;
			
		end
		function initializeBuffer(obj)
			
			% CANCEL & DELETE ANY CURRENTLY HELD BUFFER FUTURE OBJECTS
			bufferFuture = obj.ParallelFutureObj;
			if ~isempty(bufferFuture)
				% 				cancel(bufferFuture)
				try, delete(bufferFuture), catch, end
			else
				bufferFuture = parallel.FevalFuture.empty;
			end
			
			
			% GET LOCAL VARIABLES FROM PROPS
			numBlocks = obj.NumBufferBlocks;
			numPerBlock = obj.NumFramesPerBufferBlock;
			bufferIdx = 0;
			stackInfo = obj.StackInfo;
			parallelPoolObj = obj.ParallelPoolObj;
			readFrameFcn = obj.ReadFrameFcn;
			nextFrameIdx = obj.NextFrameIdx;
			
			% INITIALIZE NEXT-FRAME-IDX
			nextFrameIdx = max( 1, nextFrameIdx);
			if (numel(nextFrameIdx) ~= numPerBlock)
				
				nextFrameIdx = nextFrameIdx(end) + (0:(numPerBlock-1));
			end
			% TODO: add repository of frame indices to read
			
			% DISPATCH LOAD ON EACH PARALLEL WORKER
			for kBuf = 1:numBlocks
				bufferIdx = mod(bufferIdx,numBlocks) + 1;
				% 				obj.FrameIdxList(nextFrameIdx) % todo
				bufferFuture(bufferIdx) = parfeval( parallelPoolObj, readFrameFcn, 3, stackInfo, nextFrameIdx);
				obj.BufferedFrameIdx{kBuf,1} = nextFrameIdx;
				nextFrameIdx = nextFrameIdx(end)+(1:numPerBlock);
				
			end
			
			% REASSIGN VARIABLES TO PROPERTIES
			obj.NextBufferIdx = 1;
			obj.NextFrameIdx = nextFrameIdx;
			obj.ParallelFutureObj = bufferFuture;
			
			obj.FrameData = {};
			obj.FrameInfo = {};
			obj.FrameTime = {};
			obj.FrameIdx = {};
			
		end
		function getFileInputInteractive(obj)
			[fname,fdir] = uigetfile('*.tif','MultiSelect','on');
			updateFullFilePathFromNameDir(obj,fname,fdir)
			obj.FileDirectory = fdir;
			obj.FileName = fname;
			checkFileInput(obj)
		end
		function updateFullFilePathFromNameDir(obj,fname,fdir)
			switch class(fname)
				case 'char'
					obj.FullFilePath{1} = [fdir,fname];
				case 'cell'
					for n = numel(fname):-1:1
						obj.FullFilePath{n} = fullfile(fdir,fname{n});
					end
			end
		end
		function checkFileInput(obj)
			try
				if isempty(obj.FileDirectory)
					obj.FileDirectory = pwd;
				end
				if ~isempty(obj.FileDirectory) ...
						&& isdir(obj.FileDirectory) ...
						&& ~isempty(obj.FileName)
					updateFullFilePathFromNameDir(obj,obj.FileName,obj.FileDirectory)
				end
				if isempty(obj.FullFilePath)
					getFileInputInteractive(obj)
					return
				end
				if ~isempty(obj.FullFilePath)
					for k=1:numel(obj.FullFilePath)
						assert(logical(exist(obj.FullFilePath{k}, 'file')))
					end
				end
				obj.NumFiles = numel(obj.FileName);
			catch me
				if obj.UseInteractive
					getFileInputInteractive(obj)
				else
					rethrow(me)
				end
			end
		end
	end
	methods
		function [data, varargout] = getDataSample(obj, numSampleFrames)
			
			if isLocked(obj)
				% ------------------------------------------
				% RETURN CURRENTLY BUFFERED DATA (IF LOCKED)
				% ------------------------------------------
				% 				warning('BufferedTiffStackLoader:getDataSample:SystemLocked',...
				% 					['The BufferedTiffStackLoader is currently locked and is unable to return randomly sampled',...
				% 					'data. Data from current buffer will be returned instead. For a random data sample',...
				% 					'you must first call release(), then call getDataSample() again.'])
				% 				data = obj.FrameData;
				% 				info = obj.FrameInfo;
				% 				sampleFrameIdx = obj.FrameTime;
				release(obj)
				% 			else
			end
			% ------------------------------------------
			% RETURN RANDOMLY SAMPLED DATA
			% ------------------------------------------
			if ~isInitialized(obj)
				initialize(obj)
			end
			
			% LOCAL VARIABLES
			N = obj.NumFrames;
			
			% DETERMINE NUMBER OF FRAMES TO SAMPLE
			if nargin < 2
				numSampleFrames = min(N, obj.MinSampleNumber);
			end
			
			if isscalar(numSampleFrames)
				% GENERATE RANDOMLY SPACED FRAME INDICES TO SAMPLE
				jitter = floor(N/numSampleFrames);
				sampleFrameIdx = round(linspace(1, N-jitter, numSampleFrames)')...
					+ round( jitter*rand(numSampleFrames,1));
				
			else
				% USE SPECIFIC FRAME INDICES FROM VECTOR INPUT
				sampleFrameIdx = numSampleFrames;
				numSampleFrames = numel(sampleFrameIdx);
				
			end
			
			% LOAD FRAMES
			
			
			% GET FRAME-IDX MAPPING FUNCTION HANDLES
			lookupFileIdx = obj.LookupFileIdx;
			lookupRelIdx = obj.LookupRelIdx;
			
			% TODO: LOAD WITH ASYNC FUNCTION
			data(:,:,:,numSampleFrames) = zeros(obj.FrameSize, obj.InputDataType);
			
			% 			nextIdx = obj.CurrentFrameIdx;
			% 			for k=1:numSampleFrames
			% 				% 				setFrameIdx(obj, sampleFrameIdx(k));
			% 				fileIdx = lookupFileIdx(sampleFrameIdx(k));
			% 				relativeFrameIdx = lookupRelIdx(sampleFrameIdx(k));
			% 				setDirectory(obj.TiffObj(fileIdx), relativeFrameIdx) % Unnecessary???
			% 				data(:,:,:,k) = read(obj.TiffObj(fileIdx));
			% 			end
			
			
			% 			if ~isempty(currentIdx)
			% 				setFrameIdx(obj, currentIdx);
			% 			end
			
			% RETURN FRAME IDX IF 2ND OUTPUT REQUESTED
			if nargout > 1
				varargout{1} = sampleFrameIdx;
			end
			
		end
		function setFrameIdx(obj, frameIdx)
			% Sets the NextFrameIdx property to 'frameIdx', specifying the next frame(s) to read
			
			obj.StartFrameIdx = frameIdx(1);
			
			if isLocked(obj)				
				% DELETE BUFFERS (PARALLEL FUTURES OBJECTS) todo
				bufferFuture = obj.ParallelFutureObj;
				if ~isempty(bufferFuture)
					delete(bufferFuture)
				end
				obj.FinishedFlag = false;
				initialize(obj)
				obj.NextFrameIdx = obj.StartFrameIdx;
				initializeBuffer(obj)
				obj.StartFrameIdx = 1;
				% 				obj.StartFrameIdx = obj.CurrentLoadedFrameIdx(end) + 1;
				
				% 				release(obj)
			end
			% 			reset(obj);
			
			% 			obj.NextFrameIdx = frameIdx;
			
			% 			if (obj.NextFrameIdx(1) >= obj.NumFrames)
			% 				setStateFinished(obj)
			% 			end
			
		end
	end
	
	
	
	% ##################################################
	% PROPERTY-SET METHODS
	% ##################################################
	methods
		function set.FileName(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'BufferedTiffStackLoader', 'FileName');
			if ischar(value)
				obj.FileName = {value};
			else
				obj.FileName = value;
			end
			setStatePreInitialized(obj)
		end
		function set.FileDirectory(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'BufferedTiffStackLoader', 'FileDirectory');
			if ischar(value)
				obj.FileDirectory = value;
			else
				obj.FileDirectory = value{1};
			end
			setStatePreInitialized(obj)
		end
		function set.FullFilePath(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'BufferedTiffStackLoader', 'FullFilePath');
			if ischar(value)
				obj.FullFilePath = {value};
			else
				obj.FullFilePath = value;
			end
			setStatePreInitialized(obj)
		end
	end
	
	
	
end




function suppressTiffWarnings()

% SUPPRESS TIFFLIB WARNINGS
warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
warning('off','MATLAB:tifflib:TIFFReadDirectory:libraryWarning')
warning('off','MATLAB:imagesci:Tiff:closingFileHandle')

end



% 		function varargout = outputImpl(obj)
%
% 			% LOAD FRAME/FRAMES
% 			fillNextBufferBlock(obj)
%
% 			% todo: implement with timer or loop for multi framesperstep/framesperbuffer ratio
%
% 			frameData = obj.FrameData{1};
% 			if numel(obj.FrameData) > 1
% 				obj.FrameData = obj.FrameData{2:end};
% 			else
% 				obj.FrameData = {};
% 			end
%
% 			frameTime = obj.FrameTime{1};
% 			if numel(obj.FrameTime) > 1
% 				obj.FrameTime = obj.FrameTime{2:end};
% 			else
% 				obj.FrameTime = {};
% 			end
%
% 			frameInfo = obj.FrameInfo{1};
% 			if numel(obj.FrameInfo) > 1
% 				obj.FrameInfo = obj.FrameInfo{2:end};
% 			else
% 				obj.FrameInfo = {};
% 			end
%
% 			frameIdx = obj.FrameIdx{1};
% 			if numel(obj.FrameIdx) > 1
% 				obj.FrameIdx = obj.FrameIdx{2:end};
% 			else
% 				obj.FrameIdx = {};
% 			end
%
%
% 			% RETURN VARIABLE OUTPUT ARGUMENTS
% 			if nargout
% 				requestedOutput = [...
% 					obj.FrameDataOutputPort,...
% 					obj.FrameTimeOutputPort,...
% 					obj.FrameInfoOutputPort];
% 				availableOutput = {frameData, frameTime, frameInfo};
% 				varargout = availableOutput(requestedOutput);
% 			end
%
%
%
% 		end
% 		function updateImpl(obj, frameIdx)
%
% 		end

