function t = readHamamatsuTimeFromStart(imageDescriptionTag)
warning('readHamamatsuTimeFromStart.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
 

[idLines,~] = strsplit(imageDescriptionTag,'\r\n');
tfsLine = idLines{strncmp(' Time_From_Start',idLines,12)};
tfsNum = sscanf(tfsLine,' Time_From_Start = %d:%d:%f');
t = tfsNum(1)*3600 + tfsNum(2)*60 + tfsNum(3);
