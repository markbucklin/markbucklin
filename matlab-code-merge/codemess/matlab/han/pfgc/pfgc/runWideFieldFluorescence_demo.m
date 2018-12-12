%% RUN WIDE-FIELD FLUORESCENCE
% Run the function that will process example data files. Select all Tiff files at once by selecting
% the first Tiff file, then holding SHIFT while clicking on the last Tiff file.



%% PROCESS INPUT
% Run processFast() function, returning file-names that can be used to restore data, along with
% RegionOfInterest class ROIs. You can also just type >> processFast(); and files will be saved
[allVidFiles, R, info, uniqueFileName] = processFast();



%% VISUALIZE OUTPUT
% Usesthe methods defined by the RegionOfInterest class to aid in the visualization of identified
% ROIs and their activity over time

try
   % SHOW ROIs WITH DEFAULT COLORS
   % show(R);
   % snapnow
   close(h.fig)
   
   % LOAD VIDEO DATA FROM CACHED BINARY FILES
   data = readBinaryData(allVidFiles);
   
   % SHOW WITH IMAGE OVERLAY - CLICK ON ROIs TO SHOW TRACES
   showAsOverlay(R, range(data,3)*2.5 + 25);
   snapnow
   close(h.fig)
   
   % MANIPULATE COLORS
   set(R, 'Color', [0 0 .9])
   set(R, 'Transparency', .65)
   
   % PICK A RANDOM ROI
   roiIdx = randi([1 numel(R)]);
   roiBinVec = true(numel(R),1);
   roiBinVec(roiIdx) = false;
   
   % MEASURE DISTANCE BETWEEN RANDOMLY PICKED ROI & ALL OTHERS
   thisR = R(roiIdx);
   otherR = R(roiBinVec);
   roiDistance = centroidSeparation(thisR, otherR);
   
   % SET COLORS DEPENDENT ON DISTANCE
   rdMean = mean(roiDistance);
   set( otherR( (roiDistance > rdMean/2) & (roiDistance < rdMean)), 'Color', [0 .6 0])
   thisR.Color = [.9 0 0];
   
   % SHOW ROIs IN PATCH MODE - CLICK ON ROIs TO SHOW TRACES
   set(R, 'ShowMode', 'patch')
   show(R)
   snapnow
   close(h.fig)
   
   % SHOW AGAIN WITH IMAGE OVERLAY  - CLICK ON ROIs TO SHOW TRACES
   showAsOverlay(R, range(data,3)*2.5 + 25);
   snapnow
   close(h.fig)
   
   % SHOW DYNAMIC VIDEO OVERLAY
   % showAsOverlay(R, data*2.5 + 25)
   
   
catch
   
end

% ACCESS DATA STORED IN ROI DIRECTLY
x = [R.Trace];
stripSpace = .05 * mean(range(x,1),2);
spacedTrace = bsxfun(@plus, x, stripSpace.*(0:numel(R)-1));
plot(spacedTrace); snapnow
bw = createMask(R);
imshow(bw); snapnow
lm = createLabelMatrix(R);
imshow(label2rgb(lm)); snapnow

% ACCESS REGION-OF-INTEREST DOCUMENTATION TO SEE AVAILABLE PROPERTIES & METHODS
doc RegionOfInterest



%% LOAD UNSCALED VIDEO FILES & PLAY IN MATLAB
% You will need to select the uint16 type binary files from the \VidFiles folder. You may select
% more than one, as many as you like. They will be read into your workspace (as long as there is
% available RAM) and can then be saved as a TIFF. Also you can use built-in MATLAB tools such as the
% VideoWriter to save as compressed or uncompressed AVI, MP4, etc. We will also apply a recursive
% temporal filter to aid visualization. 


% dataUnscaled = readBinaryData();
% n0 = 2;
% a = exp(-1/n0);
% ykm1 = dataUnscaled(:,:,1);
% for k=2:size(dataUnscaled,3)
%    yk = a*ykm1 + (1-a)*dataUnscaled(:,:,k);
%    dataUnscaled(:,:,k) = yk;
%    ykm1 = yk; 
% end
% implay(dataUnscaled)








