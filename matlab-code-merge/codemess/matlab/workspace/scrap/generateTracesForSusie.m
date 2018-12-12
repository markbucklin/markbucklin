%%
m = size(f.rgb,4);
idx = 64;
TF = scicadelic.TemporalFilter('MinTimeConstantNumFrames',8)
bwL = {};

%%
while idx(end) < m
	idx=idx(end)+(1:16); idx=idx(idx<=m);
	
	Qk = single(gpuArray(squeeze(f.rgb(:,:,1,idx)))) .*(1/256);
	Qk = applyFunction2D(@medfilt2, Qk);
	Qk = step(TF, Qk);
	
	bw = Qk>.2;
	bw = reshape(  bwmorph(bwmorph(bwmorph( reshape(bw,numRows,[],1), 'clean'), 'majority'),'fill')   ,numRows,numCols,[]);
	bwl = applyFunction2D(@bwlabel, bw);
	
	bwL{end+1} = gather(bwl);
	%roi = RegionOfInterest(bwl)
end


%%
%rpC = {};
rpC = cell(1,numel(bwL));
for k=1:numel(bwL)
	rpC{k} = regionprops(bwL{k});
end