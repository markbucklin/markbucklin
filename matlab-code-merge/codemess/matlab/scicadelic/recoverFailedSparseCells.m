% chunkFinished = cellfun(@isempty, lfsDataCell);
% lastChunk = find(chunkFinished,1,'last');
% lcell = cell(lastChunk,1);


XS = spalloc(8*587, 1024*1024, 2000*587);
for k=1:587
	lfs = lfsDataCell{k};
	lfsidx = lfs(:,end)>=1;
	kidx = ((k-1)*8)+(1:8);
	lfsidxCell{k} = find(lfs(:,end)>=1);
	XS(kidx, lfsidx) = lfs(lfsidx,:)';
% 	if ~isempty(lfs)
% 		lcell{k} = find(lfs(:,end));
% 	end
end

