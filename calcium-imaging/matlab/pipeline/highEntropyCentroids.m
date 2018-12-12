function c = highEntropyCentroids(vid, varargin)

pixExclude = 5;

try
	if nargin>1
		nCentroids = varargin{1};
	else
		nCentroids = 10;
	end
	if isstruct(vid)
		N = numel(vid);
		nSampleFrames = min(N, 25);
		vid = cat(3, vid( round(linspace(1,N,nSampleFrames)) ).cdata );
	else
		N = size(vid,3);
		nSampleFrames = min(N, 25);
		vid = vid(:,:, round(linspace(1,N,nSampleFrames)) );
	end
	
	s = zeros(size(vid));
	for k = 1:nSampleFrames
		s(:,:,k) = entropyfilt(im2uint8(vid(:,:,k)));
	end
	sprod = prod(s,3);
	s99 = prctile(sprod(:),99.9);
	sbinary = sprod > s99;
	
	% remove small objects and fill in holes between the body and the tail
	sbinary = imclose(bwareaopen(sbinary,pixExclude),strel('disk',10));
	cc = bwconncomp(sbinary);
	L = labelmatrix(cc);
	c = regionprops(cc,'Centroid', 'BoundingBox','Area');
	[~,idx] = sort([c.Area]);
	c = c(fliplr(idx));
	c = c(1:min(nCentroids,numel(c)));
	if isempty(c)
		keyboard
	end
catch me
	beep
	keyboard
end



