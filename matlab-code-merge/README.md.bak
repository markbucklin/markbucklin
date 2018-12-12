# Calcium Imaging Code Cleanup

The goal is to merge/refactor code from a few highly overlapping and previously untracked repositories of calcium imaging video processing code. We are beginning with a function that has been used previously to wrap access to several other functions defined in the file 'getScicadelicPreprocessor.m'.

```matlab
function [nextFcn, varargout] = getScicadelicPreProcessor(tiffLoader, saveBW,saveRGB)
```

## Plan

## Steps in _getScicadelicPreProcessor.m_

### Workspace Configuration

- inputs
- outputs
  - storage path auto-naming (using date-time) --> logging
- work-directory
- other miscellaneous settings (i.e. _framesPerStep_\)

```matlab
TL = scicadelic.TiffStackLoader
videoFile = scicadelic.FileWrapper
```

### Processor Enumeration & Configuration

#### Image Pre-Processing operations

Using matlab 'system' interface, a bunch of image processing 'systems' are added which will be connected together manually later to form the processing pipeline. This is helpful on the way to a standardized interface for processing nodes, but is not quite there because of loose restrictions (or lack of a wrapper) around the number and type of inputs/outputs for the processing units.

```matlab
pp.sys.tiffloader = TL;
pp.sys.medianfilter = scicadelic.HybridMedianFilter;
pp.sys.contrastenhancer = scicadelic.LocalContrastEnhancer;
pp.sys.contrastenhancer.LpFilterSigma = 15; %7
pp.sys.contrastenhancer.UseInteractive = true;
pp.sys.motioncorrector = scicadelic.MotionCorrector;
pp.sys.temporalgradientstatisticcollector = scicadelic.TemporalGradientStatisticCollector;
pp.sys.temporalgradientstatisticcollector.DifferentialMomentOutputPort = true;
pp.sys.temporalgradientstatisticcollector.GradientRestriction = 'Positive Only'; %'Absolute Value';
pp.sys.temporalfilter = scicadelic.TemporalFilter;
pp.sys.temporalfilter.MinTimeConstantNumFrames = 6;% new
pp.sys.pixelintensitystatisticcollector = scicadelic.StatisticCollector('DifferentialMomentOutputPort',true);
pp.sys.temporalgradienttemporalfilter = scicadelic.TemporalFilter('MinTimeConstantNumFrames',6);
```

#### Output Normalization & Filtering operations

```matlab
INg = scicadelic.ImageNormalizer('NormalizationType','ExpNormComplement');
% INb = scicadelic.ImageNormalizer('NormalizationType','Geman-McClure');
% INr = scicadelic.ImageNormalizer('NormalizationType','Geman-McClure');
MF = pp.sys.medianfilter;
```

#### Specific Processor/Operation Sequencing

Operations can be sequenced/ordered to form 'pipeline' sections, and can be grouped for combining execution parameters (i.e. synchronous, or asynchronous and prioritizied) and also for efficient delegation across processing nodes/cores/devices. note: needed graph layout dataflow definition. todo: todo, do. additionally, need to add ability for simple buffering between pipelined/sequential steps or groups, or feedback buffers.

```matlab
feedThroughSystem = {... pp.sys.medianfilter pp.sys.contrastenhancer pp.sys.motioncorrector pp.sys.temporalfilter pp.sys.temporalgradienttemporalfilter }; otherSystem = {... pp.sys.temporalgradientstatisticcollector pp.sys.pixelintensitystatisticcollector INg % INr % INb }; allSystems = cat(1,{TL},feedThroughSystem,otherSystem);
```

### Resolve Properties of Input and Prepare Workspace to Accomodate

- size
- type
- counters
- timestamp
- initialize buffers
- truncate/expand space on ramdisk

### Intrafuncalatory Runtime-variable Delivery

Return handle to subfunctions that implement procedures on new data in chunkwise steps.

Signatures:

```matlab
function chunk = next()
    if ~finishedFlag
        [chunk.data, chunk.info] = processChunk();


        chunk.pixelStatistics = updatePixelStatistics();


        [fdata,udata] = generateColorCodedMarginalStatChannels();


        saveRGBMarginalStatFile(udata);
        saveBWRawIntensityFile(chunk.data);
        ...
        %more
        ...
    else
        %reset/restart...
    end

end


```

## Success

## Shower-Gown Celebration
