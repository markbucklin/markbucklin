function imrcplay(lm)

lm = oncpu(lm);
[numRows, numCols, numFrames] = size(lm);
lmrgb = zeros(numRows,numCols,3,numFrames, 'uint8');

for k=1:numFrames
	lmrgb(:,:,:,k) = label2rgb(lm(:,:,k),'prism','k');
end
imrgbplay(lmrgb);






