



% lmD = distributed(lmData);
N = size(lmData,3);
spmd
	
	lmCD = codistributed(lmData, codistributor1d(3));
end



spmd
	lm = getLocalPart(lmCD);
	n = size(lm,3);
	fprintf('Lab: %i\n\tLM-Size %i\n\n', labindex, n)
	[idxStart, idxEnd] = globalIndices(lmCD, 3, labindex);
	for k=idxStart:idxEnd
		fprintf('lab %i %i\n',k,labindex)
	end
	
end



