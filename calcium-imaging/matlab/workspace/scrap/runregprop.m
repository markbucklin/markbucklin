function [regStorage, regIncidence] = runregprop(data, labelMatrix)
warning('runregprop.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')


idx = 1:8;
obj = scicadelic.RegionPropagator;

while idx(end)<size(data,3),
	disp(idx(1))
	tic
	step(obj, data(:,:,idx), labelMatrix(:,:,idx), idx);
	toc
	idx = idx(end)+(1:8);
end

regStorage = obj.RegionStorage;
regIncidence = obj.RegionIncidence;

release(obj)
clear obj









% 
% idx = find(regIncidence);
% incid = full(regIncidence);
% idxCommon = idx(incid(idx)>255);
% idxRare = idx(incid(idx)<=255);
% fn = fields(regStorage),
% for k=1:numel(fn),
% if ~iscell(regStorage.(fn{k})),
% regScalarProp.(fn{k}) = regStorage.(fn{k})(idxCommon,1:512);
% end, end
% Xmax = full(regScalarProp.MeanIntensity)';
% Xmax(Xmax==0) = NaN;
% Xmin = full(regScalarProp.MinIntensity)';
% Xmin(Xmin==0) = NaN;
% Xmean =  full(regScalarProp.MeanIntensity)';
% Xmean(Xmean==0) = NaN;
% xidx = 1:10:1000;
% col = distinguishable_colors(numel(xidx));
% h(:,1) = plot(Xmin(:,xidx)); hold on
% h(:,2) = plot(Xmean(:,xidx));
% h(:,3) = plot(Xmax(:,xidx));
% for k=1:size(h,1), set(h(k,:), 'Color',col(k,:)); end
