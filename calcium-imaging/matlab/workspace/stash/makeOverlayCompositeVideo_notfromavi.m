
%%


%%
% brainAVI = VideoReader(uigetfile('*.avi'));
% % mouseAVI = VideoReader('mouseoverlay1.avi');
% overlayAVI = VideoWriter('Overlay Composite (mouse263).avi', 'Uncompressed AVI');
% set(overlayAVI,'FrameRate',24);
% open(overlayAVI);

%%

% for k=1:8, imshow(brainAVI.readFrame()); end


%%
outputFrameSize = [1080 1920 3];
% brainFrameSize = [brainAVI.Height brainAVI.Width];
% mouseFrameSize = [mouseAVI.Height mouseAVI.Width];
brainFrameSize = size(bw(:,:,1));
mouseFrameSize = size(animat.rgb(:,:,:,1));

mouseAlphaMax = 1.0;

%%
rowStart = (outputFrameSize(1)-brainFrameSize(1))/2;
rgbColumnStart = 0;
mouseColumnStart = 300; %(outputFrameSize(2)-brainFrameSize(2));
bwColumnStart = outputFrameSize(2)-brainFrameSize(2);
rgbIdx = { rowStart + (1:brainFrameSize(1))', rgbColumnStart + (1:brainFrameSize(2)), reshape(1:3,1,1,3)};
mouseIdx = { rowStart + (1:mouseFrameSize(1))', mouseColumnStart + (1:1024), reshape(1:3,1,1,3)};
bwIdx = { rowStart + (1:brainFrameSize(1))', bwColumnStart + (1:brainFrameSize(2)), reshape(1:3,1,1,3)};

blankFrame = @() zeros(outputFrameSize,'double');

%%
k=0;
N = size(rgb,4);

%% RGB and BW Blending Function
outputMid = outputFrameSize(2)/2 + 1;
brainFrameOvershoot = brainFrameSize(2) - outputMid;
outputColIdx = 1:outputFrameSize(2);
rgbColAlpha = 1 - max(0, 1 + (rgbIdx{2} - outputMid)/brainFrameOvershoot)/2;
bwColAlpha =  1 - max(0, 1 + (-bwIdx{2} + outputMid)/brainFrameOvershoot)/2;
% brainImOverlap = max( 0 , (brainFrameSize(2) - outputMid) - abs(colIdx - outputMid))

%%
while k<N %mouseAVI.hasFrame() &&
    %%
    k = k+ 1;
    fprintf('Frame %d\n',k);
    %     mouseFrame = mouseAVI.readFrame();
    %     mouseFrame = f(k).cdata;
    %     brainFrame = brainAVI.readFrame();
    
    %%
    outputFrame = blankFrame();    
    outputAlpha = 0.* outputFrame(:,:,1);
    mouseFrame = im2double(animat.rgb(:,:,:,k));
    rgbFrame = im2double(rgb(:,:,:,k));
    bwFrame = fliplr( im2double(repmat( bw(:,:,k), 1, 1, 3)));
    
    %%   
    outputFrame(rgbIdx{:}) = bsxfun(@plus,...
        bsxfun(@times, 1-rgbColAlpha, outputFrame(rgbIdx{:})),...
        bsxfun(@times, rgbColAlpha, rgbFrame));
    outputFrame(bwIdx{:}) = bsxfun(@plus,...
        outputFrame(bwIdx{:}), ...
        bsxfun(@times, bwColAlpha, bwFrame));
    
    %%
    mouseAlpha = mouseAlphaMax * ~all(mouseFrame == 0, 3);    
    outputFrame(mouseIdx{:}) = bsxfun(@plus,...
        bsxfun(@times, 1-mouseAlpha, double(outputFrame(mouseIdx{:}))),...
        bsxfun(@times, mouseAlpha, mouseFrame));
    
    % blend
    %     outputFrame(bwIdx{:}) = outputFrame(bwIdx{:}) + bwFrame;
    
    %     if ~exist('hIm','var')
    %         hIm = handle(imshow(outputFrame, 'InitialMagnification','fit'));
    %     else
    %         hIm.CData = outputFrame;
    %     end
    
    %%
    writeVideo(overlayAVI, im2uint8(outputFrame));
    
end

%
close(overlayAVI)

% 
% %%
%     %     r = blankFrame();
%     %     b = blankFrame();
%     %     % blend over onto separate blanks
%     %     r(rgbIdx{:}) = bsxfun(@times, 1-rgbColAlpha, r(rgbIdx{:})) + bsxfun(@times, rgbColAlpha, rgbFrame);
%     %     b(bwIdx{:}) = bsxfun(@times, 1-bwColAlpha, b(bwIdx{:})) + bsxfun(@times, bwColAlpha, bwFrame);
%     %     ra = 0.*r(:,:,1);
%     %     ba = 0.*b(:,:,1);
%     %     ra(rgbIdx{1:2}) = bsxfun(@times, ones(size(rgbIdx{1})), rgbColAlpha);
%     %     ba(bwIdx{1:2}) = bsxfun(@times, ones(size(bwIdx{1})), bwColAlpha);
%     %     % blend xor together
%     %     imshow(blend.xor(r,ra,b,ba))
%     %
%     %
%     outputFrame(rgbIdx{:}) = bsxfun(@plus,...
%         bsxfun(@times, 1-rgbColAlpha, outputFrame(rgbIdx{:})),...
%         bsxfun(@times, rgbColAlpha, rgbFrame));
%     outputFrame(bwIdx{:}) = bsxfun(@plus,...
%         outputFrame(bwIdx{:}), ...
%         bsxfun(@times, bwColAlpha, bwFrame));
%     
%     
% %     S = blendOver(...
% %         colorAlphaStruct( outputFrame(rgbIdx{:}), outputAlpha(rgbIdx{1:2})),...
% %         colorAlphaStruct( rgbFrame, rgbColAlpha));
% %     outputFrame(rgbIdx{:}) = S.C;
% %     outputAlpha(rgbIdx{1:2}) = S.a;
% %     S = blendOver( ...
% %         colorAlphaStruct( outputFrame(bwIdx{:}), outputAlpha(bwIdx{1:2})),...
% %         colorAlphaStruct(bwFrame, bwColAlpha));    
% %     outputFrame(bwIdx{:}) = S.C;
% %     outputAlpha(bwIdx{1:2}) = S.a;
%     
%%
% blendOver = @(dst,src) bsxfun(@plus, bsxfun(@times, (1-a), dst) , bsxfun(@times, a, src));
% blendOver = @(dst,src) bsxfun(@plus, bsxfun(@times, (1-a), dst) , bsxfun(@times, a, src));
% premultipliedBlendOver = @(dst,src) struct(...
%     'c', src.c + dst.c*(1-src.a),...
%     'a', src.a + dst.a*(1-src.a));
% blendOver = @(dst,src) struct(...
%     'C', bsxfun(@rdivide, ...
%     bsxfun(@plus, bsxfun(@times, src.C , src.a), bsxfun(@times, bsxfun(@times, dst.C , dst.a) , (1-src.a))),...
%     bsxfun(@plus, src.a, bsxfun(@times, dst.a, (1-src.a)))),...
%     'a', bsxfun(@plus, src.a, bsxfun(@times, dst.a, (1-src.a))) );
% blendOverPremultiplied = @(dst,src) struct(...
%     'c', bsxfun(@plus, src.c, bsxfun(@times, dst.c, (1-src.a))),...
%     'a', bsxfun(@plus, src.a, bsxfun(@times, dst.a, 1-src.a)));
% colorAlphaStruct = @(C,a) struct('C',C,'a',a);
% premultiplyAlpha = @(src) struct(...
%     'C', src.C,...
%     'a', src.a,...
%     'c', bsxfun(@times, src.a, src.C));
% 
% blendXorPremultiplied = @(dst,src) struct(...
%     'c', bsxfun(@plus, ...
%     bsxfun(@times, src.c, (1-dst.a)),...
%     bsxfun(@times, dst.c, (1-src.a))),...
%     'a', bsxfun(@plus,...
%     bsxfun(@plus, src.a, dst.a),...
%     -2 .* bsxfun(@times, dst.a, src.a)));
% % 
% % 'C', bsxfun(@rdivide, ...
% %     bsxfun(@plus, bsxfun(@times, src.C , src.a), bsxfun(@times, bsxfun(@times, dst.C , dst.a) , (1-src.a)) ),...
% %     bsxfun(@plus, src.a, bsxfun(@times, dst.a, (1-src.a))),...
% %     'a', bsxfun(@plus, src.a, bsxfun(@times, dst.a, (1-src.a)))));
% % 'c', bsxfun(@plus, bsxfun(@times, src.c, src.a), bsxfun(@times, dst.c, (1-src.a))),...
% caStruct2RGB = @(s) bsxfun(@rdivide, s.c , s.a);
% CaStruct2RGB = @(s) s.c;
% 
% % blend.over = blendOver;
% blend.xor = @(C1,a1,C2,a2) ...
%     caStruct2RGB( ...
%     blendXorPremultiplied( ...
%     premultiplyAlpha( colorAlphaStruct(C1,a1)),...
%     premultiplyAlpha( colorAlphaStruct(C1,a1))));
