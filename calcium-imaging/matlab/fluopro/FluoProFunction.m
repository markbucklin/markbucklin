classdef FluoProFunction < hgsetget
   
   
   
   
   properties
	  useGpu = true
	  usePct = true
	  useMemoryMap = true
	  useInteractive
	  collectFigures
	  tunableParameters
	  sampleFrameNumbers
	  nSequentialSamples
	  expectedCellPixelDiameter = [8 30]
	  tempDir = 'Z:\.TEMP'
	  diskDataFileName = 'memmap-databuffer'
   end
   properties (SetAccess = protected, Transient)
	  default
	  settableProps
	  isTuned
	  isTunable
	  isInteractive
	  resourceRequirements
	  isSequential
	  canUseInteractive
	  canUseGpu
	  canUsePct
   end
   properties (SetAccess = protected)
	  classHistory
	  dataSetName
   end
   
   
   properties (Access = protected, Transient)
	  statusHandle
	  statusString
	  statusNumber
	  isDiskDataCurrent = false
   end
   properties (Constant)
	  statusUpdateInterval = .15
	  minSampleNumber = 100
   end
   properties %(SetAccess = protected)
	  info
	  data
	  stat
	  eff
	  effSample
	  frameIdx
	  nFrames
	  frameProcessed
	  stableFrames
	  preSample
	  postSample
	  saturatedRange
	  figures
	  memoryMap
	  memoryMapFileName
	  memoryMapFileID
	  memoryMapFrame
   end
   
   
   
   
   
   
   
   
   
   methods
	  function obj = FluoProFunction(varargin)
		 if nargin
			subObj = varargin{1};
			for n=numel(subObj):-1:1
			   % 					obj(n) = subObj(n);
			   oMeta = metaclass(obj(n));
			   oProps = oMeta.PropertyList(:);
			   oProps = oProps(~strcmp({oProps.GetAccess},'private'));
			   for k=1:numel(oProps)
				  if strcmp(oProps(k).GetAccess,'private') || oProps(k).Constant
					 continue
				  else
					 obj(n).(oProps(k).Name) = subObj(n).(oProps(k).Name);
				  end
			   end
			   checkFluoProOptions(obj(n)); % TODO: find proper place to check options
			   fprintf('FluoPro: Creating a %s\n',class(obj(n)));
			end
		 end
		 
		  % DEFAULTS		 (NEW, moved from obj.initialize() )
		  % 		 if ~isempty(obj.data)
		  % 			 obj.nFrames = size(obj.data,3);
		  % 			obj.default.diskDataFileName = ['databuffer_',class(obj.data),'.bin'];
		  % 		 else
		  % 			obj.default.diskDataFileName = ['databuffer.bin'];
		  % 		 end
		 
	  end
	  function obj = parseConstructorInput(obj,args)
		 if nargin < 2
			args = {};
		 end
		 propSpec = {};
		 nArgs = numel(args);
		 if nArgs >= 1
			% EXAMINE FIRST INPUT -> SUBCLASS, STRUCT, DATA, PROPS
			firstArg = args{1};
			firstArgType = find([...
			   isa( firstArg, 'FluoProFunction') ; ...
			   isstruct( firstArg ) ; ...
			   isnumeric( firstArg ) ; ...
			   isa( firstArg, 'char') ],...
			   1, 'first');
			switch firstArgType
			   case 1 % FLUOPROFUNCTION SUBCLASS
				  obj = copyProps(obj,firstArg);
			   case 2 % STRUCTURE REPRESENTATION OF OBJECT
				  fillPropsFromStruct(firstArg);
			   case 3 % RAW DATA INPUT
				  obj.data = firstArg;
			   case 4 % 'PROPERTY',VALUE PAIRS
				  propSpec = args(:);
			   otherwise
				   % 				  keyboard %TODO
			end
			if isempty(propSpec) && nArgs >=2
			   propSpec = args(2:end);
			end
		 end
		 if ~isempty(propSpec)
			if numel(propSpec) >=2
			   for k = 1:2:length(propSpec)
				  obj.(propSpec{k}) = propSpec{k+1};
			   end
			end
		 end
		 function fillPropsFromStruct(structSpec)
			fn = fields(structSpec);
			for kf = 1:numel(fn)
			   try
				  obj.(fn{kf}) = structSpec.(fn{kf});
			   catch me
				  warning('FluoProFunction:parseConstructorInput', me.message)
			   end
			end
		 end
	  end
	  function obj = checkOptions(obj)
		 if isempty(obj.settableProps)
			obj = getSettableProperties(obj);
		 end
		 props = fields(obj.default);
		 for k=1:numel(props)
			if isempty(obj.(props{k}))
			   obj.(props{k}) = obj.default.(props{k});
			end
		 end
	  end
	  function obj = checkFluoProOptions(obj)
		 global FPOPTION
		 % CHECK GPU-PROCESSING ABILITY
		 if isempty(FPOPTION) || ~isfield(FPOPTION, 'useGpu')
			try
			   % TODO: store GPU device info  --> dev.Name, dev.MultiprocessorCount, dev.ComputeCapability
			   gpu = gpuDevice;
			   if gpu.isCurrent && gpu.DeviceSupported
				  FPOPTION.useGpu = true;
			   else
				  FPOPTION.useGpu = false;
			   end
			catch
			   FPOPTION.useGpu = false;
			end
		 end
		 % SET MEMBER OPTION TO GLOBAL PREFERENCE IF EMPTY, OR PREF IS TO NOT USE GPU
		 if isempty(obj.useGpu) || (obj.useGpu && ~FPOPTION.useGpu)
			obj.useGpu = FPOPTION.useGpu;
		 end
		 % CHECK PCT-PROCESSING ABILITY
		 if isempty(FPOPTION) || ~isfield(FPOPTION,'usePct')
			try
			   versionInfo = ver;
			   if any(strcmpi({versionInfo.Name},'Parallel Computing Toolbox'))
				  % TODO: Query user to use PCT
				  if strcmp('Yes', questdlg('Would you like to use the Parallel Computing Toolbox where available?'))
					 FPOPTION.usePct = true;
				  else
					 FPOPTION.usePct = false;
				  end
			   else
				  FPOPTION.usePct = false;
			   end
			catch
			   FPOPTION.usePct = false;
			end
		 end
		 % SET MEMBER OPTION TO GLOBAL PREFERENCE IF EMPTY, OR PREF IS TO NOT USE GPU
		 if isempty(obj.usePct) || (obj.usePct && ~FPOPTION.usePct)
			obj.usePct = FPOPTION.usePct;% TODO: check canUsePct & canUseGpu
		 end
		 
	  end
	  function obj = setStatus(obj,statusNum, statusStr)
		 % FluoProFunctions use the method >> obj.setStatus(n, 'function status') in a similar manner to how
		 % they would use the MATLAB builtin waitbar function. This method will create a waitbar for functions
		 % that update their status in this manner, but may be easily modified to convey status updates to the
		 % user in some other by some other means. Whatever the means, this method keeps the avenue of
		 % interaction consistent and easily modifiable.
		 persistent setTime
		 if isempty(setTime)
			setTime = cputime;
		 end
		 if nargin < 3
			if isempty(obj.statusString)
			   statusStr = 'Awaiting status update';
			else
			   statusStr = obj.statusString;
			end
			if nargin < 2 % NO ARGUMENTS -> Closes
			   obj = closeStatus(obj);
			   return
			end
		 end
		 obj.statusString = statusStr;
		 obj.statusNumber = statusNum;
		 if isinf(statusNum) % INF -> Closes
			obj = closeStatus(obj);
			return
		 end
		 % OPEN OR CLOSE STATUS INTERFACE (WAITBAR) IF REQUESTED
		 %      0 -> open          inf -> close
		 if (cputime - setTime) > obj.statusUpdateInterval
			if isempty(obj.statusHandle) || ~isvalid(obj.statusHandle)
			   obj = openStatus(obj);
			   return
			else
			   obj = updateStatus(obj);
			end
			setTime = cputime;
		 end
	  end
	  function obj = cast(obj, newclass)
		 for n=numel(obj):-1:1
			oMeta = metaclass(obj(n));
			oPropsAll = oMeta.PropertyList(:);
			oProps = oPropsAll([oPropsAll.DefiningClass] == oMeta);
			for k=1:numel(oProps)
			   oHist(n).(oProps(k).Name) = obj(n).(oProps(k).Name);
			end
			oHist(n).preSample = obj(n).preSample;
			oHist(n).postSample = obj(n).postSample;
			oHist(n).figures = obj(n).figures;
		 end
		 obj = FluoProFunction(obj);
		 for n=numel(obj):-1:1
			% ACCUMULATE HISTORY OF PRIVATE PROPERTIES FROM OLD CLASS
			oldClassName = oMeta.Name;
			if isstruct(obj(n).classHistory)
			   k=1;
			   while isfield(obj(n).classHistory,oldClassName)
				  oldClassName = [oMeta.Name,num2str(k)];
				  k=k+1;
			   end
			end
			obj(n).classHistory.(oldClassName) = oHist(n);
		 end
		 if isa(newclass, 'function_handle')
			obj = newclass(obj);
		 elseif isa(newclass, 'char')
			constructorString = sprintf('%s(obj)', newclass);
			obj = eval(constructorString);
		 end
		 % 			obj = newobj;
		 % 			for n=numel(obj):-1:1
		 % 				obj(n).tunableParameters = [];
		 % 			end
	  end
	  function obj = copyProps(obj,objInput)
		 oMetaIn = metaclass(objInput);
		 oPropsIn = oMetaIn.PropertyList(:);
		 for n=numel(obj):-1:1
			oMetaOut = metaclass(obj(n));
			oPropsOut = oMetaOut.PropertyList(:);
			% 				oProps = oPropsAll([oPropsAll.DefiningClass] == oMeta);
			for k=1:numel(oPropsOut)
			   if any(strcmp({oPropsIn.Name},oPropsOut(k).Name))
				  if ~strcmp(oPropsOut(k).GetAccess,'private') ...
						&& ~oPropsOut(k).Constant ...
						&& ~oPropsOut(k).Transient
					 obj(n).(oPropsOut(k).Name) = objInput.(oPropsOut(k).Name);
				  end
			   end
			end
			% 			obj(n).data = objInput.data;  %TODO?
		 end
	  end
	  function obj = getSettableProperties(obj)
		 for n=numel(obj):-1:1
			oMeta = metaclass(obj(n));
			oPropsAll = oMeta.PropertyList(:);
			oProps = oPropsAll([oPropsAll.DefiningClass] == oMeta);
			propSettable = ~strcmp('private',{oProps.SetAccess}) ...
			   & ~strcmp('protected',{oProps.SetAccess}) ...
			   & ~[oProps.Constant] ...
			   & ~[oProps.Transient];
			obj(n).settableProps = oProps(propSettable);
		 end
	  end
	  function obj = getDataSampleStatistics(obj, nSamples, extremeValuePercentTrim, outputDataType)
		 % Returns pixel-by-pixel statistics (min,max,mean,std) over time, using a trimmed-mean to calculate the mean and
		 % standard deviation (builtin function trimmean()).
		 %
		 % IMPORTANT NOTE: Currently mean and std calculations are performed in the same datatype as the input which will
		 % likely compound rounding errors for integer datatypes
		 
		 if nargin < 4
			outputDataType = [];
			%    outputDataType = class(data);
			%    outputDataType = 'single';
			%    outputDataType = 'double';
			if nargin < 3
			   extremeValuePercentTrim = 25;
			   if nargin < 2
				  nSamples = 250;
			   end
			end
		 end
		 
		 % TODO: could implement array  here, potentially with pct/parfor, atleast after removing data
		 dataSample = getDataSample(obj, obj.data, nSamples);
		 inputDataType = class(dataSample);
		 sz = size(dataSample);
		 frameSize = sz(1:2);
		 
		 sampleStat.min = min(dataSample,[],3);
		 sampleStat.max = max(dataSample,[],3);
		 statMean = ...
			trimmean(dataSample,...
			extremeValuePercentTrim, 3);
		 statStd = ...
			mean(...
			max(cat(4,...
			bsxfun(@minus, dataSample, cast(statMean,inputDataType)),...
			bsxfun(@minus, cast(statMean, inputDataType), dataSample)),...
			[], 4),...
			3);
		 % POSITIVE AND NEGATIVE LOBES BROKEN DOWN
		 if inputDataType(1) == 'u'
			upperStd = mean(bsxfun(@minus, dataSample, cast(statMean, inputDataType)), 3);
			lowerStd = mean(bsxfun(@minus, cast(statMean, inputDataType), dataSample), 3);
		 else
			upperStd = ...
			   mean(...
			   bsxfun( @max, ...
			   bsxfun(@minus, dataSample, cast(statMean, inputDataType)),...
			   zeros(frameSize, 'like', dataSample)),...
			   3);
			lowerStd = ...
			   mean(...
			   bsxfun( @max, ...
			   bsxfun(@minus, cast(statMean, inputDataType), dataSample),...
			   zeros(frameSize, 'like', dataSample)),...
			   3);
		 end
		 
		 if ~isempty(outputDataType)
			sampleStat.mean = cast(statMean, outputDataType);
			sampleStat.std = cast(statStd, outputDataType);
			sampleStat.upperstd = cast(upperStd, outputDataType);
			sampleStat.lowerstd = cast(lowerStd, outputDataType);
		 else
			sampleStat.mean = statMean;
			sampleStat.std = statStd;
			sampleStat.upperstd = upperStd;
			sampleStat.lowerstd = lowerStd;
		 end
		 % 			if isempty(obj.stat)
		 obj.stat = sampleStat;
		 % 			else
		 % 				obj.stat(numel(obj.stat)+1) = sampleStat;
		 % 			end
	  end
	  function obj = getDataSampleEff(obj, nSamples)
		 
		 if nargin < 2
			nSamples = 500;
		 end
		 if isnumeric(nSamples)
			F = getDataSample(obj.data, nSamples);
			propname = 'effSample';
		 else
			F = obj.data;
			propname = 'eff';
		 end
		 
		 % FIND MAX PEAKS IN ENTROPY-FILTERED STACK, MINIMIZED OVER TIME
		 diskRadius = floor(mean(obj.expectedCellPixelDiameter.*sqrt(2)/pi));
		 efNhood = getnhood(strel('disk', diskRadius));
		 [nrows, ncols, N] = size(F);
		 efF = zeros(nrows,ncols,N,'uint8');
		 frameEntropy = zeros(1,1,N);
		 parfor k=1:N
			efF(:,:,k) = uint8(8 * entropyfilt(F(:,:,k), efNhood));
			frameEntropy(k) = entropy(F(:,:,k));
		 end
		 try
			obj.(propname).frameEntropy = frameEntropy;
			obj.(propname).note = 'All values except frameEntropy are multiplied by 8';
			obj.(propname).min = min(efF,[],3);
			obj.(propname).max = max(efF,[],3);
			effAvg = mean(efF, 3, 'native');
			obj.(propname).absdev = bsxfun(@minus, efF, effAvg) + bsxfun(@minus, effAvg, efF);
			obj.(propname).range = obj.(propname).max - obj.(propname).min;
			obj.(propname).mean = effAvg;
			obj.(propname).data = efF;			
		 catch me
			msg = getReport(me);
			disp(msg)
			% 			keyboard
		 end
	  end
	  function obj = getEntropyFilteredFrames(obj)
		 obj = getDataSampleEff(obj, 'all');
		 
		 % FIND MAX PEAKS IN ENTROPY-FILTERED STACK, MINIMIZED OVER TIME
		 % 		   nhoodSize = max(obj.expectedCellPixelDiameter);
		 % 		   nhoodSize = 1+2*floor(nhoodSize/2);
		 % 		   efNhood = true(nhoodSize);
		 % 		 diskRadius = ceil(mean(obj.expectedCellPixelDiameter).*sqrt(2)/2);
		 % 		 efNhood = getnhood(strel('disk', diskRadius));
		 % 		 [nrows, ncols, N] = size(obj.data);
		 % 		 entropyFilteredFrame = zeros(nrows,ncols,N,'uint8');
		 % 		 frameEntropy = zeros(1,1,N);
		 % 		 parfor k=1:N
		 % 			entropyFilteredFrame(:,:,k) = entropyfilt(F(:,:,k), efNhood) ./ entropy(F(:,:,k)) - 1;
		 % 			pEff = entropyfilt(obj.data(:,:,k), efNhood);
		 % 			entropyFilteredFrame(:,:,k) = uint8(pEff .* 8)
		 % 			frameEntropy(k) = entropy(obj.data(:,:,k));
		 % 		 end
		 % 		   normalizedEff = bsxfun(@rdivide, entropyFilteredFrame, frameEntropy) - 1;
		 % 		 obj.eff.frameEntropy = frameEntropy;
		 % 		 % 		 normalizedEff = bsxfun(@rdivide, entropyFilteredFrame, frameEntropy) - 1;
		 % 		 obj.eff.min = min(entropyFilteredFrame,[],3);
		 % 		 obj.eff.max = max(entropyFilteredFrame,[],3);
		 % 		 obj.eff.sum = sum(entropyFilteredFrame, 3);
		 % 		 obj.eff.std = std(entropyFilteredFrame,1,3);
		 % 		 obj.eff.range = obj.eff.max - obj.eff.min;
		 % 		 obj.eff.data = entropyFilteredFrame;
		 % [Fx, Fy, Ft] = gradient(single(F));
		 % dFt = std(Ft,1,3);
		 % Fr = sqrt(Fx.^2 + Fy.^2);
		 
		 % implay(mat2gray(normalizedEff))
		 % imagesc(temporalMaxEff./abs(temporalMinEff), [0 5]), colorbar
		 % imagesc(log1p(temporalMaxEff./abs(temporalMinEff))), colorbar
	  end
   end
   methods
	  function obj = initialize(obj)		
		 
	  end
	  function obj = run(obj)
		 obj.isDiskDataCurrent = false;
	  end
	  function obj = finalize(obj)
		 % 		   persistent previousFinalizeTime TODO
		 [obj, sampleData] = getDataSample(obj,obj.data);
		 obj.postSample = sampleData;
		 if obj.useMemoryMap
			if ~isempty(obj.memoryMap) && strcmp(class(obj.data), obj.memoryMap.Format{1})
			   obj = updateMemoryMap(obj);
			else
			   obj = mapDataOnDisk(obj);
			end
		 end
		 obj = setStatus(obj,inf);
	  end
	 
   end
   methods (Access = protected)
	  function obj = openStatus(obj)
		 obj.statusHandle = waitbar(0,obj.statusString);
	  end
	  function obj = updateStatus(obj)
		 % IMPLEMENT WAITBAR UPDATES  (todo: or make a updateStatus method?)
		 if isnumeric(obj.statusNumber) && ischar(obj.statusString)
			if ~isempty(obj.statusHandle) && isvalid(obj.statusHandle)
			   waitbar(obj.statusNumber, obj.statusHandle,obj.statusString);
			end
		 end
	  end
	  function obj = closeStatus(obj)
		 if ~isempty(obj.statusHandle)
			if isvalid(obj.statusHandle)
			   close(obj.statusHandle)
			end
			obj.statusHandle = [];
		 end
	  end
   end
   methods (Access = public)
	  
	  function varargout = getDataSample(obj, data, varargin)
		 % >> [obj, data] = getDataSample( obj, obj.data, nSampleFrames, nSequentialSamples);
		 % TODO: sample from array of FluoProFunctions
		 % DETERMINE NUMBER OF FRAMES TO SAMPLE
		 if isnumeric(data)
			sz = size(data);
			N = size(data,ndims(data));
			getSampleFcn = @numericArrayFcn;
		 elseif isstruct(data)
			N = numel(data);
			sz = size(data(1).cdata);
			getSampleFcn = @structArrayFcn;
		 else
			warning('Check input')
		 end
		 nrows = sz(1);
		 ncols = sz(2);
		 switch numel(varargin)
			case 0
			   nSampleFrames = min(N, obj.minSampleNumber);
			case 1 % 3rd dimension spans across time pseudo-randomly
			   nSampleFrames = ceil(varargin{1});
			   obj.nSequentialSamples = 1;
			case 2
			   nSampleFrames = ceil(varargin{1});
			   obj.nSequentialSamples = varargin{2};
		 end
		 
		 if isempty(obj.sampleFrameNumbers)
			jitter = floor(N/nSampleFrames);
			obj.sampleFrameNumbers = round(linspace(1, N-jitter, nSampleFrames)')...
			   + round( jitter*rand(nSampleFrames,1));
		 end
		 if isempty(obj.nSequentialSamples)
			obj.nSequentialSamples = 1;
		 end
		 
		 dataSample = feval(getSampleFcn);
		 
		 if nargout > 1
			varargout{1} = obj;
			varargout{2} = dataSample;
		 else
			varargout{1} = dataSample;
		 end
		 function dataSample = numericArrayFcn()
			if obj.nSequentialSamples <= 1
			   switch ndims(data)
				  case 3
					 dataSample = data(:,:,obj.sampleFrameNumbers);
				  case 4
					 dataSample = data(:,:,:,obj.sampleFrameNumbers);%TODO: for MultiChannel
				  otherwise
					 dataSample = data;
			   end
			else
			   dataSample = zeros( nrows, ncols,...
				  numel(obj.sampleFrameNumbers), ...
				  numel(obj.nSequentialSamples),...
				  'like',data);
			   for k=1:numel(obj.sampleFrameNumbers)
				  sequentialIdx = (obj.sampleFrameNumbers(k) + (0:(obj.nSequentialSamples-1)));
				  switch ndims(data)
					 case 3
						dataSample(:,:,k,:) = data(:,:,sequentialIdx);
					 case 4
						dataSample(:,:,:,k,:) = data(:,:,:,sequentialIdx);%TODO: for MultiChannel
					 otherwise
						dataSample = data;
				  end
			   end
			end
		 end
		 function dataSample = structArrayFcn()		
			dataSample = data(obj.sampleFrameNumbers);
		 end
	  end
	  function obj = getSaturatedRange(obj, saturationPercentiles)
		 if nargin < 2
			saturationPercentiles = [.05 .9995];
		 end
		 if any(saturationPercentiles > 1)
			saturationPercentiles = saturationPercentiles/100;
		 end
		 xClass = class(obj.preSample);
		 if obj.canUseGpu
			X = gpuArray(obj.preSample);
		 else
			X = obj.preSample;
		 end
		 nSampleFrames = size(X,ndims(X));
		 nPixelsPerFrame = numel(X(:))/nSampleFrames;
		 
		 try
			satLims = stretchlim(X, saturationPercentiles);
			satRange = double(max(satLims,[],2))' .* double(intmax(xClass));
		 catch me
			warning(me.message)
			targetPixOver = round((1-saturationPercentiles(2)) * nPixelsPerFrame);
			targetPixUnder = round(saturationPercentiles(1) * nPixelsPerFrame);
			maxIntensity = max(X(:));
			minIntensity = min(X(:));
			if isa(X, 'integer')
			   initialStep = ceil(intmax(class(X))/64);
			   minStep = ceil(initialStep/64);
			else
			   initialStep = 1/1000;
			   minStep = 1/10000;
			end
			pixOver = 0;
			step = initialStep;
			while step > minStep
			   if pixOver > targetPixOver
				  break
			   end
			   pixOver = nnz(X(:) >= maxIntensity-step);
			   if pixOver < targetPixOver
				  maxIntensity = maxIntensity - step;
			   else
				  step = step/2;
				  pixOver = pixOver-step/2;
				  maxIntensity = maxIntensity - step;
			   end
			end
			step = initialStep;
			pixUnder = 0;
			while step > minStep
			   if pixUnder > targetPixOver
				  break
			   end
			   pixUnder = nnz(X(:) <= minIntensity-step);
			   if pixUnder < targetPixUnder
				  minIntensity = minIntensity + step;
			   else
				  step = step/2;
				  pixUnder = pixUnder-step/2;
				  minIntensity = minIntensity + step;
			   end
			end
			satRange = [minIntensity maxIntensity];
		 end
		 if isa(satRange,'gpuArray')
			obj.saturatedRange = gather(satRange);
		 else
			obj.saturatedRange = satRange;
		 end
	  end
   end
   methods (Access = public)
	  function obj = mapDataOnDisk(obj)
		 try
			% TODO
			obj = setStatus(obj,0,'Mapping Data to Disk');
			if ~isempty(obj.memoryMap)
			   if ~isempty(obj.memoryMapFrame)
				  obj.memoryMapFrame = [];
			   end
			   obj.memoryMap = [];
			end
			dataClass = class(obj.data);
			sz = size(obj.data);
			% setenv('DEFAULTTEMP',getenv('TEMP')),setenv('TEMP',obj.tempDir) TODO
			
			% CHECK TEMPDIR -> FIND HIGH-CAPACITY DISK IF DIRECTORY NOT SPECIFIED
			if ~isempty(obj.tempDir)
				if ~isdir(obj.tempDir)
					try
						mkdir(obj.tempDir);
					catch
						obj.tempDir = getenv('HIGHCAPACITYTEMP');
					end
				end
			end
			if isempty(obj.tempDir) || ~isdir(obj.tempDir)				
				drivesAvail = findDriveSizeAvailable();
				[~,largestDriveIdx] = max([drivesAvail.gbAvailable]);
				tempDriveLetter = drivesAvail(largestDriveIdx).driveLetter; %TODO: for linux -> mount point??
				tempDriveFolder = '.TEMP';
				obj.tempDir = [tempDriveLetter,':\',tempDriveFolder];
				if ~isdir(obj.tempDir)
					mkdir(obj.tempDir);
				end
				setenv('HIGHCAPACITYTEMP', obj.tempDir);
			end
			
			
			obj.memoryMapFileName = fullfile(obj.tempDir, obj.diskDataFileName);%TODO find fastest disk
			obj.memoryMapFileID = fopen(obj.memoryMapFileName, 'W');%obj.memoryMapFileID = fopen(obj.memoryMapFileName, 'Wb');
			fwrite(obj.memoryMapFileID, obj.data, dataClass);
			fclose(obj.memoryMapFileID);
			obj.memoryMap = memmapfile(obj.memoryMapFileName,...
			   'Writable', true,...
			   'Format', {dataClass, sz(1:2), 'cdata'});
			obj = setStatus(obj, inf);
			obj.isDiskDataCurrent = true;
		 catch me
			 disp(me.message)
		 end
		 
		 % SUBFUNCTION  FOR FINDING AVAILABLE TEMPORARY HARDDISK-SPACE
		  function drivesAvail = findDriveSizeAvailable()
			  if ispc
				  drivesAvail = struct.empty();
				  driveNum = 0;
				  k=0;
				  while k < 26
					  k=k+1;
					  driveLetter = char(64+k);
					  [driveStat, driveStr] = system(sprintf('dir %s:\\',driveLetter));
					  if driveStat == 0
						  driveNum = driveNum + 1;
						  [c,~] = textscan(driveStr, '%s', 'Delimiter','\n');
						  c = c{1};
						  lastLine = c{end};
						  [c,~] = textscan(lastLine, '%*f %*s %s bytes free');
						  c = c{1};
						  bytesFreeStr = c{1};
						  numBytes = str2double(bytesFreeStr);
						  % 						  bytesFreeVec = str2num(bytesFreeStr);
						  % 						  multiplierVec = 2 .^ (10*fliplr(0:(numel(bytesFreeVec)-1)));
						  % 						  numBytes = sum( bytesFreeVec .* multiplierVec);
						  numGigaBytes = numBytes / 2^30;
						  dirList = dir(sprintf('%s:\\',driveLetter));						  
						  drivesAvail(driveNum).driveLetter = driveLetter;
						  drivesAvail(driveNum).gbAvailable = numGigaBytes;
						  drivesAvail(driveNum).dirList = dirList;
					  end					  
				  end
			  else
				  % TODO
				  
			  end
		  end
	  end
	  function obj = updateMemoryMap(obj, updateFrameIdx)
		 try
			if nargin < 2
			   updateFrameIdx = obj.frameIdx;
			end
			if isempty(obj.memoryMap)
			   obj = mapDataOnDisk(obj);
			else
			   if numel(obj.memoryMap.Data) == numel(obj.frameIdx)
				  obj = mapDataOnDisk(obj);
			   else
				  for k=1:numel(updateFrameIdx)
					 idx = updateFrameIdx(k);
					 obj.memoryMap.Data(idx).cdata = obj.data(:,:,idx);% TODO: use separate index for memory-mapped and loaded data
				  end
			   end
			end
		 catch me
			disp(me.message)
		 end
	  end
	  function obj = readFromMemoryMap(obj, fileName)
		 classesAvailable = {'uint16','uint8'};
		 dataClass = classesAvailable{listdlg('ListString',classesAvailable)};
		 sizeAvailable = {'[2048 2048]','[1024 1024]','[512 512]','[256 256]'};%TODO
		 sz = eval(sizeAvailable{listdlg('ListString',sizeAvailable, 'InitialValue',2)});
		 
		 defaultFileName = fullfile(obj.tempDir, obj.diskDataFileName);
		 if nargin < 2
			if exist(defaultFileName,'file')
			   fileName = defaultFileName;
			else
			   [fileName, fileDir] = uigetfile([obj.tempDir,filesep,'*']);
			   fileName = fullfile(fileDir,fileName);
			end
		 end
		 obj.memoryMapFileName = fileName;
		 obj.memoryMap = memmapfile(obj.memoryMapFileName,...
			'Writable', true,...
			'Format', {dataClass, sz(1:2), 'cdata'}); %TODO
		 obj.nFrames = numel(obj.memoryMap.Data);
		 N = obj.nFrames;
		 obj.memoryMapFileID = fopen(obj.memoryMapFileName, 'r');
		 obj.data = reshape(fread(obj.memoryMapFileID, ['*',dataClass]), [sz N]);
		 fclose(obj.memoryMapFileID);
		 % 			obj.data = zeros([sz N], dataClass);
		 % 			for k=1:N
		 % 			   obj.data(:,:,k) = obj.memoryMap.Data(k).cdata;
		 % 			end
		 if isempty(obj.frameIdx)
			obj.frameIdx = 1:N;
		 end
	  end
	   function objByteStream = saveobj(obj)
		  if ~obj.isDiskDataCurrent
			 obj = mapDataOnDisk(obj);
		  end
		  % 		  warning('off', 'MATLAB:structOnObject')
		  % 		  objStruct = struct(obj);
		  obj.data = [];
		  % 		  obj.eff = [];
		  % 		  obj.classHistory = [];
		 objByteStream = getByteStreamFromArray(obj);
	  end
   end
   methods (Static)
	  function obj = loadobj(objByteStream)
		 obj= getArrayFromByteStream(objByteStream);
	  end
   end
   
   
   
   
   
   
   
   
   
   % 	NET.addAssembly('System.Speech');
   % 	ss = System.Speech.Synthesis.SpeechSynthesizer;
   % 	ss.Volume = 100
   % 	Speak(ss,'You can use .NET Libraries in MATLAB')
   
   
   
   % 	imshowpair(imcomplement(mat2gray(mean(obj.preSample,3))), mat2gray(mean(obj.postSample,3)), 'ColorChannels',[2 0 1])
   
   
   
   
   
   
   
   
   
   
end














