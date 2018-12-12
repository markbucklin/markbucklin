function vid = vidStruct2Uint8Ranged(vid, inputRange)





N = numel(vid);
inputDataType = class(vid(1).cdata);


t=hat;
h = waitbar(0,  sprintf('Converting video frames from %s to %s: %g of %g (%f ms/frame)',...
   inputDataType, 'uint8', 1,N, 1000*(hat-t)));
for k=1:numel(vid)
   im = mat2gray( gpuArray(vid(k).cdata), inputRange);
   im = cast(im*255, 'uint8');
   vid(k).cdata = gather(im);
   waitbar(k/N, h, sprintf('Converting video frames from %s to %s: %g of %g (%f ms/frame)',...
      inputDataType, 'uint8', k,N, 1000*(hat-t)));
   t=hat;
end
delete(h)
