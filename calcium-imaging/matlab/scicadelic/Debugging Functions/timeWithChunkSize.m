

n=0;
for k=1:8
	chunkSize=2^(k-1); 
	data = gpuArray(bwRaw(:,:,n+(1:chunkSize)));
	t(k) = gputimeit(@()step(BSF, data))*1000/chunkSize
end