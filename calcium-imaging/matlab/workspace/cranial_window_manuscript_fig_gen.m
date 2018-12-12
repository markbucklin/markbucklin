options = struct(...
    'writeGray', false,...
    'writeRGB', false,...
    'numFramesForLabeling', 2048);



%% Set up Directories and Path
dataDir = establishDir('DATA_SOURCE_ROOT', 'Select Data Source Root (with .tif files)');
exportDir = establishDir('FIGURE_EXPORT_ROOT');
dateStamp = datestr(now,'(yyyymmmdd_HHMMPM)');



%% Set up Image File Source (Tiff Files)
tiffList = dir(fullfile(dataDir,'*.tif'));
tiffLoader = scicadelic.TiffStackLoader(...
	'FileDirectory',dataDir,...
	'FileName', {tifList.name});


%% Configuration/Options (todo)



%% Set up Pre-Processing Pipeline
[next,pp] = getScicadelicPreProcessor(tiffLoader, options.writeGray, options.writeRGB);



%% Specify Signals Extracted from Each Chunk --> {'signalname': source_variable}
getInputSignals = @(nextOut) struct(...
	'intensity', nextOut.f,...
	'red', nextOut.srgb.marginalKurtosisOfIntensity,...
	'blue', nextOut.srgb.marginalSkewnessOfIntensityChange);


%% Setup Cell Segmentation and Extractionator 
report = findRegionLabels( next, options.numFramesForLabeling)







%% Get Session Attributes
numFrames = tiffLoader.NumFrames;
frameSize = tiffLoader.FrameSize;
numPixels = prod(frameSize);
numChunks = tiffLoader.NumSteps;




%% Do a Pre-Run to Find ROIs (mask/labelmatrix)






%% Process Files -> Extract traces from ROIs & identify Groups







%% Clean (unchunkify) and Export ROIs -> save in 'roi' structure





%% Return Functions for Trace Normalization and Roi Visualization



