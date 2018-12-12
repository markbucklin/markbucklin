
%%


%%
brainAVI = VideoReader(uigetfile('*.avi'));
% mouseAVI = VideoReader('mouseoverlay1.avi');
overlayAVI = VideoWriter('Overlay Composite (mouse263).avi', 'Uncompressed AVI');
set(overlayAVI,'FrameRate',24);
open(overlayAVI);

%%

for k=1:8, imshow(brainAVI.readFrame()); end


%%
outputFrameSize = [1080 1920 3];
brainFrameSize = [brainAVI.Height brainAVI.Width];
% mouseFrameSize = [mouseAVI.Height mouseAVI.Width];
mouseFrameSize = size(f(1).cdata);

%%
rowStart = (outputFrameSize(1)-brainFrameSize(1))/2;
brainColumnStart = 300;
mouseColumnStart = (outputFrameSize(2)-brainFrameSize(2));
brainIdx = { rowStart + (1:brainFrameSize(1))', brainColumnStart + (1:brainFrameSize(2)), reshape(1:3,1,1,3)};
mouseIdx = { rowStart + (1:mouseFrameSize(1))', mouseColumnStart + (1:1024), reshape(1:3,1,1,3)};
blankFrame = @() zeros(outputFrameSize,'uint8');

%%
k=0;

%%
while brainAVI.hasFrame() %mouseAVI.hasFrame() &&
    %%
    k = k+ 1;
    fprintf('Frame %d\n',k);
    %     mouseFrame = mouseAVI.readFrame();
    mouseFrame = f(k).cdata;
    brainFrame = brainAVI.readFrame();
    
    %%
    outputFrame = blankFrame();
    a = 0.8 * ~all(mouseFrame == 0, 3);
    outputFrame(brainIdx{:}) = outputFrame(brainIdx{:}) + brainFrame;
    outputFrame(mouseIdx{:}) = uint8(bsxfun(@times, a, double(mouseFrame)) + bsxfun(@times, (1-a), double(outputFrame(mouseIdx{:}))));
    %     if ~exist('hIm','var')
    %         hIm = handle(imshow(outputFrame, 'InitialMagnification','fit'));
    %     else
    %         hIm.CData = outputFrame;
    %     end
    
    %%
    writeVideo(overlayAVI, outputFrame);
    
end

%%
close(overlayAVI)
