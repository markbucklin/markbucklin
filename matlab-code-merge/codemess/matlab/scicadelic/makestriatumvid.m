%%
filename = 'Amph-Baseline roigen3-overlay-magenta (minarea 10).mp4';
vidProfile = 'MPEG-4';
writerObj = VideoWriter(filename,vidProfile);
writerObj.FrameRate = 20;
writerObj.Quality = 85;
open(writerObj)


% READ DATA
fid = fopen('processedvideooutput.bin','r');
data = reshape(fread(fid,inf, '*uint16'), 1024,1024,[]);

CE = scicadelic.LocalContrastEnhancer;
CE.UseInteractive = true;

obj = scicadelic.RoiGenerator;
obj.OutputType = 'Mask';
obj.MaxExpectedDiameter = 100;
obj.MinRoiPixArea = 10;
obj.MaxRoiPixArea = 2500;
obj.UseInteractive = true;


%%

tune(CE, sampledata);

tune(obj, sampledata);

%%
%%
% DEFINE INTENSITY LIMITS
lims(1) = 2900;
lims(2) = 45000;
a = uint16((lims(2)-lims(1))/255);
b = uint16(lims(1));



idx = 0; 
k=0;
bufSize = 8;
% [nRows, nCols, N] = size(data);
nRows = 1024;
nCols = 1024;
N = TL.NumFrames;
benchtime = zeros(N,1);
% bw = false(nRows, nCols, N);
% vid = zeros(nRows, nCols, 3, N, 'uint8');
hWait = waitbar(0,'processing time');
while idx(end) < N
	tStart = hat; 
	k=k+1;
	idx = idx(end)+(1:bufSize);
	idx = idx(idx<=N);
	
	for kFrame = 1:numel(idx)
		cdata(:,:,kFrame) = step(TL);
	end
% 	cdata = data(:,:,idx);
gdata = gpuArray(cdata);
gdata = step(CE, gdata);
[gdata, info(k).motion] = step(MC, gdata);
for kFrame = 1:numel(idx)
	bw(:,:,kFrame) = gather(step(obj, gdata(:,:,kFrame)));
	LR{idx(kFrame)} = obj.LinkedRegionObj;
end
cdata = gather(gdata(:,:,1:kFrame));

ss(:,:,k) = gather(obj.SegmentationSum);
% LR{k} = obj.LinkedRegionObj;

fprintf('storing frame %i to %i\n',idx(1), idx(end))
data(:,:,idx) = cdata(:,:,1:numel(idx));

	% 	bw(:,:,idx) = gather(step(obj, data(:,:,idx)));
% 	bw = gather(step(obj, cdata));
bw = bw(:,:,1:numel(idx));
if ndims(bw) < 4
	bw = uint8(permute(shiftdim(bw, -1), [2 3 1 4])).*200;
else
	bw = uint8(bw).*200;
end
	vdata = (cdata-b)./a;
	vdata = permute(shiftdim(vdata, -1), [2 3 1 4]);
	
	nIdx = numel(idx);
	vid = cat(3, bw, uint8(vdata), bw);
	for kFrame = 1:size(vid,4)
		writeVideo(writerObj, vid(:,:,:,kFrame));
	end
	t = hat - tStart;
	benchTime(k) = t;
	waitbar(idx(end)/N, hWait, sprintf('processing time: %-03.3g ms/frame',t*1000/bufSize));
end
close(hWait)


close(writerObj);


% data = data-b;
% data = data./a;
% data = uint8(data);
% data = permute(shiftdim(data, -1), [2 3 1 4]);
% bw = uint8(permute(shiftdim(bw, -1), [2 3 1 4])).*220;

% saveData2Mp4(vid, 'Amph-etamine roigen2-overlay-magenta.mp4')


% vid = zeros(nRows, nCols, 3, nFrames, 'uint8');
% vid = permute(cat(4,...
% 	uint8(bw).*uint8(200),...
% 	uint8( idivide(data-b, a)),...
% 	uint8(bw).*uint8(200)),...
% 	[1 2 4 3]);







% vid(reshape(bw, size(bw,1), size(bw,2), 1, [])) = uint8(220);
% vid(:,:,3,:) = vid(:,:,1,:);
% vid(:,:,2,:) = uint8( idivide(data-b, a));













% parfor k=1:size(databaseline,3)
% 	%GREEN
% 	F = databaseline(:,:,k);
% 	F = medfilt2(F);
% 	F = uint16(a.*(single(F) - b));
% 	
% 	
% 	
% 	vid(:,:,2,k) = uint8(F);
% 		
% end
% 
% 
% 
% parfor k=1:numel(CC)	
% 	% 	lm = sparse(logical(labelmatrix(CCbaseline)));
% 	cc = CC(k);
% 	nframes = numel(cc.Frames);
% 	lm = zeros(1024,1024,nframes, 'uint8');
% 	idx = cat(1,cc.PixelIdxList{:});
% 	lm(idx) = 255;
% 	g{k} = lm;
% end
% 
% 
% 
% tmp = cat(3,g{:});
% vid(:,:,3,:) =  tmp(:,:,1:size(vid,4));








