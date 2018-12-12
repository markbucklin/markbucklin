function releaseWorkerBuffer(buf)
try
	% 	buf = distcompdeserialize(buf);
	for k=1:buf.numFiles
		close(buf.tiffObj(k))
	end
	buf = [];
	fprintf('Frame-Buffer Released\n')
end
end