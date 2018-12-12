function vid = normalizeVidStruct2Region(vid, varargin)

vidClass = class(vid(1).cdata);
% PROCESS BINARY MASK INPUT OR QUERY USER TO SELECT BACKGROUND REGIONS
if nargin > 1
	bgMask = varargin{1};
else
	waitfor(msgbox('Select the background region to normalize video intensity to'));
	vidSample = getVidSample(vid);
	sampleImage = mat2gray( range( cat(3, vidSample.cdata), 3));
	imshow(sampleImage);
	% 	imshow(mat2gray( var(single(cat(3,vidSample.cdata)),1,3)));
	doAnotherRoi = 'yes';
	nRoi = 0;
	while(strcmpi(doAnotherRoi,'yes'))
		nRoi = nRoi +1;
		hRoi(nRoi) = impoly(gca);
		doAnotherRoi = questdlg('Do Another?');
	end
	bgMask = hRoi(1).createMask;
	for k = 1:numel(hRoi)
		bgMask = bgMask | hRoi(k).createMask;
	end
	imshowpair(sampleImage, bgMask);
	drawnow
end
% NORMALIZE EACH FRAME BY SUBTRACTING THE SCALAR MEAN OF SELECTED BACKGROUND REGIONS
% cvid.vid = vid;
% cvid.bmvid = vid;
% cvid.logbmvid = vid;
for k = 1:numel(vid)
	bm(k) = mean(vid(k).cdata(bgMask), 'double');
	vid(k).backgroundMean = bm(k);
% 	fprintf('frame %i\n',k)	
end
offset = median(bm(:));
% logoffset = log(offset);
% logbm = log(bm);
for k=1:numel(vid)	
	bgSubFrame = double(vid(k).cdata) - bm(k) + offset;
% 	bgSubFrame = exp( log(double(vid(k).cdata) - logbm(k) + logoffset));
	vid(k).cdata = cast(bgSubFrame, vidClass);
% 	fprintf('frame %i\n',k)	
fprintf('Normalizing video Background Intensity. (frame %i)\n',k)	
end




