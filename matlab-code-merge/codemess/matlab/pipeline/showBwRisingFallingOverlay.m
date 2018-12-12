function showBwRisingFallingOverlay( vid, bwvid )





N = numel(vid);

rgbImage = cat(3,vid([1 round(N/2) N]).cdata);
hImage = handle(imshow(rgbImage));
hText(1) = handle(text(10,40,'Falling Edge', 'Color','b'));
hText(2) = handle(text(10,15,'Rising Edge', 'Color','r'));
hFrameText = handle( text( size(rgbImage,1)-400, 15, 'Frame', 'Color','w'));

for k=1:N
	rgbImage = cat(3, im2uint8(bwvid(k).bwRisingEdge), vid(k).cdata, im2uint8(bwvid(k).bwFallingEdge));
	hImage.CData = rgbImage;
	hFrameText.String = sprintf('Frame %i/%i', k, N);
	drawnow
	pause(.01)
end



% for k=100:N, hLabIm.CData = label2rgb(bwvid(k).conRegRising.labelMat); drawnow, pause(.01), end