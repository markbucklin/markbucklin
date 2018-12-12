%%
[regStorage, regIncidence] = runregprop(data, labelMatrix);
numFrames = 512;

%%
idx = find(regIncidence);
incid = full(regIncidence);
idxCommon = idx(incid(idx)>numFrames/2);
idxRare = idx(incid(idx)<=numFrames/2);

fn = fields(regStorage);
for k=1:numel(fn)
	if ~iscell(regStorage.(fn{k}))
		regScalarProp.(fn{k}) = full(regStorage.(fn{k})(idxCommon,1:numFrames));
	end
end

%%

Fmax = full(regScalarProp.MaxIntensity)';
Fmin = full(regScalarProp.MinIntensity)';
Fmean =  full(regScalarProp.MeanIntensity)';

%%
fMissing = (Fmax==0);
% Fmax(fMissing) = NaN;
% Fmin(fMissing) = NaN;
% Fmean(fMissing) = NaN;
tCell = cell(size(Fmax,2),1);
for k=1:numel(tCell)
	tCell{k} = find(~fMissing(:,k));
end



%%
fAllRange = range(Fmean,1);
numLines = min(numel(fAllRange), 20);
[rangesortval,rangesortidx] = sort(fAllRange(:),'Descend');
ridx = rangesortidx(1:numLines);
rval = cumsum(rangesortval(1:numLines))';

fAllIncidence = incid(idxCommon);
numLines = min(numel(fAllIncidence), 20);
[incidsortval,incidsortidx] = sort(fAllIncidence(:),'Descend');
ridx = incidsortidx(1:numLines);
rval = cumsum(fAllRange(ridx));


fMin = bsxfun(@plus, Fmin(:,ridx), [0, rval(1:(end-1))]);
fMean = bsxfun(@plus, Fmean(:,ridx), [0, rval(1:(end-1))]);
fMax = bsxfun(@plus, Fmax(:,ridx), [0, rval(1:(end-1))]);


col = distinguishable_colors(numel(ridx));
clear h
close
hax = gca;
colormap(gca,col);
for k=numel(ridx):-1:1
	lidx = ridx(k);
	t = tCell{lidx};
	lineColor = col(k,:);
	
	
	
	h(k,1) = handle(line(t, fMin(t,k), 'Color', [lineColor , .5],'Parent',hax));
	h(k,2) = handle(line(t, fMean(t,k), 'Color', [lineColor , .8],'Parent',hax,'LineWidth',1.25));
	h(k,3) = handle(line(t, fMax(t,k), 'Color', [lineColor , .5],'Parent',hax));
	hUnderPatch(k) = patch(...
		'XData',[t;flipud(t)],...
		'YData',[fMin(t,k);fMean(flipud(t),k)],...
		'FaceVertexCData', k.*ones(2*numel(t),1),...
		'FaceColor', 'interp',...
		'EdgeColor','none',...
		'FaceAlpha',.07,...
		'Parent',hax);
hOverPatch(k) = patch(...
		'XData',[flipud(t);t],...
		'YData',[fMean(flipud(t),k);fMax(t,k)],...
		'FaceVertexCData', k.*ones(2*numel(t),1),...
		'FaceColor', 'interp',...
		'EdgeColor','none',...
		'FaceAlpha',.05,...
		'Parent',hax);
	
	% 	k.*ones(2*numel(t),1),...
	% 	hOverPatch(k) = patch(...
	% 		[t;flipud(t)],...
	% 		[fMax(t,lidx);Fmean(flipud(t),lidx)],...
	% 		repmat(lineColor,2*numel(t),1),...
	% 		'FaceColor', 'interp',...
	% 		'EdgeColor','none',...
	
% 		'FaceVertexAlphaData',uint8(10),...
	% 		'Parent',hax);
end
xlim([0 numFrames])
ylim([0 rval(end)+rval(1)])
hax.Position = hax.Position + [-.5*hax.Position(1:2) hax.Position(1:2)];

% h(:,1) = handle(plot(Fmin(:,ridx))); hold on
% h(:,2) = handle(plot(Fmean(:,ridx)));
% h(:,3) = handle(plot(fMax(:,ridx)));
% for k=1:size(h,1)
% 	lineColor = col(k,:);
% 	h(k,1).Color = [lineColor , .3];
% 	h(k,2).Color = [lineColor , .8];
% 	h(k,3).Color = [lineColor , .6];
% end