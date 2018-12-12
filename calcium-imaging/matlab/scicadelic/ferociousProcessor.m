obj = scicadelic.TiffStackLoader;
setup(obj)
tiffObj = obj.TiffObj;
nFrames = [obj.TiffInfo.nFrames];
nTiff = nnz(nFrames == nFrames(1));
sumFrames = sum(nFrames(nFrames == nFrames(1)));
frameSize = obj.FrameSize;
fullFileFrames = nFrames(1);

pool = parpool(nTiff);
tifInfoDis = distributed(obj.TiffInfo(1:nTiff));
filePathDis = distributed(obj.FullFilePath(1:nTiff));
spmd(nTiff)
	warning('off','MATLAB:imagesci:tiffmexutils:libtiffWarning')
	warning off MATLAB:tifflib:TIFFReadDirectory:libraryWarning
	w = labindex;
	if w <= nTiff
		tifInfoLoc = getLocalPart(tifInfoDis);
		filePathLoc = getLocalPart(filePathDis);
		idxFirst = tifInfoLoc.firstIdx;
		idxLast = tifInfoLoc.lastIdx;
		tiffObjLoc = Tiff(filePathLoc{:}, 'r');
		
		nFramesLoc = idxLast - idxFirst + 1;
		dataLoc = codistributed.zeros([frameSize sumFrames], 'uint16');
		for k=idxFirst:idxLast
			dataLoc(:,:,k) = read(tiffObjLoc);
			nextDirectory(tiffObjLoc);
		end
	end
end





