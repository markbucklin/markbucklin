classdef FluoPro < handle
   % ------------------------------------------------------------------------------
   % FluoPro
   % FluoPro Toolbox
   % 2/24/2015
   % Mark Bucklin
   % ------------------------------------------------------------------------------
   %
   % The CALKRACKER function executes the default data-processing routine for a set of calcium imaging data. All
   % output will be saved with automatically generated file-names, and if no input is given this function will query
   % the user for all necessary input (i.e. data filenames) before launching into the data processing routine. If the
   % user wishes to return output directly to the MATLAB workspace, output arguments may be specified as in any of the
   % usage examples shown below.
   %
   % Optional input, FILENAME, may be a string containing the name of files to be
   % processed (e.g. 'raw1.tif'), a cell array of strings specifying multiple files, or a structure array such as that
   % returned by the function DIR, e.g.	>> FILENAME = DIR('.\*.tif');
   %
   %
   % EXAMPLE:
   % >> FluoPro()
   % >> FluoPro(FILENAME)
   % >> FluoPro(dir('.\*.tif'))
   % >> FluoPro(dir('Z:\Data\MyExperimentName\MyAnimalName\*.tif'))
   % >> [allVidFiles] = FluoPro();
   % >> [allVidFiles, R] = FluoPro();
   % >> [allVidFiles, R, info] = FluoPro();
   % >> [allVidFiles, R, info, uniqueFileName] = FluoPro();
   %
   %
   % If the user is running this function for the first time, or if the data to be processed are substantially
   % dissimilar to previously processed data, the user may run the CALKRACKERINTERACTIVE function, which will guide
   % the user through parameter selection
   %
   %
   % SubSystem Properties:
   %     currentDataFile - An object of a type derived from the DataFile
   %     class (VideoFile or BehaviorFile) that is currently open and being
   %     filled with data.
   %
   %     currentDataFileSet - The set of most recently made DataFile
   %     objects, which will be saved to a Mat file and forgotten when
   %     'saveDataSet' is called.
   %
   %     savedDataFiles - Previously held all DataFile objects which had
   %     been saved to a Mat file, however this property is not always used
   %     anymore.
   %
   %     systemName - A name used to differentiate multiple systems of the
   %     same type, e.g. multiple CameraSystems.
   %
   %     currentExperimentName - The name determined from the
   %     ExperimentSyncObj (normally acquired over UDP from BehavCtrl).
   %     Defaults to EXPX.
   %
   %     currentDataSetPath - Determined automatically from the savePath
   %     property and the currentExperimentName.
   %
   %     saveSetting - A switch to control how data is saved as it is
   %     acquired.
   %
   %     autoSaveFrequency - The number of trials (or calls to
   %     'saveDataFile') before the currentDataFileSet is saved to a Mat
   %     file and cleared from memory.
   %
   %     savePath - Should be assigned if not handled with GUI. Defaults to
   %     Z:\TEST\TEST_[date]\  .
   %
   %     frameDataCallbackFcn - A callback function can be assigned to this
   %     property to perform some operation on the data acquired in each
   %     frame. See details in the CameraSystem class documentation.
   %
   % SubSystem Methods:
   %   experimentStateChangeFcn - (abstract) trigger or stop acquisition
   %   trialStateChangeFcn - (abstract) save a DataFile object
   %   frameAcquiredFcn - (abstract) record data and write to currentDataFile
   %   start - (abstract) prepare system for acquisition
   %   stop - (abstract) stop acquisition
   %   saveDataFile - save and close currentDataFile
   %   saveDataSet - save currentDataFileSet in Mat file
   %   clearDataSet - clear currentDataFileSet
   %   updateExperimentName - check experimentSyncObj for experiment name
   %   isready - true if system has been started
   %   isvalid - true if system has NOT been deleted
   %
   % See also CAMERASYSTEM, BEHAVIORSYSTEM, DATAFILE, SYSTEMSYNCHRONIZER,
   % DATAACQUISITION, FRAMESYNX
   
   % INPUT
   properties
	  fileName
	  filePath
   end
   properties (SetAccess = protected)
	  inputFileSizeBytes
	  inputFileInfo
	  inputFileFrameInfo
	  numInputFile
   end
   % OPTIONS
   properties
	  useParallel = true
	  useGpu = true
	  useInteractive = false
	  fileType = 'tif'
   end
   properties (SetAccess = protected, Hidden)
	  option = struct(...
		 'useParallel',[],...
		 'useGpu',[],...
		 'useInteractive',[],...
		 'fileType',[]);
   end
   % PROCESSING FUNCTIONS
   properties
	  loadInputFcn = @loadTif
	  processInputFcn = { @correctIlluminationHomomorphic, @correctMotionNormXcorr, @normalizeDataMinSubtract}   
	  generateOutputFcn 
	  saveOutputFcn
	  processInputFcnParameters
	  generateOutputFcnParameters
   end
   % DATA
   properties
	  rawDataFileName
	  rawDataFileID
	  rawDataMemoryMap
	  rawFrame
	  rawInfo
	  processedDataFileName
	  processedDataFileID
	  processedDataMemoryMap
	  processedFrame
	  processedInfo
	  roiOutput
   end
   
   
   events
   end
   
   % CONSTRUCTOR/INITIALIZATION
   methods
	  function obj = FluoPro(varargin)
		 fprintf('\nEnjoy FluoPro\n')
		 % ------------------------------------------------------------------------------------------
		 % CHECK INPUT
		 % ------------------------------------------------------------------------------------------
		 if nargin > 1
			for k = 1:2:length(varargin)
			   obj.(varargin{k}) = varargin{k+1};
			end
		 elseif nargin == 1
			fname = varargin{1};
			switch class(fname)
			   case 'char'
				  obj.fileName = cellstr(fname);
			   case 'cell'
				  obj.fileName = cell(numel(fname),1);
				  for n = 1:numel(fname)
					 obj.fileName{n} = which(fname{n});
				  end
			   case 'struct'
				  obj.fileName = {fname.name}';
				  for n = 1:numel(obj.fileName)
					 obj.fileName{n} = which(obj.fileName{n});
				  end
			end
		 end
		 % ------------------------------------------------------------------------------------------
		 % CHECK FILE INPUT (QUERY USER IF NO INPUT IS PROVIDED)
		 % ------------------------------------------------------------------------------------------
		 if ~isempty(obj.filePath) && isdir(obj.filePath)
			addpath(obj.filePath);
		 end
		 if ~isempty(obj.fileName)
			[obj.filePath, ~] = fileparts(which(obj.fileName{1}));
		 else
			fext = obj.fileType;
			if isempty(fext)
			   fext = '*';
			end
			[fname,obj.filePath] = uigetfile(['*.',fext],'MultiSelect','on');
			addpath(obj.filePath);
			switch class(fname)
			   case 'char'
				  obj.fileName{1} = [obj.filePath,fname];
			   case 'cell'
				  obj.fileName = cell(numel(fname),1);
				  for n = 1:numel(fname)
					 obj.fileName{n} = [obj.filePath,fname{n}];
				  end
			end
		 end
		 if ~isempty(obj.fileName)
			% 			go(obj)
		 end
	  end
	  function go(obj)
		 global FPOPTION
		 % ------------------------------------------------------------------------------------------
		 % EXAMINE INPUTS
		 % ------------------------------------------------------------------------------------------
		 obj.inputFileInfo = cellfun(@dir, obj.fileName);
		 obj.inputFileSizeBytes = [obj.inputFileInfo.bytes];
		 obj.numInputFile = numel(obj.fileName);
		 inputFileFrameInfoChunk = cellfun(@imfinfo, obj.fileName, 'UniformOutput', false);
		 obj.inputFileFrameInfo = cat(1, inputFileFrameInfoChunk{:});
		 
		 
		 % ------------------------------------------------------------------------------------------
		 % CHECK INTERACTIVE VS. AUTOMATED (PARAMETER SELECTION ASSISTANCE MODE)
		 % ------------------------------------------------------------------------------------------
		 
		 
		 % ------------------------------------------------------------------------------------------
		 % STORE DEFAULT OPTIONS
		 % ------------------------------------------------------------------------------------------
		 fn = fields(obj.option);
		 for k = 1:numel(fn)
			if isprop(obj, fn{k})
			   obj.option.(fn{k}) = obj.(fn{k});
			   FPOPTION.(fn{k}) = obj.(fn{k});
			elseif isstruct(FPOPTION) && isfield(FPOPTION, fn{k})
			   obj.option.(fn{k}) = FPOPTION.(fn{k});
			   obj.(fn{k}) = FPOPTION.(fn{k});
			end
		 end
		 
		 % ------------------------------------------------------------------------------------------
		 % RUN
		 % ------------------------------------------------------------------------------------------
% 		 loadInput(obj)
		 % 		 processInput(obj)
		 % 		 generateOutput(obj)
		 % 		 saveOutput(obj)
	  end
   end
   % SEQUENTIALLY CALLED WRAPPER FUNCTIONS
   methods
	  function loadInput(obj)
		 
		 
		 % ------------------------------------------------------------------------------------------
		 % OPEN BINARY FILE FOR MEMORY-MAPPING
		 % ------------------------------------------------------------------------------------------
		 obj.rawDataFileName = fullfile(obj.filePath, 'rawdata.bin');
		 obj.rawDataFileID = fopen(obj.rawDataFileName, 'Wb');
		 % ------------------------------------------------------------------------------------------
		 % LOAD VIDEO DATA
		 % ------------------------------------------------------------------------------------------
		 infochunk = cell(numel(obj.fileName),1);
		 if obj.option.useParallel
			% USE PARALLEL (MULTI-CORE) READ AND SERIAL WRITE
			parfor kFile = 1:obj.numInputFile
			   [datachunk{kFile}, infochunk{kFile}] = feval(obj.loadInputFcn, obj.fileName(kFile));
			end
			info = cat(1, infochunk{:});
			fileFrameIdx.last = cumsum(cellfun(@numel, infochunk));
			fileFrameIdx.first = [0; fileFrameIdx.last(1:end-1)]+1;
			dataClass = class(datachunk{1});
			for kFile = 1:obj.numInputFile
			   fwrite(obj.rawDataFileID, datachunk{kFile}, dataClass);
			end
			clear datachunk infochunk
		 else
			userViewMem = memory;
			if userViewMem.MaxPossibleArrayBytes < sum(obj.inputFileSizeBytes)
			   % USE DECREASED MEMORY, SERIAL READ AND WRITE
			   for kFile = 1:obj.numInputFile
				  [datachunk, infochunk{kFile}] = feval(obj.loadInputFcn, obj.fileName(kFile));
				  dataClass = class(datachunk);
				  fwrite(obj.rawDataFileID, datachunk, dataClass);
			   end
			   info = cat(1, infochunk{:});
			   fileFrameIdx.last =cumsum(cellfun(@numel, infochunk));
			   fileFrameIdx.first = [0; fileFrameIdx.last(1:end-1)]+1;			   
			   clear datachunk infochunk
			else
			   % USE INCREASED MEMORY, SERIAL READ AND WRITE
			   [data, info] = feval(obj.loadInputFcn, obj.fileName);
			   dataClass = class(data);
			   fwrite(obj.rawDataFileID, data, dataClass);
			end
		 end
		 fclose(obj.rawDataFileID);
		 
		 % FIX FRAME NUMBERS
		 fn = cat(1, info.frame);
		 fnmax = max(fn);
		 fn = round(unwrap(fn.*(2*pi/fnmax)) .* (fnmax/(2*pi)));
		 
		 % ------------------------------------------------------------------------------------------
		 % STORE INFORMATION DESCRIBING VIDEO
		 % ------------------------------------------------------------------------------------------		 
		 vid.timestamps = cat(1, info.t);
		 vid.framenumbers = fn;
		 vid.subframenumbers = cat(1, info.subframe);
		 vid.numframes = numel(fn);
		 vid.bitdepth = obj.inputFileFrameInfo(1).BitDepth;
		 vid.width = obj.inputFileFrameInfo(1).Width;
		 vid.height = obj.inputFileFrameInfo(1).Height;
		 vid.pixperframe = vid.width*vid.height;
		 vid.bitsperframe = vid.pixperframe*vid.bitdepth;
		 vid.size = [vid.height vid.width vid.numframes];
		 vid.datatype = dataClass;
		 obj.rawInfo = vid;
		 
		 
		 % ------------------------------------------------------------------------------------------
		 % OPEN BINARY FILE FOR MEMORY-MAPPING TO RAW DATA
		 % ------------------------------------------------------------------------------------------
		 obj.rawDataMemoryMap = memmapfile(obj.rawDataFileName,...
			'Writable', false,...
			'Format', {obj.rawInfo.datatype, obj.rawInfo.size(1:2), 'cdata'});
		 obj.rawFrame = obj.rawDataMemoryMap.Data;
		 
	  end
	  function initializeProcessingFunctions(obj)
		  
		  % ------------------------------------------------------------------------------------------
			% CHECK INPUT - CONVERT DATA TO NUMERIC 3D-ARRAY
			% ------------------------------------------------------------------------------------------
			if isstruct(datainput)
				data = cat(3, datainput.cdata);
			else
				data = datainput;
			end
			
			
	  end
	  function processInput(obj)
		 
		 
		 
		 
		 
		 % ------------------------------------------------------------------------------------------
		 % PROCESS FIRST FILE
		 % ------------------------------------------------------------------------------------------
		 
		 
		 
		 
		 
		 
		 
		 
		 
		 mapDataOnDisk(obj, data)
		 
		 
		 % ------------------------------------------------------------------------------------------
		 % PROCESS FIRST FILE
		 % ------------------------------------------------------------------------------------------
		 [d8a, singleFrameRoi, procstart, info] = processFirstVidFile(tifFile(1).fileName);
		 vidStats(1) = getVidStats(d8a);
		 vidProcSum(1) = procstart;
		 % videoFileDir = [fdir, 'VideoFiles'];
		 % if ~isdir(videoFileDir)
		 %    mkdir(videoFileDir);
		 % end
		 vfile = saveVidFile(d8a,info, tifFile(1));
		 allVidFiles = VideoFile.empty(obj.numInputFile,0);
		 allVidFiles(1) = vfile;
		 % allVidFiles(obj.numInputFile) = vfile;
		 % ------------------------------------------------------------------------------------------
		 % PROCESS REST OF FILES (IN BACKGROUND)
		 % ------------------------------------------------------------------------------------------
		 % procFcn = @processVidFile;
		 vidStats(numel(tifFile),1) = vidStats(1);
		 vidProcSum(numel(tifFile),1) = vidProcSum(1);
		 for kFile = 2:numel(tifFile)
			fname = tifFile(kFile).fileName;
			fprintf(' Processing: %s\n', fname);
			[f.d8a, f.singleFrameRoi, procstart, f.info] = processVidFile(fname, procstart);
			vidStats(kFile) = getVidStats(f.d8a);
			vidProcSum(kFile) = procstart;
			vfile = saveVidFile(f.d8a, f.info, tifFile(kFile));
			allVidFiles(kFile,1) = vfile;
			%    d8a = cat(3,d8a, f.d8a);
			singleFrameRoi = cat(1,singleFrameRoi, f.singleFrameRoi);
			info = cat(1,info, f.info);
		 end
		 
		 
		 
		 
		 % ------------------------------------------------------------------------------------------
		 % ONCE VIDEO HAS BEEN PROCESSED - CREATE FILENAMES AND SAVE VIDEO
		 % ------------------------------------------------------------------------------------------
		 try
			uniqueFileName = procstart.commonFileName;
			saveTime = now;
			processedVidFileName =  ...
			   ['Processed_VideoFiles_',...
			   uniqueFileName,'_',...
			   datestr(saveTime,'yyyy_mm_dd_HHMM'),...
			   '.mat'];
			processedStatsFileName =  ...
			   ['Processed_VideoStatistics_',...
			   uniqueFileName,'_',...
			   datestr(saveTime,'yyyy_mm_dd_HHMM'),...
			   '.mat'];
			processingSummaryFileName =  ...
			   ['Processing_Summary_',...
			   uniqueFileName,'_',...
			   datestr(saveTime,'yyyy_mm_dd_HHMM'),...
			   '.mat'];
			roiFileName = ...
			   ['Processed_ROIs_',...
			   uniqueFileName,'_',...
			   datestr(saveTime,'yyyy_mm_dd_HHMM'),...
			   '.mat'];
			save(fullfile(fdir, processedVidFileName), 'allVidFiles');
			save(fullfile(fdir, processedStatsFileName), 'vidStats', '-v6');
			save(fullfile(fdir, processingSummaryFileName), 'vidProcSum', '-v6');
			% ------------------------------------------------------------------------------------------
			% MERGE/REDUCE REGIONS OF INTEREST
			% ------------------------------------------------------------------------------------------
			singleFrameRoi = fixFrameNumbers(singleFrameRoi);
			saveRoiExtract(singleFrameRoi,fdir)
			try
			   R = reduceRegions(singleFrameRoi);
			catch me
			   R = singleFrameRoi(1:500);
			   R = R.removeEmpty();
			   save('pseudo_ROIs', 'R')
			   keyboard
			end
			try
			   R = reduceSuperRegions(R);
			catch me
			   save('pseudo_Reduced_ROIs', 'R')
			   keyboard
			end
			% ------------------------------------------------------------------------------------------
			% SAVE TOP 1000 ROIs ACCORDING TO 'FrameDifferenceSum' INDEX
			% ------------------------------------------------------------------------------------------
			%   fds = zeros(numel(R),1);
			%   for k=1:numel(R)
			% 	 fds(k,1) = sum(diff(R(k).Frames) == 1) / sum(diff(R(k).Frames) > 2);
			%   end
			save('allROI','R')
			%   fdsmin = 0;
			%   while sum(fds >= fdsmin) > 1000
			% 	 fdsmin = fdsmin + .1;
			%   end
			%   R = R(fds >= fdsmin);
			delete(gcp)
			% ------------------------------------------------------------------------------------------
			% RELOAD DATA AND MAKE ROI TRACES (NORMALIZED TO WINDOWED STD)
			% ------------------------------------------------------------------------------------------
			[data, vidinfo] = getData(allVidFiles);
			data = squeeze(data);
			Xraw = makeTraceFromVid(R,data);
			%TODO: FIX THIS DETRENDING NORMALIZING THING
			%   fs=20;
			%   winsize = 1*fs;
			%   numwin = floor(size(X,1)/winsize)-1;
			%   xRange = zeros(numwin,size(X,2));
			%   for k=1:numwin
			% 	 windex = (winsize*(k-1)+1):(winsize*(k-1)+20);
			% 	 xRange(k,:) = range(detrend(X(windex,:)), 1);
			%   end
			%   Xraw = X;%new
			%   X = bsxfun(@rdivide, X, mean(xRange,1));	
			% FILTER AND NORMALIZE TRACES AFTER COPYING TRACE TO RAWTRACE
			for k=1:numel(R)
			   R(k).RawTrace = Xraw(:,k);%new
			   % 	 R(k).Trace = X(:,k);
			end
			R.normalizeTrace2WindowedRange
			R.makeBoundaryTrace
			R.filterTrace
			% SAVE AND RETURN OUTPUTS (OR ASSIGN IN BASE)
			save(fullfile(fdir,roiFileName), 'R');
			if nargout > 0
			   varargout{1} = allVidFiles;
			   if nargout > 1
				  varargout{2} = R;
				  if nargout > 2
					 varargout{3} = info;
					 if nargout > 3
						varargout{4} = uniqueFileName;
					 end
				  end
			   else
				  assignin('base','allVidFiles',allVidFiles)
			   end
			else
			   assignin('base','R',R)
			end
		 catch me
			keyboard
		 end
		 
	  end
	  function generateOutput(obj)
	  end
	  function saveOutput(obj)
	  end
   end
   methods
	  function mapDataOnDisk(obj, datainput)
		 if ~isempty(obj.processedDataMemoryMap)
			if ~isempty(obj.processedFrame)
			   obj.processedFrame = [];
			end
			obj.processedDataMemoryMap = [];
		 end
		 if isstruct(datainput)
			data = cat(3,datainput.cdata);
		 else
			data = datainput;
		 end
		 dataClass = class(data);
		 sz = size(data);
		 obj.processedDataFileName = fullfile(obj.filePath, 'databuffer.bin');
		 obj.processedDataFileID = fopen(obj.processedDataFileName, 'Wb');		 
		 fwrite(obj.processedDataFileID, data, dataClass);
		 fclose(obj.processedDataFileID);
		 obj.processedDataMemoryMap = memmapfile(obj.processedDataFileName,...
			'Writable', true,...
			'Format', {dataClass, sz(1:2), 'cdata'});
		 obj.processedFrame = obj.processedDataMemoryMap.Data;
	  end
   end
   % CLEANUP
   methods
	  function delete(obj)
		 obj.rawFrame = [];
		 obj.processedFrame = [];
		 obj.rawDataMemoryMap = [];
		 obj.processedDataMemoryMap = [];
	  end
   end
 
   
   
   
   
   
   
   
   
end




























