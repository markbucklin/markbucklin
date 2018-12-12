classdef (CaseInsensitiveProperties = true)  TiffStackLoaderAsync <  scicadelic.SciCaDelicSystem ...
		& matlab.system.mixin.FiniteSource
	% TiffStackLoaderAsync
	
	
	
	% SETTINGS
	properties (Nontunable)
		FileName
		FileDirectory
		FullFilePath
		ReadTimeStampFcn = @readHamamatsuTimeFromStart
		DataSetName = ''
		NumBuffers
		MaxLatency = 1
	end
	properties
		NumFramesPerBuffer = 16
		MaxFrameRate = 100		
	end
	properties (Constant, PositiveInteger)
		MinSampleNumber = 100
	end
	
	% OUTPUT SETTINGS
	properties (Nontunable, Logical)
		FrameDataOutputPort = false
		FrameInfoOutputPort = false
		FrameIdxOutputPort = false
	end
	
	% CURRENT STATE (Frame & File Index)
	properties (SetAccess = private) %(DiscreteState)
		CurrentFrameIdx
		NextFrameIdx
		CurrentFileIdx
		NextFileIdx		
		CurrentFileFirstFrameIdx
		CurrentFileLastFrameIdx		
		FrameCompletion
		FileCompletion
	end
	properties (SetAccess = private)
		InitializedFlag @logical scalar = false
		FinishedFlag @logical scalar = false
		IsLastFile = false;
	end
	
	% OUTPUT
	properties (SetAccess = private)
		FrameData
		FrameInfo
		FrameIdx
	end
	
	% TIFF FILE & FRAME INFO
	properties (SetAccess = private, Nontunable)
		TiffObj @Tiff vector
		FileInfo
		NumFiles
		NumFrames
		
		ReadableTagIDs
		FirstFrameTag
		LastFrameTag
	end
	
	% PARALLEL COMPUTING PROPS
	properties (SetAccess = private, Nontunable, Hidden)
		ParPoolObj
		ParFutureObj
		ParConstantObj
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = protected, Nontunable, Hidden)
		FileFrameIdx
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
		function obj = TiffStackLoaderAsync(varargin)
			% 			obj.UsePct = false;
			% 			obj.UseGpu = false;
			% 			obj.UseInteractive = true;
			% 			obj.UseBuffer = false;
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));
			obj.CanUseBuffer = true;
			obj.CanUseInteractive = true;
			setPrivateProps(obj);
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
			fprintf('TiffLoader Reset\n')
			
			if ~obj.InitializedFlag
				initialize(obj)
			else
				makeTiffObj(obj)
			end
			
			% ALWAYS HAPPENS IN RESET ???
			setCurrentFrame(obj, 1);
			
			setPrivateProps(obj);
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function varargout = stepImpl(obj)
			
			numArgsOut = nargout;
			numOutputs = getNumOutputsImpl(obj);
			argsOut = cell(numOutputs,1);			
			[argsOut{:}] = outputImpl(obj);
			varargout = argsOut(1:min(numOutputs,numArgsOut));			
			
		end
		function varargout = outputImpl(obj)
			
			% LOAD FRAME/FRAMES
% 			[data, info, idx] = readNext(obj);
			
			% UPDATE COMPLETION STATUS
			% 			obj.FrameCompletion(idx) = true;
			
			
			% ASSIGN OUTPUT TO PROPERTIES			
			% 			obj.FrameData = data;
			% 			obj.FrameIdx = idx;			
			% 			obj.FrameInfo = info;			
			% 			availableOutput = {obj.FrameData, obj.FrameInfo, obj.FrameIdx};			
			
			% RETURN VARIABLE OUTPUT ARGUMENTS
			if nargout
				requestedOutput = [...
					obj.FrameDataOutputPort,...
					obj.FrameInfoOutputPort,...
					obj.FrameIdxOutputPort];
					availableOutput = {data, info, idx};				
				varargout = availableOutput(requestedOutput);
			end
			
			if (obj.CurrentFrameIdx >= obj.NumFrames)
				finishedFcn(obj)
			end
			
		end
		
		
		% outputImpl(obj)
		
		% ============================================================
		% I/O & RESET
		% ============================================================
		function numOutputs = getNumOutputsImpl(obj)
			numOutputs = nnz([...
				obj.FrameDataOutputPort,...
				obj.FrameInfoOutputPort,...
				obj.FrameIdxOutputPort]);
		end
		function numInputs = getNumInputsImpl(obj)
			numInputs = 0;
		end
		function resetImpl(obj)
			
			fprintf('TiffLoader Reset\n')
			% INITIALIZE/RESET ALL DESCRETE-STATE PROPERTIES
			dStates = obj.getDiscreteState;
			fn = fields(dStates);
			for m = 1:numel(fn)
				dStates.(fn{m}) = [];
			end
			makeTiffObj(obj)
			
			% KEEP TRACK OF COMPLETED FRAMES
			obj.FrameCompletion = false(obj.NumFrames,1);
			obj.FinishedFlag = false;
			setPrivateProps(obj)
			
			% SET FRAME TO LOAD IN FIRST BUFFER
			setCurrentFrame(obj, 1)
			
			% SET FRAME IDX TO LOAD IN FOLLOWING BUFFER
			if isempty(obj.NumFramesPerBuffer)
				obj.NumFramesPerBuffer = 1;
			end
			setNextFrame(obj, 1 + obj.NumFramesPerBuffer)
			
			% SET-FRAME-IDX METHODS WILL ALSO UPDATE CURRENT & NEXT FILE-IDX
			
		end
		function releaseImpl(obj)
			% CLEAR TIFF OBJECT
			if ~isempty(obj.TiffObj)
				closeTiffObj(obj);
			end
			fetchPropsFromGpu(obj)
			% 			obj.InitializedFlag = false;
		end
		function flag = isDoneImpl(obj)
			flag = obj.FinishedFlag;
			% 		 bDone = all(obj.FileCompletion);
		end
		function s = saveObjectImpl(obj)
			s = saveObjectImpl@matlab.System(obj);
			if isLocked(obj)
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				for k=1:numel(oProps)
					s.(oProps(k).Name) = obj.(oProps(k).Name);
				end
			end
		end
		function loadObjectImpl(obj,s,wasLocked)
			if wasLocked
				% 				oMeta = metaclass(obj);
				% 				oProps = oMeta.PropertyList(:);
				% 				propSettable = ~[oProps.Dependent] & ~[oProps.Constant];
				sFields = fields(s);
				for k=1:numel(sFields)
					
					obj.(sFields{k}) = s.(sFields{k});
				end
			end
			% Call base class method to load public properties
			loadObjectImpl@matlab.System(obj,s,[]);
		end
	end
	
	% ##################################################
	% RUN-TIME HELPER FUNCTIONS
	% ##################################################
	methods (Access = protected, Hidden)
		function closeTiffObj(obj)
			for n = 1:numel(obj.TiffObj)
				if ~isempty(obj.TiffObj(n)) && isvalid(obj.TiffObj(n))
					close(obj.TiffObj(n));
				end
			end
		end
		function makeTiffObj(obj)
			warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
			warning off MATLAB:tifflib:TIFFReadDirectory:libraryWarning
			for n = 1:numel(obj.FullFilePath)
				tiffFileName = obj.FullFilePath{n};
				obj.TiffObj(n) = Tiff(tiffFileName,'r');
			end
		end
		function setCurrentFile(obj, n)
			% Sets current file to input N, and sets the current directory of that file to 1
			if n > numel(obj.TiffObj)
				finishedFcn(obj)
			else
				obj.CurrentFileFirstFrameIdx = obj.FileFrameIdx.first(n);
				obj.CurrentFileLastFrameIdx = obj.FileFrameIdx.last(n);
				obj.CurrentFrameIdx = obj.CurrentFileFirstFrameIdx;				
				obj.CurrentFileIdx = n;
				
				% NEW
				% 				try
				% 					currentFileCurrentDirectory = currentDirectory(obj.TiffObj(n));
				% 				catch me
				% 					getReport(me)
				% 					makeTiffObj(obj)
				% 					currentFileCurrentDirectory = currentDirectory(obj.TiffObj(n));
				% 				end
				% 				if currentFileCurrentDirectory ~= 1
				% 					setDirectory(obj.TiffObj(n), 1)
				% 				end
				
				
				% NEW
				setNextFile(obj, n + 1);
				
			end
		end
		function setCurrentFrame(obj, frameIdx)
			% Sets the CurrentFrameIdx property to 'frameIdx', specifying the next frame to read
			if frameIdx > obj.NumFrames
				warning('scicadelic:TiffStackLoaderAsync:setCurrentFrame',...
					'Requested frame exceeds last index of last file')
				% 				frameIdx = obj.NumFrames + 1;
			end				
			fileIdx = getFileIdx(obj, frameIdx);
			setCurrentFile(obj, fileIdx);
			obj.CurrentFrameIdx = frameIdx;
			obj.CurrentSubFrameIdx = frameIdx - obj.CurrentFileFirstFrameIdx + 1;
		end
		function setNextFile(obj, n)
			% Sets next/queued file to input N, and sets the current directory of that file to 1						
			if n > numel(obj.TiffObj)
				obj.IsLastFile = true;
				obj.NextFileIdx = [];
				
			else
				obj.IsLastFile = false;
				obj.NextFileIdx = n;
				
			end
		end
		function finishedFcn(obj)
			obj.FinishedFlag = true;
		end
		function fileIdx = getFileIdx(obj, frameIdx)
			if ~isempty(obj.FileFrameIdx)
				fileIdx = find((frameIdx >= obj.FileFrameIdx.first) & (frameIdx < obj.FileFrameIdx.last));
			else
				fileIdx = 1;
			end
		end
	end
	
	
	
	% ##################################################
	% TUNING
	% ##################################################
	methods (Hidden)
		function tuneInteractive(~)
		end
		function tuneAutomated(~)
		end
	end
	
	
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
	methods
		function initialize(obj)
			% CHECK INPUT SPECIFICATIONS (File Names & Paths)
			if isempty(obj.DataSetName) && ~isempty(obj.FileDirectory)
				[~,obj.DataSetName] = fileparts(fileparts(obj.FileDirectory));
			end
			checkFileInput(obj)			
			numFiles = obj.NumFiles;
			
			% START PARALLEL POOL
			if obj.UsePct % && numFiles>4 %NEW: TODO
				pool = gcp('nocreate');
				if isempty(pool)
					numCores = str2double(getenv('NUMBER_OF_PROCESSORS'));
					pool = parpool(numCores);
					% 					poolSize = min(N, numCores);
					% 					pool = parpool(poolSize);
				end
				obj.ParPoolObj = pool;
			end
			
			% CONSTRUCT LINKS TO TIFF FILES (MOVED FROM BELOW)
			makeTiffObj(obj);
			
			% READ INITIAL TIFF-FILE INFO (FROM FIRST DIRECTORY)
			readTiffFileInfo(obj)
						
			% CHUNK/BUFFER OUTPUT
			% 			updateNumChunkedSteps(obj)
			% 			estimateSuitableChunkSize(obj)
			M = obj.NumFramesPerBuffer;
			
			% 				frameData = zeros([obj.FrameSize M], obj.OutputDataType);			
			% 			obj.FrameData = frameData;
			% 			obj.FrameInfo = obj.CachedFrameInfo(1);			
			% 			obj.FrameIdx = NaN(M,1);
			% 			obj.NumFrames = obj.FileFrameIdx.last(end); % TODO: NFrames is defined in parent function... can't be made nontunable?
			
			% RESET INITIAL COMPLETION COUNTERS
			obj.FrameCompletion = false(obj.NumFrames,1);
			obj.FileCompletion = zeros(obj.NumFiles,1);
			
			
			% 			% CONSTRUCT LINKS TO TIFF FILES
			% 			makeTiffObj(obj);
			
			setPrivateProps(obj)
			obj.InitializedFlag = true;
		end
		function getFileInputInteractive(obj)
			[fname,fdir] = uigetfile('*.tif','MultiSelect','on');
			updateFullFilePathFromNameDir(obj,fname,fdir)
			obj.FileDirectory = fdir;
			obj.FileName = fname;
			checkFileInput(obj)
		end
		function checkFileInput(obj)
			try
				% 				if isempty(obj.FullFilePath)
				% 					getFileInputInteractive(obj)
				% 					return
				% 				end
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
				getReport(me)
				if obj.UseInteractive
					getFileInputInteractive(obj)
				else
					rethrow(me)
				end
			end
		end
		function readTiffFileInfo(obj)
			% Uses INFINFO to read basic image information from Tiff files
			
			numFiles = obj.NumFiles;
			allFileInfo = struct(...
				'fileName',obj.FileName(:),...				
				'nFrames',repmat({0},numFiles,1),...
				'frameSize',repmat({[NaN NaN]},numFiles,1),...
				'firstIdx',repmat({[NaN]},numFiles,1),...
				'lastIdx',repmat({[NaN]},numFiles,1));
			
			
			firstTiffObj = obj.TiffObj(1);
			allTiffTagIDs = Tiff.TagID;
			tagFields = fields(allTiffTagIDs);
			numTagFields = numel(tagFields);
			isTagReadable = true(numTagFields,1);
			for tagIdx = 1:numTagFields
				try
					tagName = tagFields{tagIdx};
					tagID = allTiffTagIDs.(tagName);
					readableTiffTags.(tagName) = firstTiffObj.getTag( tagID );
					readableTagIDs.(tagName) = tagID;
				catch me
					isTagReadable(tagIdx) = false;
				end
			end
			readableTagFields = tagFields(isTagReadable);
			obj.ReadableTagIDs = readableTagIDs;
			obj.FirstFrameTag = readableTiffTags;
			numReadableTagFields = sum(isTagReadable);
			
			numCols = readableTiffTags.ImageWidth;
			numRows = readableTiffTags.ImageLength;
			
			for n = 1:numFiles
				allFileInfo(n).fileName = obj.FileName{n};
				% 				imDescription = tiffObj.getTag(Tiff.TagID.ImageDescription);
				
				
				%%%%%%%%%%%%%
				
				
				% 				allFileInfo(n).firstFrameTiffTags = imfinfo(obj.FullFilePath{n});
				tiffObj = obj.TiffObj(n);				
				
				% GET NUMBER OF FRAMES IN CURRENT FILE
				frameCounter = currentDirectory(tiffObj);
				countIncrement = 64;
				while ~lastDirectory(tiffObj)
					stridedFrameCounter = frameCounter + countIncrement;
					try
						setDirectory(tiffObj, stridedFrameCounter);
						frameCounter = stridedFrameCounter;
					catch
						countIncrement = max(1, floor(countIncrement/2));
					end
				end
				allFileInfo(n).nFrames = currentDirectory(tiffObj);
				
				% CHECK IF THIS IS THE LAST TIFF FILE
				if (n == numFiles)					
					for rtIdx = 1:numReadableTagFields
						rtagName = readableTagFields{rtIdx};
						rtagID = readableTagIDs.(rtagName);
						lastFrameTag.(rtagName) = tiffObj.getTag( rtagID);
					end
					obj.LastFrameTag = lastFrameTag;
				end
				
				% RESET DIRECTORY OR CLOSE FILE DOWN
				setDirectory(tiffObj, 1);
				% close tiffObj if parallel
				
				% GET DIMENSIONS
				allFileInfo(n).frameSize = [numRows numCols];
				
			end
			
			% GET NUM-CHANNELS & BIT-DEPTH
			numChannels = readableTiffTags.ImageDepth;
			numBits = readableTiffTags.BitsPerSample;
			obj.FrameSize = [numRows, numCols numChannels];
			
			
			obj.NumFrames = sum([allFileInfo(:).nFrames]);
			lastFrameIdx = cumsum([allFileInfo(:).nFrames]);
			obj.FileFrameIdx(1).first = [0 lastFrameIdx(1:end-1)]+1;
			obj.FileFrameIdx(1).last = lastFrameIdx;
			
			for n = 1:numFiles				
				allFileInfo(n).firstIdx = obj.FileFrameIdx.first(n);
				allFileInfo(n).lastIdx = obj.FileFrameIdx.last(n);
			end
			
			obj.FileInfo = allFileInfo;
			
			
			switch numBits
				case 16
					obj.InputDataType = 'uint16';
				case 8
					obj.InputDataType = 'uint8';
				otherwise
					obj.InputDataType = 'single';
			end
			obj.OutputDataType = obj.InputDataType;
			
			
			
			
		end
		function estimateSuitableChunkSize(obj)
			if obj.UseGpu
				dev = gpuDevice;
				numPixels = prod(obj.FrameSize);
				obj.NumFramesPerBuffer = 2^(nextpow2(round(dev.AvailableMemory/numPixels/64))-2); %TODO;
			elseif obj.UsePct
				if isempty(obj.ParPoolObj)
					obj.ParPoolObj = gcp('nocreate');
				end
				if ~isempty(obj.ParPoolObj)
					numWorkers = obj.ParPoolObj.NumWorkers;
					obj.NumFramesPerBuffer = numWorkers;
				else
					obj.NumFramesPerBuffer = 1;
				end
			else
				obj.NumFramesPerBuffer = 1;
			end
		end
		function updateNumChunkedSteps(obj)
			idx = 0;
			m = 0;
			numFramesPerBuf = obj.NumFramesPerBuffer;			
			if isempty(numFramesPerBuf)
				estimateSuitableChunkSize(obj)
				numFramesPerBuf = obj.NumFramesPerBuffer;
			end
			
			numRemain = getNumFramesRemaining(obj);
			numSteps = ceil(numRemain/numFramesPerBuf);
			
			% 			obj.NumSteps = numSteps;
			
		end
		function numRemain = getNumFramesRemaining(obj)
			if ~isDone(obj)
				numTotalFrames = obj.NumFrames;
				currentFrameIdx = obj.CurrentFrameIdx;
				numRemain = numTotalFrames - currentFrameIdx + 1;
			else
				numRemaim = 0;
			end
			
		end
		function initializeParallelWorkers(obj)
			
			
			% 			obj.ParConstantObj
		end
		function [data, varargout] = getDataSample(obj, nSampleFrames)
			
			if isLocked(obj)
				% ------------------------------------------
				% RETURN CURRENTLY BUFFERED DATA (IF LOCKED)
				% ------------------------------------------
				% 				warning('TiffStackLoaderAsync:getDataSample:SystemLocked',...
				% 					['The TiffStackLoaderAsync is currently locked and is unable to return randomly sampled',...
				% 					'data. Data from current buffer will be returned instead. For a random data sample',...
				% 					'you must first call release(), then call getDataSample() again.'])
				% 				data = obj.FrameData;
				% 				info = obj.FrameInfo;
				% 				sampleFrameIdx = obj.FrameIdx;
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
				nSampleFrames = min(N, obj.MinSampleNumber);
			end
			
			if isscalar(nSampleFrames)
				% GENERATE RANDOMLY SPACED FRAME INDICES TO SAMPLE
				jitter = floor(N/nSampleFrames);
				sampleFrameIdx = round(linspace(1, N-jitter, nSampleFrames)')...
					+ round( jitter*rand(nSampleFrames,1));
				
			else
				% USE SPECIFIC FRAME INDICES FROM VECTOR INPUT
				sampleFrameIdx = nSampleFrames;
				nSampleFrames = numel(sampleFrameIdx);
				
			end
			
			% LOAD FRAMES
			
			% TODO: LOAD WITH ASYNC FUNCTION
			data(:,:,nSampleFrames) = zeros(obj.FrameSize, obj.InputDataType);
			currentIdx = obj.CurrentFrameIdx;
			for k=1:nSampleFrames
				setCurrentFrame(obj, sampleFrameIdx(k));
				fileIdx = obj.CurrentFileIdx;
				setDirectory(obj.TiffObj(fileIdx), obj.CurrentSubFrameIdx) % Unnecessary???
				data(:,:,k) = read(obj.TiffObj(fileIdx));
			end
			if ~isempty(currentIdx)
				setCurrentFrame(obj, currentIdx);
			end
			
			% RETURN FRAME IDX IF 2ND OUTPUT REQUESTED
			if nargout > 1
				varargout{1} = sampleFrameIdx;
			end
			
		end
	end
	methods (Access = protected, Hidden)
		function setPreInitializedState(obj)
			obj.InitializedFlag = false;
		end
		function flag = isInitialized(obj)
			flag = obj.InitializedFlag;
		end
	end
	methods
		function updateFullFilePathFromNameDir(obj,fname,fdir)
			switch class(fname)
				case 'char'
					obj.FullFilePath{1} = [fdir,fname];
				case 'cell'
					for n = numel(fname):-1:1
						% 						obj.FullFilePath{n} = [fdir,fname{n}];
						obj.FullFilePath{n} = fullfile(fdir,fname{n});
					end
			end
		end
	end
	
	
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
	methods (Access = protected, Hidden)
		function setPrivateProps(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			for k=1:numel(oProps)
				prop = oProps(k);
				if prop.Name(1) == 'p'
					pname = prop.Name(2:end);
					try
						pval = obj.(pname);
						obj.(prop.Name) = pval;
					catch me
						getReport(me)
					end
				end
			end
		end
		function fetchPropsFromGpu(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			propSettable = ~[oProps.Dependent] & ~[oProps.Constant];
			for k=1:length(propSettable)
				if propSettable(k)
					pn = oProps(k).Name;
					try
						if isa(obj.(pn), 'gpuArray') && existsOnGPU(obj.(pn))
							obj.(pn) = gather(obj.(pn));
							obj.GpuRetrievedProps.(pn) = obj.(pn);
						end
					catch me
						getReport(me)
					end
				end
			end
		end
		function pushGpuPropsBack(obj)
			fn = fields(obj.GpuRetrievedProps);
			for kf = 1:numel(fn)
				pn = fn{kf};
				if isprop(obj, pn)
					if obj.UseGpu
						obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
					else
						obj.(pn) = obj.GpuRetrievedProps.(pn);
					end
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
				'TiffStackLoaderAsync', 'FileName');
			if ischar(value)
				obj.FileName = {value};
			else
				obj.FileName = value;
			end
			setPreInitializedState(obj)
		end
		function set.FileDirectory(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'TiffStackLoaderAsync', 'FileDirectory');
			if ischar(value)
				obj.FileDirectory = value;
			else
				obj.FileDirectory = value{1};
			end
			setPreInitializedState(obj)
		end
		function set.FullFilePath(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'TiffStackLoaderAsync', 'FullFilePath');
			if ischar(value)
				obj.FullFilePath = {value};
			else
				obj.FullFilePath = value;
			end
			setPreInitializedState(obj)
		end
	end
	
	
	
end








% 	  function [data, info] = tiffStackLoadNextBuffered(obj)
% 		 % 		 if isempty(obj.BufferedData) % 			obj.BufferedData = zeros([obj.FrameSize,
% 		 obj.nFrames], obj.OutputDataType); % 			obj.BufferedIdx = 0; % 		 end %
% 		 firstIdx = obj.CurrentFrameIdx; % 		 if firstIdx > obj.BufferedIdx % 		 end %
% 		 lastIdx = firstIdx + obj.bufferSize -1; % 		 fn = fields(obj.AllFrameInfo); % 		 for
% 		 kfn=1:numel(fn) % 			info.(fn{kfn}) = obj.AllFrameInfo.(fn{kfn})(firstIdx); % 		 end
% 		 % 		 data = read(obj.TiffObj(obj.CurrentFileIdx)); % 		 if
% 		 obj.TiffObj(obj.CurrentFileIdx).lastDirectory(); % 			setCurrentFile(obj,
% 		 obj.CurrentFileIdx + 1) % 		 else %
% 		 obj.TiffObj(obj.CurrentFileIdx).nextDirectory(); % 			obj.CurrentSubFrameIdx =
% 		 obj.CurrentSubFrameIdx + 1; % 			obj.CurrentFrameIdx = obj.CurrentFrameIdx + 1; %
% 		 end
% 	  end