hIm = handle(imshow(f.rgb));
npix=100;
% stdpc = prctile(double(stat.Std(:)), 1:100)
S6 = strel('disk',6,8);
S5 = strel('disk',5,8);
S4 = strel('disk',4,8);
S3 = strel('disk',3,8);
for k=k:numel(vid)
	f.im = vid(k).cdata;
	bw = f.im > minImage + stdpc(99);
f.red = imerode(imopen(bw, S6), S4);
	f.green = imclose(imopen(bw, S6), S3);
f.blue = f.im;
	f.rgb = cat(3, f.red.*200, f.green.*200, f.blue);
	hIm.CData = f.rgb;
	drawnow
end


% 	f.red = bwareaopen(imopen(bw, strel('disk',4,8)), npix);

	% f.red = (f.im, strel('disk',4,8));
	% 	f.green = f.im;
% 	f.green = gather(imclose(imopen(gpuArray(f.red), strel('disk',6,8)), strel('disk',3,8)));
% f.green = imdilate( f.red, strel('disk',5,8));
	% 	f.blue = imclose(imopen(f.im>80, strel('disk', 4, 8)),strel('disk', 4, 8)).*80;
% 		f.blue = zeros(size(f.im),'uint8');
% 	f.blue = imclose(imopen(f.red, strel('disk',4,8)), strel('disk',5,8));