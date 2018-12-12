function [obj, benchTime] = tryprop(labelMatrix)

try
	% N = 64;
	
	% labelMatrix = lmData(:,:,1:N);
	
	% labelMatrix = lmData;
	[nRows, nCols, N] = size(labelMatrix);
	frameIdx = 0;
	frameSize = [nRows, nCols];
	% stats = LinkedRegion.regionStats.essential;
	stats = LinkedRegion.regionStats.shape;
	k=1;
	rp = regionprops(labelMatrix(:,:,k), stats{:});
	rk = FrameLinkedRegion(rp, 'FrameIdx', frameIdx+k, 'FrameSize', frameSize);
	obj = PropagatingRegion(rk);
	
	benchTime = zeros(N,1);
	fprintf('Round %i  - %i PropagatingRegions\t\n',k, numel(obj))
	
	for k=2:size(labelMatrix,3)
		try
			tStart = hat;
			
			rp = regionprops(labelMatrix(:,:,k), stats{:});
			rk = FrameLinkedRegion(rp, 'FrameIdx', frameIdx+k, 'FrameSize', frameSize);
			[obj, splitPropRegion, newPropRegion] = propagate(obj, rk);
			if ~isempty(splitPropRegion);
				obj = cat(1, obj, splitPropRegion);
			end
			if ~isempty(newPropRegion)
				obj = cat(1, obj, newPropRegion);
			end
			
			tFinish = hat-tStart;
			fprintf('Round %i:\t\t %i PropagatingRegions\t (%-3.4gms)\n',k, numel(obj), tFinish*1000)
			benchTime(k) = tFinish;
			
			% 	unreliable = ([obj.NumCopagation]>=8) & (([obj.NumPropagation]./[obj.NumCopagation])<.1);
			% 	fprintf('FracReliable: %-03.4g\n',nnz(~unreliable)./numel(unreliable));
			% 	obj = obj(~unreliable);
		catch me
			msg = getError(me);
			disp(msg);
			
		end
		
	end
	
	
catch me
	
	
end

