function c = getFilteredRois(vid, varargin)

% [centers,radii] = imfindcircles(A,[6 25], 'Sensitivity', .9);
% h=viscircles(centers, radii)

pixExclude = 5;

try
	%%
	if ~isa(vid(1).cdata,'uint8')
		vid = vidStruct2uint8(vid);
	end
	N = numel(vid);
	spatfilt = true;
	H = fspecial('gaussian', [5 5], .5);
	midVal = .5;
	vidRange = single(range(cat(1,vid.min, vid.max)));
	vidMin = single(min([vid.min]));
	vidMax = single(max([vid.max]));
	[sz1 sz2] = size(vid(1).cdata);
	
	% Filter with normalized Gaussian
	cellRadius = 5;
	H = fspecial('disk', cellRadius);
	H = padarray(H,[cellRadius cellRadius], 0, 'both');
	H(H<eps) = -mean(H(H>eps));
	H = H - mean(H(:));
	videdge = mean(vid(1).cdata(:));
	for k=1:numel(vid)
		fvid(k).cdata = imfilter(vid(k).cdata, H, videdge);
		fprintf('filtering %i\n',k),
	end
	se = strel('disk', cellRadius);
	
	%%
	h = waitbar(0,  sprintf('Calculating Difference of Running Average for Frame %g of %g (%f secs/frame)',1,N,0));
	tic
	mvAvg = gpuArray(imlincomb(1/2, vid(1).cdata, 1/2, vid(end).cdata, 'uint8'));
	for k = 1:numel(vid)
		im = gpuArray(vid(k).cdata);
		lpim = imlincomb(1, im, -1, mvAvg, midVal, 'uint8');
		mvAvg = imlincomb(k/(k+1), mvAvg, 1/(k+1), im, 'uint8');
		if spatfilt
			% 			lpim = imfilter(lpim, H, midVal);
			lpim = imopen(lpim, se);
			lpim = imfill(lpim, 'holes');			
		end
		% 		imagesc(lpim), colorbar		
		vid(k).lpdata = gather(lpim);
		imshowpair(vid(k).lpdata, vid(k).cdata);
		drawnow
		waitbar(k/N, h, ...
			sprintf('Calculating Difference of Running Average for Frame %g of %g (%f secs/frame)',k,N,toc));
		tic
	end
	delete(h)
	
	
	
	%%
	% 	H = fspecial('gaussian', round(6*cellRadius), cellRadius);
	% 	sfilt = zeros(size(s));
	% 	for k = 1:size(s,3)
	% 		sfilt(:,:,k) = gather(imfilter(gpuArray(s(:,:,k)), H));
	% 	end
	
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



