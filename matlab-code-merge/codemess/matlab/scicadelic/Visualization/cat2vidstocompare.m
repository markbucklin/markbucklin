

dataPost = uint8(data./uint16(25000/256));
dataPre = uint8(predata./uint16(25000/256));
medDataPost = median(dataPost,3);
medDataPre = median(dataPre,3);
rows = 1:1024;
cols = 33:1024-32;
dataPost = permute(shiftdim(dataPost, -1), [2 3 1 4]);
dataPre = permute(shiftdim(dataPre, -1), [2 3 1 4]);

vid = cat(2, ...
	cat(3,dataPre(rows,cols,:,:),...
	repmat(medDataPre(rows,cols),1,1,2,2000)),...
	cat(3,dataPost(rows,cols,:,:),...
	repmat(medDataPost(rows,cols),1,1,2,2000)));



fps = 20;
sz = size(vid);

[filename, filedir] = uiputfile('*.mp4');
   filename = fullfile(filedir,filename);

profile = 'MPEG-4';
writerObj = VideoWriter(filename,profile);
writerObj.FrameRate = fps;
writerObj.Quality = 100;
open(writerObj)

writeVideo(writerObj, vid)
close(writerObj)



