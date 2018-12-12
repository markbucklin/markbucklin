classdef DataSample
   
   
   
   properties
	  nSequentialSamples
	  nScatteredSamples
	  sampleIdx
	  dataType
   end
   properties % (SetAccess = protected)
	  data
	  info
	  stat
   end
   properties % (Dependent)
	  sequentialIdx
	  sequentialData
	  sequentialInfo
	  scatteredIdx
	  scatteredData
	  scatteredInfo
   end
   properties % (Hidden)
	  isSequentialIdx
	  isScatteredIdx
   end
   properties % misplaced?
	  eff
   end
   
   
   methods
	  function obj = DataSample(varargin)
		 if nargin >1
			propSpec = varargin(:);
			if ischar(propSpec{1})
			   fillPropsFromPropValPair(propSpec)
			end
		 elseif nargin == 1
			structSpec = varargin{1};
			if isstruct(structSpec)
			   fillPropsFromStruct(structSpec)
			end
		 end
		 function fillPropsFromPropValPair(propSpec)
			if ~isempty(propSpec)
			   if numel(propSpec) >=2
				  for k = 1:2:length(propSpec)
					 obj.(propSpec{k}) = propSpec{k+1};
				  end
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
	  function varargout = getDataSample(obj, dinput, varargin)
		 % >> [obj, data] = getDataSample( obj, obj.data, nSampleFrames, nSequentialSamples);
		 % TODO: sample from array of FluoProFunctions
		 % DETERMINE NUMBER OF FRAMES TO SAMPLE		 
		 if isnumeric(dinput)
			sz = size(dinput);
			N = size(dinput,ndims(dinput));
			getSampleFcn = @numericArrayFcn;
		 elseif isstruct(dinput)
			N = numel(dinput);
			sz = size(dinput(1).cdata);
			getSampleFcn = @structArrayFcn;
		 elseif strcmpi(class(dinput), 'scicadelic.TiffStackLoader')
			N = dinput.NFrames;
			sz = dinput.frameSize;
			getSampleFcn = @systemFcn;
		 else
			warning('Check input')
		 end
		 nrows = sz(1);
		 ncols = sz(2);
		 switch numel(varargin)
			case 0
			   if isempty(obj.nScatteredSamples)
				  obj.nScatteredSamples = min(N, obj.minSampleNumber);			  
			   end
			   if isempty(obj.nSequentialSamples)
				  obj.nSequentialSamples = 1;
			   end
			case 1 % 3rd dimension spans across time pseudo-randomly
			   obj.nScatteredSamples = ceil(varargin{1});
			   obj.nSequentialSamples = 1;
			case 2
			   obj.nScatteredSamples = ceil(varargin{1});
			   obj.nSequentialSamples = varargin{2};
		 end
		 
		 if isempty(obj.scatteredIdx)
			jitter = floor(N/obj.nScatteredSamples);
			obj.scatteredIdx = round(linspace(1, N-jitter, obj.nScatteredSamples)')...
			   + round( jitter*rand(obj.nScatteredSamples,1));
		 end
		 if isempty(obj.nSequentialSamples)
			obj.nSequentialSamples = 1;
		 end
		 obj.sequentialIdx = 1:obj.nSequentialSamples;
		 
		 dataSample = feval(getSampleFcn);
		 obj.data = dataSample;
		 if nargout > 1
			varargout{1} = obj;
			varargout{2} = dataSample;
		 else
			varargout{1} = obj;
		 end
		 function dataSample = numericArrayFcn()
			if obj.nSequentialSamples <= 1
			   switch ndims(dinput)
				  case 3
					 dataSample = dinput(:,:,obj.scatteredIdx);
				  case 4
					 dataSample = dinput(:,:,:,obj.scatteredIdx);%TODO: for MultiChannel
				  otherwise
					 dataSample = dinput;
			   end
			else
			   dataSample = zeros( nrows, ncols,...
				  obj.nScatteredSamples, ...
				  obj.nSequentialSamples,...
				  'like',dinput);
			   for k=1:numel(obj.scatteredIdx)
				  seqIdx = (obj.scatteredIdx(k) + (0:(obj.nSequentialSamples-1)));
				  switch ndims(dinput)
					 case 3
						dataSample(:,:,k,:) = dinput(:,:,seqIdx);
					 case 4
						dataSample(:,:,:,k,:) = dinput(:,:,:,seqIdx);%TODO: for MultiChannel
					 otherwise
						dataSample = dinput;
				  end
			   end
			end
		 end
		 function dataSample = structArrayFcn()
			dataSample = dinput(obj.scatteredIdx);
		 end
		 function dataSample = systemFcn()
			reset(dinput)
			dataSample = zeros( nrows, ncols,...
			   obj.nScatteredSamples, ...
			   obj.nSequentialSamples,...
			   dinput.outputDataType);
			for k = 1:obj.nScatteredSamples
			   setCurrentFrame(dinput, obj.scatteredIdx(k))
			   for kSeq=1:obj.nSequentialSamples
				  [dataSample(:,:,k, kSeq),~] = step(dinput);
			   end
			end			
		 end		
	  end
	  function obj = getDataSampleStatistics(obj, extremeValuePercentTrim, outputDataType)
		 % Returns pixel-by-pixel statistics (min,max,mean,std) over time, using a trimmed-mean to calculate the mean and
		 % standard deviation (builtin function trimmean()).
		 %
		 % IMPORTANT NOTE: Currently mean and std calculations are performed in the same datatype as the input which will
		 % likely compound rounding errors for integer datatypes
		 
		 if nargin < 3
			outputDataType = [];
			%    outputDataType = class(data);
			%    outputDataType = 'single';
			%    outputDataType = 'double';
			if nargin < 2
			   extremeValuePercentTrim = 25;
			   % 			   if nargin < 2
			   % 				  nSamples = 250;
			   % 			   end
			end
		 end
		 
		 % TODO: could implement array  here, potentially with pct/parfor, atleast after removing data
		 % 		 dataSample = getDataSample(obj, obj.data, nSamples);
		 dataSample = obj.data;
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
	  function obj = getDataSampleEff(obj, diskRadius)
		 
		 
			F = obj.data;
			propname = 'eff';
		 
		 
		 % FIND MAX PEAKS IN ENTROPY-FILTERED STACK, MINIMIZED OVER TIME
		 if nargin < 2
			diskRadius = 5;%floor(mean(obj.expectedCellPixelDiameter.*sqrt(2)/pi));
		 end
		 efNhood = getnhood(strel('disk', diskRadius));
		 [nrows, ncols, N] = size(F);
		 efF = zeros(nrows,ncols,N,'uint8');
		 frameEntropy = zeros(1,1,N);
		 parfor k=1:N %TODO. check use pct global
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
			disp(me.message)
			keyboard
		 end
	  end	
   end
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
   
end