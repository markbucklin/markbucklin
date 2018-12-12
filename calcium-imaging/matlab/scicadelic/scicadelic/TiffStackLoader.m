classdef (CaseInsensitiveProperties = true)  TiffStackLoader <  scicadelic.SciCaDelicSystem ...
		& matlab.system.mixin.FiniteSource
	% TiffStackLoader
	
	
	
	% SETTINGS
	properties (Nontunable)
		FileName
		FileDirectory
		FullFilePath
		ReadTimeStampFcn = @getHamamatsuTimeStampSeconds
		DataSetName = ''
		FramesPerStep
	end
	properties (Constant, PositiveInteger)
		MinSampleNumber = 100
	end
	% OUTPUT SETTINGS
	properties (Nontunable, Logical)
		FrameDataOutputPort = true
		FrameInfoOutputPort = false
		FrameIdxOutputPort = true
	end
	
	% CURRENT STATE (Frame & File Index)
	properties (SetAccess = private) %(DiscreteState)
		CurrentFrameIdx
		CurrentSubFrameIdx
		CurrentFileIdx
		CurrentFileFirstFrameIdx
		CurrentFileLastFrameIdx
		CurrentStepCount
	end
	properties (SetAccess = private)
		InitializedFlag @logical scalar = false
		FinishedFlag @logical scalar = false
	end
	
	% OUTPUT
	properties (SetAccess = private)
		FrameData
		FrameInfo @struct
		FrameIdx
		FrameCompletion @logical vector % TODO
		FileCompletion @double vector % TODO
	end
	
	% TIFF FILE & FRAME INFO
	properties (SetAccess = private, Nontunable)
		TiffObj @Tiff vector
		TiffInfo @struct vector
		NumFiles @double scalar = 0
		NumSteps
		NumFrames
		AllFrameInfo @struct
		CachedFrameInfo @struct
		FileFrameIdx @struct
	end
	
	% PARALLEL COMPUTING PROPS
	properties (SetAccess = private, Nontunable, Hidden)
		ParPool
	end
	
	% PRIVATE COPIES
	properties (SetAccess = protected, Hidden)
	end
	
	
	
	% TODO: EVENTS
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = TiffStackLoader(varargin)
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
			if ~obj.InitializedFlag
				initialize(obj)
			else
				makeTiffObj(obj)
				cacheChunkedFrameInfo(obj)
			end
			
			obj.CurrentStepCount = 0;
			
			% ENSURE ALL TIFF FILES ARE PREPARED TO LOAD FIRST FRAME IN FILE
			for n=1:numel(obj.TiffObj)
				setDirectory(obj.TiffObj(n), 1)
			end
			setCurrentFile(obj, 1);%find(obj.FrameCompletion, 1, 'last')
			
			setPrivateProps(obj);
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function varargout = stepImpl(obj)
			
			% LOAD FRAME/FRAMES
			[data, info, idx] = readNext(obj);
			
			% UPDATE COMPLETION STATUS
			obj.FrameCompletion(idx) = true;
			obj.CurrentStepCount = obj.CurrentStepCount + 1;
			
			% ASSIGN OUTPUT TO PROPERTIES
			% 			if obj.pUseGpu
			% 				data = gpuArray(data);
			% 			end
			% 			if obj.pUseGpu
			% 				obj.FrameData = gpuArray(data);
			% 				obj.FrameIdx = gpuArray(idx);
			% 				% 				idx = gpuArray(idx);
			% 			else
			% 				obj.FrameData = data;
			% 				obj.FrameIdx = idx;
			% 			end
			% 			obj.FrameInfo = info;
			% 			obj.FrameData = data; % NEW -> MAY SPEED UP IF WE REMOVE?
			% 			if ~obj.FrameDataOutputPort || (nargout < 1)
			% 			obj.FrameData = data;
			% 			end
			% 			obj.FrameInfo = info;
			% 			obj.FrameIdx = idx;
			
			% RETURN VARIABLE OUTPUT ARGUMENTS
			if nargout
				requestedOutput = [...
					obj.FrameDataOutputPort,...
					obj.FrameInfoOutputPort,...
					obj.FrameIdxOutputPort];
				% 				availableOutput = {obj.FrameData, obj.FrameInfo, obj.FrameIdx};
				if obj.pUseGpu
					availableOutput = {gpuArray(data), info, idx};
				else
					availableOutput = {data, info, idx};
				end
				varargout = availableOutput(requestedOutput);
			end
			
			if (obj.CurrentStepCount >= obj.NumSteps) || (idx(end) >= obj.NumFrames)
				finishedFcn(obj)
			end
			
		end
		
		% ============================================================
		% I/O & RESET
		% ============================================================
		function numOutputs = getNumOutputsImpl(obj)
			numOutputs = nnz([...
				obj.FrameDataOutputPort,...
				obj.FrameInfoOutputPort,...
				obj.FrameIdxOutputPort]);
		end
		function resetImpl(obj)
			% INITIALIZE/RESET ALL DESCRETE-STATE PROPERTIES
			dStates = obj.getDiscreteState;
			fn = fields(dStates);
			for m = 1:numel(fn)
				dStates.(fn{m}) = [];
			end
			makeTiffObj(obj)
			cacheChunkedFrameInfo(obj)
			
			% KEEP TRACK OF COMPLETED FRAMES
			obj.FrameCompletion = false(obj.NumFrames,1);
			obj.FinishedFlag = false;
			setPrivateProps(obj)
			setCurrentFile(obj, 1)
			setCurrentFrame(obj, 1)
			obj.CurrentStepCount = 0;
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
				obj.CurrentSubFrameIdx = 1;
				obj.CurrentFileIdx = n;
				
				% NEW
				try
					currentFileCurrentDirectory = currentDirectory(obj.TiffObj(n));
				catch me
					getReport(me)
					makeTiffObj(obj)
					currentFileCurrentDirectory = currentDirectory(obj.TiffObj(n));
				end
				if currentFileCurrentDirectory ~= 1
					setDirectory(obj.TiffObj(n), 1)
				end
				% NEW
			end
		end
		function setCurrentFrame(obj, k)
			if k > obj.FileFrameIdx.last(end)
				error('scicadelic:TiffStackLoader:setCurrentFrame',...
					'Requested frame exceeds last index of last file')
			end
			try
				fileIdx = find((k >= obj.FileFrameIdx.first) & (k < obj.FileFrameIdx.last));
			catch me
				msg = getReport(me);
			end
			setCurrentFile(obj, fileIdx)
			obj.CurrentFrameIdx = k;
			obj.CurrentSubFrameIdx = k - obj.CurrentFileFirstFrameIdx + 1;
		end
		function finishedFcn(obj)
			obj.FinishedFlag = true;
		end
	end
	methods (Access = protected, Hidden)
		function [data, info, frameIdx] = readNext(obj)
			
			% LOCAL VARIABLES
			m = obj.CurrentStepCount + 1;
			usingNextFileFlag = false;
			
			% INDICES FROM CACHE
			info = obj.CachedFrameInfo(m);
			frameIdx = info.frameidx;
			subFrameIdx = info.subframeidx;
			fileIdx = info.fileidx;
			
			% CHECK THAT CURRENT DIRECTORY ALIGNS WITH CURRENT (first) FRAME (via sub-frame-index)
			if subFrameIdx(1) ~= currentDirectory(obj.TiffObj(fileIdx(1)))
				setDirectory(obj.TiffObj(fileIdx(1)), subFrameIdx(1))
			end
			
			% PREALLOCATE DATA
			K = numel(frameIdx);
			% 			data = zeros([obj.FrameSize K], obj.InputDataType);
			dataCell = cell(1,K);
			
			
			% LOOP THROUGH LOADING PROCEDURE (READ-NEXT)
			for k = 1:K
				
				% READ FRAME
				dataCell{1,k} = read(obj.TiffObj(fileIdx(k)));
				
				
				% 				data(:,:,k) = read(obj.TiffObj(fileIdx(k)));
				
				% INCREMENT FRAME (directory) OR FILE
				if ~obj.TiffObj(fileIdx(k)).lastDirectory()
					obj.TiffObj(fileIdx(k)).nextDirectory();
				else
					setCurrentFile(obj, fileIdx(k)+1);
					usingNextFileFlag = true;
				end
			end
			
			% UPDATE CURRENT INDEX STATES
			obj.CurrentFrameIdx = frameIdx(end) + 1;
			if usingNextFileFlag && ~obj.FinishedFlag
				obj.CurrentSubFrameIdx = currentDirectory(obj.TiffObj(obj.CurrentFileIdx));
			else
				obj.CurrentSubFrameIdx = subFrameIdx(end) + 1;
			end
			
			data = cat(3, dataCell{:});
			
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
			fillDefaults(obj)
			if ~isempty(obj.GpuRetrievedProps) % NEW
				pushGpuPropsBack(obj)
			end
			N = obj.NumFiles;
			
			% START PARALLEL POOL
			if obj.UsePct && N>4 %NEW: TODO
				pool = gcp('nocreate');
				if isempty(pool)
					numCores = str2double(getenv('NUMBER_OF_PROCESSORS'));
					poolSize = min(N, numCores);
					pool = parpool(poolSize);
				end
				obj.ParPool = pool;
			end
			
			% CONSTRUCT LINKS TO TIFF FILES (MOVED FROM BELOW)
			makeTiffObj(obj);
			
			% CACHE TIFF-FILE INFO
			readTiffFileInfo(obj)
			cacheAllFrameInfo(obj)
			cacheChunkedFrameInfo(obj)
			
			% CHUNK/BUFFER OUTPUT
			M = obj.FramesPerStep;
			% 			if obj.UseGpu
			% 				frameData = gpuArray.zeros([obj.FrameSize M], obj.OutputDataType);
			% 			else
			% 				frameData = zeros([obj.FrameSize M], obj.OutputDataType);
			% 			end
			% 			obj.FrameData = frameData;
			obj.FrameInfo = obj.CachedFrameInfo(1);
			obj.FrameIdx = NaN(M,1);
			obj.NumFrames = obj.FileFrameIdx.last(end); % TODO: NFrames is defined in parent function... can't be made nontunable?
			
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
			
			N = obj.NumFiles;
			% 			if obj.UsePct && N>1
			% 				fn = obj.FileName;
			% 				ffp = obj.FullFilePath;
			% 				tinfoCell = cell.empty(N,0); %struct.empty(N,0);
			% 				spmd %TODO
			% 					n = labindex;
			% 					for k=1:N
			% 						if k==n
			% 							fnLoc = fn{k};
			% 							ffpLoc = ffp{k};
			% 							tinfo.fileName = fnLoc;
			% 							tifftags = imfinfo(ffpLoc);
			% 							tinfo.tiffTags = tifftags;
			% 							tinfo.nFrames = numel(tifftags);
			% 							tinfo.frameSize = [tifftags(1).Height tifftags(1).Width];
			% 							tinfoCell{k,1} = tinfo;
			% 						end
			% 					end
			% 					% 				parfor n = 1:N
			% 					% 					tinfo(n,1).fileName = fn{n};
			% 					% 					tifftags = imfinfo(ffp{n});
			% 					% 					tinfo(n,1).tiffTags = tifftags;
			% 					% 					tinfo(n,1).nFrames = numel(tifftags);
			% 					% 					tinfo(n,1).frameSize = [tifftags(1).Height tifftags(1).Width];
			% 				end
			% 				tinfod = gather(cat(1,tinfoCell{1:N}));
			% 				obj.TiffInfo = cat(1,tinfod{~cellfun(@isempty,tinfod)}); %gather(tinfo);
			% 			else
			obj.TiffInfo = struct(...
				'fileName',obj.FileName(:),...
				'tiffTags',repmat({struct.empty(0,1)},obj.NumFiles,1),...
				'nFrames',repmat({0},obj.NumFiles,1),...
				'frameSize',repmat({[NaN NaN]},obj.NumFiles,1));
			for n = 1:N
				obj.TiffInfo(n).fileName = obj.FileName{n};
				
				
				% 				imDescription = tiffObj.getTag(Tiff.TagID.ImageDescription);
				obj.TiffInfo(n).tiffTags = imfinfo(obj.FullFilePath{n});
				
				
				
				
				obj.TiffInfo(n).nFrames = numel(obj.TiffInfo(n).tiffTags);
				obj.TiffInfo(n).frameSize = [obj.TiffInfo(n).tiffTags(1).Height obj.TiffInfo(n).tiffTags(1).Width];
			end
			% tiffObj = obj.TiffObj
			% width = tiffObj.getTag(Tiff.TagID.ImageWidth);
			% height = tiffObj.getTag(Tiff.TagID.ImageLength);
			% 			imDescription = tiffObj.getTag(Tiff.TagID.ImageDescription);
			
			
			% 			end
			% 			obj.NFrames = sum([obj.TiffInfo(:).nFrames]);
			obj.NumFrames = sum([obj.TiffInfo(:).nFrames]);
			lastFrameIdx = cumsum([obj.TiffInfo(:).nFrames]);
			obj.FileFrameIdx(1).first = [0 lastFrameIdx(1:end-1)]+1;
			obj.FileFrameIdx(1).last = lastFrameIdx;
			for n = 1:N
				obj.TiffInfo(n).firstIdx = obj.FileFrameIdx.first(n);
				obj.TiffInfo(n).lastIdx = obj.FileFrameIdx.last(n);
			end
			switch obj.TiffInfo(1).tiffTags(1).BitDepth
				case 16
					obj.InputDataType = 'uint16';
				case 8
					obj.InputDataType = 'uint8';
				otherwise
					obj.InputDataType = 'single';
			end
			obj.OutputDataType = obj.InputDataType;
			obj.FrameSize = obj.TiffInfo(1).frameSize;
		end
		function cacheAllFrameInfo(obj)
			% PREALLOCATE STRUCTURE FOR FRAME INFO -> CACHE
			N = obj.NumFrames;
			obj.AllFrameInfo = struct(...
				'frameidx',zeros(N,1),...
				'subframeidx',zeros(N,1),...
				'fileidx',zeros(N,1),...
				't',zeros(N,1));
			tryCustomTimeStampFcn = ~isempty(obj.ReadTimeStampFcn) ...
				&& isa(obj.ReadTimeStampFcn, 'function_handle');
			if obj.UsePct && obj.NumFiles>4
				if tryCustomTimeStampFcn
					tsfcn = obj.ReadTimeStampFcn;
					try
						% 						imDescription = tiffObj.getTag(Tiff.TagID.ImageDescription);
						
						
						
						feval(tsfcn, obj.TiffInfo(1).tiffTags(1));
					catch me
						getReport(me)
						tsfcn = @() NaN(1);
					end
				else
					tsfcn = @() NaN(1);% NEW: was  ->  tsfcn = @() NaN
				end
				ffidxfirst = obj.FileFrameIdx.first;
				ffidxlast = obj.FileFrameIdx.last;
				tinfo = obj.TiffInfo;
				parfor n = 1:numel(obj.TiffInfo)
					firstFrame = ffidxfirst(n);
					lastFrame = ffidxlast(n);
					tiffTag = tinfo(n).tiffTags;
					fprintf('Caching info from file %i\n',n)
					for k = firstFrame:lastFrame
						subk = k - firstFrame + 1;
						finfo(n).frameidx(subk,1) = k;
						finfo(n).subframeidx(subk,1) = subk;
						finfo(n).fileidx(subk,1) = n;
						finfo(n).t(subk,1) = feval(tsfcn, tiffTag(subk)); % TODO
					end
				end
				obj.AllFrameInfo.frameidx = cat(1,finfo.frameidx);
				obj.AllFrameInfo.subframeidx = cat(1,finfo.subframeidx);
				obj.AllFrameInfo.fileidx = cat(1,finfo.fileidx);
				obj.AllFrameInfo.t = cat(1,finfo.t);
			else
				for n = 1:numel(obj.TiffInfo)
					firstFrame = obj.FileFrameIdx.first(n);
					lastFrame = obj.FileFrameIdx.last(n);
					tiffTag = obj.TiffInfo(n).tiffTags;
					fprintf('Caching info from file %i\n',n)
					for k = firstFrame:lastFrame
						subk = k - firstFrame + 1;
						obj.AllFrameInfo.frameidx(k) = k;
						obj.AllFrameInfo.subframeidx(k) = subk;
						obj.AllFrameInfo.fileidx(k) = n;
						if tryCustomTimeStampFcn
							try
								obj.AllFrameInfo.t(k) = feval(obj.ReadTimeStampFcn, tiffTag(subk));
							catch me
								getReport(me)
								obj.AllFrameInfo.t(k) = NaN;
								tryCustomTimeStampFcn = false;
							end
						else
							obj.AllFrameInfo.t(k) = NaN;
							% TODO: Will need to survey formats to see what people tend to use
						end
					end
				end
			end
			
			% REORGANIZE FRAME INFORMATION INTO CACHED-ARRAY OF STRUCTURES FOR FASTER RETRIEVAL?
			% 			cacheChunkedFrameInfo(obj)
		end
		function estimateSuitableChunkSize(obj)
			if obj.UseGpu
				dev = gpuDevice;
				numPixels = prod(obj.FrameSize);
				obj.FramesPerStep = 2^(nextpow2(round(dev.AvailableMemory/numPixels/64))-2); %TODO;
			elseif obj.UsePct
				if isempty(obj.ParPool)
					obj.ParPool = gcp('nocreate');
				end
				if ~isempty(obj.ParPool)
					numWorkers = obj.ParPool.NumWorkers;
					obj.FramesPerStep = numWorkers;
				else
					obj.FramesPerStep = 1;
				end
			else
				obj.FramesPerStep = 1;
			end
		end
		function cacheChunkedFrameInfo(obj)
			idx = 0;
			m = 0;
			M = obj.FramesPerStep;
			N = obj.NumFrames;
			if isempty(M)
				estimateSuitableChunkSize(obj)
				M = obj.FramesPerStep;
			end
			numSteps = ceil(N/M);
			cachedInfo = struct(...
				'frameidx', repmat({zeros(M,1)}, numSteps, 1),...
				'subframeidx',repmat({zeros(M,1)}, numSteps, 1),...
				'fileidx',repmat({zeros(M,1)}, numSteps, 1),...
				't',repmat({zeros(M,1)}, numSteps, 1));
			allFrameIdx = obj.AllFrameInfo.frameidx;
			allSubFrameIdx = obj.AllFrameInfo.subframeidx;
			allFileIdx = obj.AllFrameInfo.fileidx;
			allT = obj.AllFrameInfo.t;
			while idx(end) < N
				m = m+1;
				idx = idx(end) + (1:M);
				idx = idx(idx<=N);
				cachedInfo(m).frameidx = allFrameIdx(idx);
				cachedInfo(m).subframeidx = allSubFrameIdx(idx);
				cachedInfo(m).fileidx = allFileIdx(idx);
				cachedInfo(m).t = allT(idx);
			end
			obj.NumSteps = numSteps;
			obj.CachedFrameInfo = cachedInfo;
		end
		function [data, varargout] = getDataSample(obj, nSampleFrames)
			
			if isLocked(obj)
				% ------------------------------------------
				% RETURN CURRENTLY BUFFERED DATA (IF LOCKED)
				% ------------------------------------------
				% 				warning('TiffStackLoader:getDataSample:SystemLocked',...
				% 					['The TiffStackLoader is currently locked and is unable to return randomly sampled',...
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
			if nargout > 1
				fld = fields(obj.AllFrameInfo);
				for fn=1:numel(fld)
					info.(fld{fn}) = obj.AllFrameInfo.(fld{fn})(sampleFrameIdx);
				end
			end
			
			% 			end
			if nargout > 1
				availableOutput = {info, sampleFrameIdx};
				varargout = availableOutput(1:(nargout-1));
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
				'TiffStackLoader', 'FileName');
			if ischar(value)
				obj.FileName = {value};
			else
				obj.FileName = value;
			end
			setPreInitializedState(obj)
		end
		function set.FileDirectory(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'TiffStackLoader', 'FileDirectory');
			if ischar(value)
				obj.FileDirectory = value;
			else
				obj.FileDirectory = value{1};
			end
			setPreInitializedState(obj)
		end
		function set.FullFilePath(obj, value)
			validateattributes( value, { 'cell', 'char' }, {},...
				'TiffStackLoader', 'FullFilePath');
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