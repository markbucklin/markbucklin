classdef (CaseInsensitiveProperties, TruncatedProperties)  ...
		TiffFileInput < ignition.core.Module & matlab.system.mixin.FiniteSource
	% TiffFileInput -> ThreadedImageLoader (TODO)
	
	
	
	% SETTINGS
	properties (Nontunable)
		FileName
		FileDirectory
		FullFilePath
		ParseFrameInfoFcnName = 'parseHamamatsuTiffTag'
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
		VideoStreamOutputPort = true
		FrameDataOutputPort = false
		FrameTimeOutputPort = false
		FrameInfoOutputPort = false
		FrameIdxOutputPort = false
	end
	% todo: VideoStreamOutputPort
	
	% HIDDEN SETTINGS
	properties (Constant, PositiveInteger, Hidden)
		MinSampleNumber = 100
	end
	
	% CURRENT STATE (Frame & File Index)
	properties (SetAccess = ?ignition.core.Object)
		NextFrameIdx = 0
		NextBufferIdx = 0
	end
	properties (SetAccess = ?ignition.core.Object, Transient)
		IsFinished @logical scalar = false
		IsLastFile = false;
	end
	
	% OUTPUT
	properties (SetAccess = ?ignition.core.Object)
		FrameData
		FrameTime
		FrameInfo
		FrameIdx
	end
	% todo: VideoBaseType -> make FrameData, FrameTime, etc Dependent
	
	% todo: FrameBuffer and/or FrameBufferCollection
	
	% TIFF-STACK -FILE & -FRAME INFO
	properties (SetAccess = ?ignition.core.Object, Nontunable)
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
	properties (SetAccess = ?ignition.core.Object, Nontunable)
% 		FrameSize
		NumRows
		NumCols
		NumChannels
		NumFrames
		NumFiles
	end
	
	% EMULATE IMAQ.VIDEODEVICE
	properties (SetAccess = ?ignition.core.Object, Nontunable)
		ReturnedDataType
		BytesPerPixel
		MegaBytesPerFrame
		ReturnedColorSpace
		VideoFormat
	end
	
	% PARALLEL COMPUTING PROPS
	properties (SetAccess = ?ignition.core.Object, Nontunable, Hidden)
		ParallelFutureObj @parallel.FevalFuture
		NumBufferBlocks
		PoolTimeoutListener
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = ?ignition.core.Object, Nontunable, Hidden)
		FileIdxLUT
		RelativeFrameIdxLUT
		BufferedFrameIdx
		IsUnreadFrameIdx
	end
	properties (SetAccess = ?ignition.core.Object, Hidden)
		StartFrameIdx = 1
		CurrentLoadedFrameIdx = 0
	end
	
	% FRAME-IDX MAPPING FUNCTION-HANDLES
	properties (SetAccess = ?ignition.core.Object, Nontunable, Hidden)
		IsValidIdx
		GetValidIdx
		LookupFileIdx
		LookupRelIdx
	end
	
	% FRAME DISPATCH/LOAD & FETCH FUNCTION-HANDLES
	properties (SetAccess = ?ignition.core.Object, Nontunable, Hidden)
		ReadFrameFcn
		ReadTaskSchedulerObj %@DeferredTask
	end
	
	
	
	events
		Start
		Load
		Data
		Pause
		OnLast
		Stop
	end
	% todo: implement event notifications and auto/timed fill of buffers in FrameData, FrameInfo, etc.
	% todo: utilize setStatus function in parent class
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = TiffFileInput(varargin)
			
			% CALL SUPERCLASS CONSTRUCTOR
			obj = obj@ignition.core.Module(varargin{:});
			
			% PARSE INPUT
			% 			parseConstructorInput(obj,varargin{:});
			
			% GET NAME OF PACKAGE CONTAINING CLASS
			% 			getCurrentClassPackage
			% 			obj.SubPackageName = currentClassPkg;
			
			% QUERY USER FOR FILES (IF NOT PROVIDED WITH INPUT)
			% 			checkCapabilitiesAndPreferences(obj)
			% 			checkFileInput(obj)
			% 			initialize(obj)
			if isempty(obj.FileDirectory)
				if obj.UseInteractive
					getFileInputInteractive(obj)
				end
			end
			checkFileInput(obj)
			
		end
	end
	
	
	% ##################################################
	% INTERNAL SYSTEM METHODS
	% ##################################################
	methods (Access = protected)	
		function resetImpl(obj)
			
			fprintf('TiffLoader Reset\n')
			
			% KEEP TRACK OF COMPLETED FRAMES
			obj.IsFinished = false;
			
			% INITIALIZE
			initialize(obj)
			
			% SET FRAME IDX TO LOAD IN FOLLOWING BUFFER
			if isempty(obj.NumFramesPerBufferBlock)
				obj.NumFramesPerBufferBlock = 8;
			end
			
			obj.NextFrameIdx = obj.StartFrameIdx;
			initializeBuffer(obj)
			obj.StartFrameIdx = 1;
			
			
			% TODO
			readyFcn(obj)
			
		end
		function releaseImpl(obj)
			fprintf('TiffLoader Release\n')
			obj.IsInitialized = false;
			
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
			% 			if obj.VideoStreamOutputPort
			% 				numOutputs = 1;
			% 			else
			numOutputs = nnz([...
				obj.VideoStreamOutputPort,...
				obj.FrameDataOutputPort,...
				obj.FrameTimeOutputPort,...
				obj.FrameInfoOutputPort,...
				obj.FrameIdxOutputPort]);
			% 			end
		end
		function numInputs = getNumInputsImpl(~)
			numInputs = 0;
		end
		function flag = isDoneImpl(obj)
			flag = obj.IsFinished;
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
			
			% 			nextFrameIdx = obj.NextFrameIdx;
			bufferIdx = obj.NextBufferIdx;
			% 			numPerBlock = obj.NumFramesPerBufferBlock;
			
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
				obj.IsFinished = false;
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
			
			% 			% DISPATCH REMOTE READ FUNCTION
			% 			if ~isempty(nextFrameIdx)
			% 				readFrameFcn = obj.ReadFrameFcn;
			% 				obj.ParallelFutureObj(bufferIdx) = parfeval( obj.ParallelPoolObj, readFrameFcn, 3, obj.StackInfo, nextFrameIdx);
			% 				obj.BufferedFrameIdx{bufferIdx,1} = nextFrameIdx;
			% 				nextFrameIdx = nextFrameIdx(end)+(1:numPerBlock);
			% 				nextFrameIdx = nextFrameIdx(nextFrameIdx <= obj.LastFrameIdx);
			% 			end
			% 			obj.NextFrameIdx = nextFrameIdx;
			% 			obj.NextBufferIdx = mod(bufferIdx, obj.NumBufferBlocks) + 1;
			%
			% 			% todo: notify
			%
		end
		function dispatchRemoteLoad(obj)
			% DISPATCH REMOTE READ FUNCTION
			nextFrameIdx = obj.NextFrameIdx;
			bufferIdx = obj.NextBufferIdx; % post-load (TODO) not updated above -> create a variable to signal buffer has been loaded and is ready for dispatch
			numPerBlock = obj.NumFramesPerBufferBlock;
			parallelPoolObj = obj.GlobalContextObj.ParallelPoolObj;
			
			if ~isempty(nextFrameIdx)
				readFrameFcn = obj.ReadFrameFcn;
				obj.ParallelFutureObj(bufferIdx) = parfeval( parallelPoolObj, readFrameFcn, 3, obj.StackInfo, nextFrameIdx);
				obj.BufferedFrameIdx{bufferIdx,1} = nextFrameIdx;
				nextFrameIdx = nextFrameIdx(end)+(1:numPerBlock);
				nextFrameIdx = nextFrameIdx(nextFrameIdx <= obj.LastFrameIdx);
			end
			obj.NextFrameIdx = nextFrameIdx;
			obj.NextBufferIdx = mod(bufferIdx, obj.NumBufferBlocks) + 1;
			
			
			
		end
		function closeTiffObj(obj)
			for n = 1:numel(obj.TiffObj)
				if ~isempty(obj.TiffObj(n)) && isvalid(obj.TiffObj(n))
					close(obj.TiffObj(n));
				end
			end
		end
		function varargout = makeTiffObj(obj)
			
			ignition.io.tiff.suppressTiffWarnings()
			
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
		function readyFcn(obj)
			schedule(obj.ReadTaskSchedulerObj); 
		end
	end
	
	methods (Hidden)
		function setStateFinished(obj)
			obj.IsFinished = true;
		end
		function setStatePreInitialized(obj)
			obj.IsInitialized = false;
		end
	end
	
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
	methods
		function initialize(obj)
			
			if obj.IsInitialized
				return
			end
			
			% START PARALLEL POOL
			% 			obj.initialize@ignition.core.Object(); % currently empty
			
			
			% IMPORT LOCAL NAMESPACE FOR EXTERNAL FUNCTIONS
			% 			import([obj.SubPackageName, '.*']);
			import ignition.io.tiff.*
			
			% SELECT/CHECK INPUT SPECIFICATIONS (File Names & Paths)
			checkFileInput(obj)
			
			% DEFINE DATA SET NAME
			if isempty(obj.DataSetName) && ~isempty(obj.FileDirectory)
				% TODO: move to external function that extracts from any single or stack of files				
				
				[~,dataLocationName] = fileparts(fileparts(obj.FileDirectory));
				
				if ischar(obj.FileName)
					dataSourceFileName = obj.FileName;
				elseif iscell(obj.FileName)
					if numel(obj.FileName) == 1
						dataSourceFileName = obj.FileName{1};
					elseif numel(obj.FileName) > 1
						[~, nameA, ~] = fileparts(obj.FileName{1});
						[~, nameB, ~] = fileparts(obj.FileName{end});
						nameLength = min(length(nameA),length(nameB));
						consistentNameParts = nameA(1:nameLength) == nameB(1:nameLength);
						inconsistentPart = find(~consistentNameParts);
						
						% TODO: a bit more complex, this only handles sequential numbering
						consistentFileName = [ nameA(1:inconsistentPart(end)) ,...
							' - ' , nameB(inconsistentPart) ,...
							nameB((inconsistentPart(end)+1):end) ];
						% 						consistentFileName = [ nameA(1:(inconsistentPart(1)-1)) ,...
						% 														' - ' , nameB(inconsistentPart) ,...
						% 														nameB((inconsistentPart(end)+1):end) ];
				
						dataSourceFileName = consistentFileName;
						
					end				
				end
				obj.DataSetName = ['[',dataLocationName,'] ', dataSourceFileName];
				
			end
			
			% 			obj.DataSetName = ['[',dataLocationName,'] ', dataSourceFileName];
			
			fprintf('[TiffFileInput] DataSetName: %s\n',obj.DataSetName)
			% 			fullFilePath = obj.FullFilePath(:);
			
			
			
			% DEFINE TAG PARSING FUNCTION (CUSTOM DEPENDING ON SOURCE)
			parseFrameInfoFcnHandle = str2func(obj.ParseFrameInfoFcnName);
			
			% CONSTRUCT LINKS TO TIFF FILES (MOVED FROM BELOW)
			allTiffObj = makeTiffObj(obj);
			
			% READ INITIAL TIFF-FILE INFO (FROM FIRST DIRECTORY)
			[stackInfo, fileInfo, ~] = initializeTiffStack(allTiffObj, parseFrameInfoFcnHandle);
			
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
			
			
			% 			% START PARALLEL POOL
			% 			obj.initialize@ignition.System()
			% 			makeEnvironmentConnections(obj)
			% 			if ~isempty(obj.ParallelPoolObj) && obj.ParallelPoolObj.Connected
			% 				obj.PoolTimeoutListener = addlistener(obj.ParallelPoolObj, 'ObjectBeingDestroyed', @(varargin) makeEnvironmentConnections(obj));
			% 				% todo: need to delete listener?
			% 			end
			
			
			% CHUNK/BUFFER OUTPUT
			% 			numFramesPerBufferBlock = obj.NumFramesPerBufferBlock;
			parallelPoolObj = obj.GlobalContextObj.ParallelPoolObj;
			if isempty(obj.NumBufferBlocks)
				obj.NumBufferBlocks = ceil(parallelPoolObj.NumWorkers/2);
			end
			
			% SET UNREAD & BUFFERED IDX LUTS
			obj.BufferedFrameIdx = cell(obj.NumBufferBlocks,1);
			obj.IsUnreadFrameIdx = true( size(obj.FrameIdxList));
			
			obj.IsInitialized = true;
			
			initializeBuffer(obj)%new
			
			% CREATE DELAYED TASK SCHEDULER
			loadFcn = @obj.dispatchRemoteLoad;			
			obj.ReadTaskSchedulerObj = ignition.internal.DeferredTask( loadFcn, 0); % obj.ReadTaskSchedulerObj = ignition.internal.DeferredTask();
			% 			schedule(obj.ReadTaskSchedulerObj, loadFcn, 0); % schedule(obj.ReadTaskSchedulerObj);
			
			% 			initializeBuffer(obj)%new
			
		end
		function varargout = run(obj)
			% StepImpl(obj) - Loads next available segment of video and dispatches another load operation
			try
				% 				notify(obj, 'Processing')
				% 				startTic = tic;
			
			% CHECK THAT PARALLEL POOL HASN'T SHUT DOWN AFTER TIMEOUT
			if (obj.UseParallel) && (~obj.GlobalContextObj.ParallelPoolObj.Connected)
				fprintf('TiffFileInput: pool disconnect (todo)\n')
				% 				obj.IsInitialized = false;
				% 				initialize(obj);
				%TODO: refresh(obj)?
				nextFirstIdx = obj.CurrentLoadedFrameIdx(end) + 1;
				release(obj)
				obj.StartFrameIdx = nextFirstIdx + 1;
				reset(obj)
				
			end
						
			
			% RETRIEVE DATA FROM PARALLEL PROCESS			
			[frameData, frameTime, frameInfo, frameIdx] = fillNextBufferBlock(obj);
			
			
			% STORE IN VIDEO-SEGMENT TYPE CLASS (CUSTOM)
			streamOut = ignition.core.type.VideoData(frameData, frameTime, frameInfo, frameIdx);
			
			% TODO: ADD VIDEO SEGMENT TO BUFFER... to combine?
			% bufferVideoStream(obj, vidSegment);
			
			if nargout
				% 				if obj.VideoStreamOutputPort
				% 					varargout = {vidSegment};
				%
				% 				else
				% RETURN VARIABLE OUTPUT ARGUMENTS
				requestedOutput = [...
					obj.VideoStreamOutputPort,...
					obj.FrameDataOutputPort,...
					obj.FrameTimeOutputPort,...
					obj.FrameInfoOutputPort,...
					obj.FrameIdxOutputPort
					];
				availableOutput = {streamOut, frameData, frameTime, frameInfo, frameIdx};
				varargout = availableOutput(requestedOutput);
				% 				end
			end
			
			% SCHEDULE NEXT LOAD (DELAYED DISPATCH) 
			reschedule(obj.ReadTaskSchedulerObj)
			% 			loadFcn = @obj.dispatchRemoteLoad;
			% 			ignition.internal.DeferredTask( loadFcn, 0);
			
					
			% POST-PROCEDURE TASKS
			% 			procTime = toc(startTic);
			% 			addBenchmark(obj.PerformanceMonitorObj, procTime, getNumFrames(vidSegment));
			%
			%
			% 				notify(obj, 'Finished')
				
			catch me
				handleError(obj, me)
			end
			
		end
	end
	methods (Hidden)
		function initializeBuffer(obj)
			% Creates the collection workers that read sequential blocks of frames from tiff files
			% asynchronously, beginning with the frame index specified in obj.NextFrameIdx. The collection
			% is implemented as an array of parallel.Future objects, which are replaced with new Future
			% objects in a circular fashion as each buffer is read out. This function is called during a
			% call to obj.reset(), and also called after a call to the function obj.setFrameIdx().
			
			% CANCEL & DELETE ANY CURRENTLY HELD BUFFER FUTURE OBJECTS
			bufferFuture = obj.ParallelFutureObj;
			if ~isempty(bufferFuture)
				% 				cancel(bufferFuture)
				try delete(bufferFuture), catch, end
			else
				bufferFuture = parallel.FevalFuture.empty;
			end
			
			
			% GET LOCAL VARIABLES FROM PROPS
			numBlocks = obj.NumBufferBlocks;
			numPerBlock = obj.NumFramesPerBufferBlock;
			bufferIdx = 0;
			stackInfo = obj.StackInfo;
			parallelPoolObj = obj.GlobalContextObj.ParallelPoolObj;
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
			
			% TODO: timed buffering from futures to client
			% = repmat({[ ]}, 1, numBlocks)
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
				% 				warning('TiffFileInput:getDataSample:SystemLocked',...
				% 					['The TiffFileInput is currently locked and is unable to return randomly sampled',...
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
			if ~obj.IsInitialized
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
			% 			lookupFileIdx = obj.LookupFileIdx;
			% 			lookupRelIdx = obj.LookupRelIdx;
			
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
				obj.IsFinished = false;
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
	methods
		function delete(obj)			
			if ~isempty(obj.ReadTaskSchedulerObj)
				try
					delete(obj.ReadTaskSchedulerObj);
				catch me
					handleError(obj, me)
				end
			end
		end
	end
	
	
	
	% ##################################################
	% PROPERTY-SET METHODS
	% ##################################################
	methods
		function set.FileName(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'TiffFileInput', 'FileName');
			if ischar(value)
				obj.FileName = {value};
			else
				obj.FileName = value;
			end
			setStatePreInitialized(obj)
		end
		function set.FileDirectory(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'TiffFileInput', 'FileDirectory');
			if ischar(value)
				obj.FileDirectory = value;
			else
				obj.FileDirectory = value{1};
			end
			setStatePreInitialized(obj)
		end
		function set.FullFilePath(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'TiffFileInput', 'FullFilePath');
			if ischar(value)
				obj.FullFilePath = {value};
			else
				obj.FullFilePath = value;
			end
			setStatePreInitialized(obj)
		end
	end
	
	
	
end




% function suppressTiffWarnings()
% 
% % SUPPRESS TIFFLIB WARNINGS
% warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
% warning('off','MATLAB:tifflib:TIFFReadDirectory:libraryWarning')
% warning('off','MATLAB:imagesci:Tiff:closingFileHandle')
% 
% end



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

