
%%
[nextFcn, pp] = getScicadelicPreProcessor();
[f,info,mstat,frgb,srgb] = nextFcn();
Fbw{1} = f;
Srgb(1) = oncpu(srgb);
T{1} = info.timestamp;


%%
k=1;
while k < 300
    k = k+1;
    [f,info,mstat,frgb,srgb] = nextFcn();
    Fbw{k} = f;
    T{k} = info.timestamp;
    %     Srgb(k) = oncpu(srgb);
    disp(k);
end

%%

bw = cat(3,Fbw{:});

%%
bwMin = min(bw,[],3);
bwMean = mean(bw,3);
bwPerc = prctile(bw,1:100,3);
bwLow = mean(bwPerc(:,:,1:10),3);
bwPerc98Tenths = prctile(bw,98:.1:99.9, 3);
bwHigh = mean(bwPerc98Tenths,3) + 10.*mean(diff(bwPerc98Tenths,[],3),3);

%%
bwLoggy = bsxfun(@minus, log1p(bw+mean(bwMean(:))), log1p(bwLow) ) ;
imscplay(bwLoggy);

hImsc.fig.Colormap = gray(4096);

%%
% bwClim = hImsc.ax.CLim;
% bwShift = -bwClim(1);
% bwScale = 1/diff(bwClim);
% bw = min(1, max(0, bwScale * (bw + bwShift)));
% bw = permute( bw, [1 2 4 3]);
bwClim = hImsc.ax.CLim;
bwShift = -bwClim(1);
bwScale = 1/diff(bwClim);
bwLoggy = min(1, max(0, bwScale * (bwLoggy + bwShift)));
bwLoggy = permute( bwLoggy, [1 2 4 3]);


%%

filename = ['BW' ,datestr(now,'HHMMSS')];
profile = 'MPEG-4'; % 'Motion JPEG AVI'
writerObj = VideoWriter(filename,profile);
writerObj.FrameRate = 24;
writerObj.Quality = 95;
open(writerObj)

writeVideo(writerObj, bw);

close(writerObj)

%%
C = colorui([1 0 0],'Choose color')