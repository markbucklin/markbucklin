%%
clear all
close all

nextFcn = getScicadelicPreProcessor();
%%
rCell ={};
bCell ={};
maskCell ={};
rThreshCell = {};
bThreshCell = {};
%%
rChunk = {};
lmChunk = {};
ccChunk = {};
flrCell = {};
rpCell = {};

%%
% t = tic;
% pauseMsg = msgbox('Pause', 'Click to Pause','non-modal');
% but = pauseMsg.Children(1);
% pauseMsg.UserData = true;
% pauseMsg.Callback = @ (src,evnt) set( src, 'UserData', ~src.UserData);
answer = inputdlg('process up to which frame number?');
goToFrame = str2num(answer{1});
idx=0;
while idx(end)<goToFrame
    [f,info,mstat,frgb,srgb] = nextFcn();
    if isempty(f)
        break
    end
    %     rgbCell{end+1} = frgb;
    FdynamicRed = squeeze(frgb(:,:,1,:)); % use RED
    FdynamicBlue = squeeze(frgb(:,:,3,:)); % use BLUE
    
    redThresh = 255 * graythresh( max(FdynamicRed,[],3) );
    blueThresh = 255 * graythresh( max(FdynamicBlue,[],3) );
    rThreshCell{end+1} = redThresh;
    bThreshCell{end+1} = blueThresh;
%     redThresh = 15; blueThresh = 15;
    
    Fmask = bsxfun(@or, (FdynamicRed > redThresh), FdynamicBlue > blueThresh);
    Fmask = applyFunction2D( @bwareaopen, Fmask, 8);
    Fmask = applyFunction2D( @bwmorph, Fmask, 'close');
%     rCell{end+1} = FdynamicRed;
%     bCell{end+1} =FdynamicBlue;
%     maskCell{end+1} = Fmask;
    
    if info.idx(1) >= 60
        hasRoi = any(any(Fmask,1),2);
        for k=1:size(info.idx)
            if hasRoi(k)
                rp = regionprops(Fmask(:,:,k),{'Area','BoundingBox','Centroid','PixelIdxList'});
%                 idx = info.idx(k);
                rpCell{info.idx(k)} = rp;
                %             flr = RegionOfInterest(rp, 'FrameIdx',idx ,'FrameSize', [1024 1024]) ;
                %             flrCell{idx} = flr;
                
                %             idx = info.idx(k);
                %             flr = FrameLinkedRegion(rp, 'FrameIdx',idx ,'FrameSize', [1024 1024]) ;
                %             flrCell{idx} = flr;
            end
        end
    end
    %     if any(Fmask(:))
    %         cc = bwconncomp(any(Fmask,3));
    %         ccChunk{end+1} = cc;
    %         %         lmChunk{end+1} = applyFunction2D(@bwlabel, Fmask);
    %         %         rChunk{end+1} = RegionOfInterest( any(Fmask,3));
    %     end
    idx = info.idx;
end
% imrgbplay( cat(4, rgbCell{:}))

% cat34 = @(fc) permute( cat(3,fc{:}),[1 2 4 3]);
% Frmaskb = cat(3, cat34(rCell), 200*uint8(cat34(maskCell)), cat34(bCell));
% imrgbplay(Frmaskb)

%% Extract regionprops() structs using builtin matlab function
% rSingle = cat(1,rChunk{:});
frameUseIdx = 60:numel(rpCell);
allRegionProps = cat(1, rpCell{frameUseIdx});
numRegionsInFrame = cellfun( @numel, rpCell(frameUseIdx));
numSingleRegions = sum( numRegionsInFrame);
regionFrameIdx = cell(numel(frameUseIdx),1);
for k=1:numel(frameUseIdx)
   regionFrameIdx{k} = repmat(frameUseIdx(k), numRegionsInFrame(k), 1);
end
allRegionPropFrameIdx = cat(1,regionFrameIdx{:});
rpArea = [allRegionProps.Area];
minRegionArea = 50;
maxRegionArea = 500;
regionSizeMask = bsxfun(@and, (rpArea >= minRegionArea) , (rpArea <= maxRegionArea));
allRegionProps = allRegionProps(regionSizeMask);
allRegionPropFrameIdx = allRegionPropFrameIdx(regionSizeMask);
save('SingleFrame-RegionProps.mat','allRegionProps', 'allRegionPropFrameIdx');

%% Make the "RegionOfInterest" objects for each frame (->many)
rSingle = RegionOfInterest(allRegionProps);
set(rSingle,'FrameSize',[1024 1024]);
for k=1:numel(rSingle)
    rSingle(k).FrameIdx = allRegionPropFrameIdx(k);
end
% rSingle = rSingle([rSingle.Area] < 500);

set( rSingle, 'GroupingSimilarityMin', .10);
R = reduceRegions(rSingle);
set(R,'FrameSize',[1024 1024]);
R = reduceSuperRegions(R);

% R = reduceSuperRegions(rSingle, maxCentroidSeparation, maxEdgeSeparation)
% (or)
% set(rSingle, 'MaxCentroidSeparation', 10)
% set(rSignle, 'MaxEdgeSeparation', 45)
% set(rSingle, 'MinSufficientOverlap', .75)
% R = reduceSuperRegions(rSingle);

% show(R)
%%
Frgb = readBinaryData();

% Frgb = cat(4, rgbCell{:});
% or readBinaryData()

%% Deleting ROIs
set(R,'ShowMode','patch')
hs = show(R)
set( hs.hpatch, 'ButtonDownFcn', @(src,evnt) delete(src.UserData))
R = R(isvalid(R))

%% ROI lines on top of processed video
set(R,'ShowMode','image')
hr = show(R);
hrgb = imrgbplay(Frgb);
set(hr.line(isvalid(hr.line)),'Parent', hrgb.ax)

%%

traceOutRed = R.makeTraceFromVid(squeeze(Frgb(:,:,1,60:end)));
% traceOutRed = R.makeTraceFromVid(single(squeeze(Frgb(:,:,1,60:end))));
% traceOutBlue = R.makeTraceFromVid(single(squeeze(Frgb(:,:,3,:))));
traceOutBlue = R.makeTraceFromVid(squeeze(Frgb(:,:,3,60:end)));

figure, plot(bsxfun( @plus, traceOutRed(60:end,randi([1 size(R,1)],1,100)), 3.*(0:99)))
figure, plot(bsxfun( @plus, traceOutBlue(60:end,randi([1 size(R,1)],1,100)), 3.*(0:99)))
% figure,subplot(2,1,1),plot(bsxfun( @plus, traceOutRed(1000:end,randi([1 size(R,1)],1,100)), 3.*(0:99)))
% subplot(2,1,2),plot(bsxfun( @plus, traceOutBlue(1000:end,randi([1 size(R,1)],1,100)), 3.*(0:99)))

save('ROIs (2files)','R')

save('RedTraceROIs','traceOutRed')
save('BlueTraceROIs','traceOutBlue')

% load('ROIs (2files).mat')

% R(4).TraceType

% figure, plot(R(4).TraceType.allpixels)
% figure, plot(R(4).TraceType.uniquepixels)
% imrgbplay(Frgb)
%%

getStatePredictor(traceOutRed,20)
%% ALTERNATIVE REGIONS
% rp = regionprops(any(Fmask,3),{'Area','BoundingBox','Centroid','PixelIdxList'});
% hasReg = any(any(Fmask,1),2);
% for k=1:size(info.idx)
%     if hasReg(k)
%         rp = regionprops(Fmask(:,:,k),{'Area','BoundingBox','Centroid','PixelIdxList'});
%         idx = info.idx(k);
%         flr = FrameLinkedRegion(rp, 'FrameIdx',idx ,'FrameSize', [1024 1024]) ;
%         flrCell{idx} = flr;
%     end
% end
% lr = LinkedRegion(rp)

% pr = PropagatingRegion( flr );

% RP = RegionPropagation()