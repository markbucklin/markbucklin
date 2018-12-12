Run processFast() function, returning file-names that can be used to restore data, along with RegionOfInterest class ROIs. 

At the MATLAB command prompt, type:


>> processFast


When asked, select all tiff files (input) recorded during a single continuous imaging session. Output files will be saved in the same directory as the input.  Alternatively, type the following to keep output in the current workspace to work with after processing completes:


>> [allVidFiles, R, info, uniqueFileName] = processFast();


To automate the process for multiple imaging sessions, the tiff file names for each imaging session can be passed in a cell array as the first input argument to the processFast function. Regions of Interest (ROIs) can be visualized by typing the following command, then left- and/or right-clicking on individual ROIs to show mean signal traces:


>> show(R)


Left-click adds one ROI trace at a time to the current axes, replacing the current trace. Right-click adds multiple ROI traces to the current  axes. Middle-click clears all traces from the current axes.

Additional functionality is demonstrated in the runWideFieldFluorescence_demo.m file, and is accessible by typing:


>> help processFast
>> help RegionOfInterest
>> doc processFast