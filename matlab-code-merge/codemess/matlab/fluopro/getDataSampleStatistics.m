function stat = getDataSampleStatistics(data, nSamples, extremeValuePercentTrim, outputDataType)
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
	  extremeValuePercentTrim = 10;
	  if nargin < 2
		 nSamples = 100;
	  end
   end
end


dataSample = getDataSample(data, nSamples);
inputDataType = class(dataSample);
sz = size(dataSample);
frameSize = sz(1:2);

stat.min = min(dataSample,[],3);
stat.max = max(dataSample,[],3);
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
   stat.mean = cast(statMean, outputDataType);
   stat.std = cast(statStd, outputDataType);
   stat.upperstd = cast(upperStd, outputDataType);
   stat.lowerstd = cast(lowerStd, outputDataType);
else
   stat.mean = statMean;
   stat.std = statStd;
   stat.upperstd = upperStd;
   stat.lowerstd = lowerStd;
end