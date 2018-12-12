function plotMaxMinMean(Fmax, Fmin, Fmean, Fsize, idxOptionInput)

if nargin < 4
	Fsize = [];
end
if nargin < 5
	idxOptionInput = 10;	
end


Fmax = double(Fmax);
Fmin = double(Fmin);
Fmean = double(Fmean);
[numFrames, numSignals] = size(Fmax);

fMissing = (Fmax==0);




%% SELECT CHANNELS TO PLOT

% USE IDXOPTION INPUT TO SELECT WHICH CHANNELS TO PLOT
if ischar(idxOptionInput)
		if strcmpi(idxOptionInput, 'all')
			idxOption = 1:numSignals;
		else
			%TODO
			% fRange = max(Fmax,[],1) - min(Fmin, [], 1);
			% fRange = max(Fmean,[],1) - min(Fmean, [], 1);
			% fRange = diff(prctile(Fmax, [25 99.9]));
			%	fRange = prctile(Fmax, 99.9) - prctile(Fmean, 25);
			idxOption = idxOptionInput;
		end
else % isnumeric
	if ismatrix(idxOptionInput)
		% TODO: Fsize
		idxOption = idxOptionInput;
	else % vector of channel indices OR scalar number of strongest signals
		idxOption = idxOptionInput;
	end
end
		
if numel(idxOption) == 1
	
	% SORT CHANNELS BY SIGNAL STRENGTH AND PLOT STRONGEST N CHANNELS
	fRange = prctile(Fmax, 99.9) - prctile(Fmin, 50);
	minNumLines = idxOption;	
	numLines = min(numSignals, minNumLines);
	[rangesortval,rangesortidx] = sort(fRange(:),'Descend');
	chanIdx = rangesortidx(1:numLines);
	chanHeight = rangesortval(1:numLines);
	chanOffset = cumsum(chanHeight)';
	titleString = sprintf('Min Max & Mean (%d of %d signals)', numLines, numSignals);
	squishFactor = 1 + .5*floor(numLines/10);
	
else
	
	% USE INPUT VECTOR OF CHANNEL INDICES
	chanIdx = idxOption(:);
	numLines = numel(chanIdx);	
	
	% NORMALIZE SELECTED SIGNALS BY RANGE INDICATOR
	rawRangeIndicator = prctile(Fmax, 99.99) - prctile(Fmin, 5);
	rawMinIndicator = prctile(Fmin, 5);
	normalized = @(x) bsxfun(@rdivide, bsxfun(@minus, x, rawMinIndicator), rawRangeIndicator);
	Fmax = normalized(Fmax);
	Fmean = normalized(Fmean);
	Fmin = normalized(Fmin);	
	
	% GET NEW (NORMALIZED) RANGE FOR CONSISTENCY WITH SORTED CASE
	fRange = prctile(Fmax, 99.99) - prctile(Fmin, 5);
	chanHeight = fRange(chanIdx);
	chanHeight = chanHeight(:);
	chanOffset = cumsum(chanHeight);
	chanOffset = chanOffset(:)';
	titleString = sprintf('Min Max & Mean (%d of %d signals)', numLines, numSignals);	
	squishFactor = 1 + .1*floor(numLines/10);
	
end




%% EXTRACT SIGNALS TO PLOT FROM SPECIFIED CHANNELS & ADD VERTICAL OFFSET TO AID VISUALIZATION

% CALCULATE CONSTANT OFFSET TO ADD TO EACH CHANNEL TO VERTICALLY OFFSET 'STRIPS'
% rval = [0 , rval(1:end-1)] - prctile(Fmin(:,chanIdx(1)), 5);
chanOffset = [0.1*chanOffset(1) , chanOffset(1:end-1)] - prctile(Fmin(:,chanIdx(1)), 5);
chanOffset = chanOffset./squishFactor;

% ADD OFFSET TO EACH CHANNEL
fMin = bsxfun(@plus, Fmin(:,chanIdx), chanOffset);
fMean = bsxfun(@plus, Fmean(:,chanIdx), chanOffset);
fMax = bsxfun(@plus, Fmax(:,chanIdx), chanOffset);

% GENERATE HIGH-CONTRAST COLORS FOR EACH CHANNEL
clf
hax = handle(gca);
hfig = gcf;
whitebg(hfig, 'white')
channelColors = distinguishable_colors(numel(chanIdx));
colormap(gca,channelColors);

% CALCULATE DOWNSAMPLED SIZE SIGNALS FOR CIRCLE OVERLAY
if ~isempty(Fsize)
	normalized = @(x) bsxfun(@rdivide, bsxfun(@minus, x, prctile(x,1,1)), diff(prctile(x,[1,99.99],1),1,1));
	fSize = normalized(double(Fsize(:,chanIdx)));
	fSize(fSize <= eps) = nan;
	tFrame = 1:numFrames; % tFrame = TL.AllFrameInfo.t;
	fs = 20;
	resampleFactor = 5;
	fsResample = resampleFactor*fs;
	[fsz, tsz] = resample(fSize, tFrame, 1/(fsResample));
	szCircCx = min(numFrames, max(1, tsz(:) + floor(resampleFactor*fs/2)));
	szCircCy = fMean(szCircCx, :); % - .1*rval(1)
	% 	winSize = fsResample;
	% 	maxCircWidth = fsResample/4;
	maxCircWidth = min(diff(szCircCx))/4;
	htRatio = chanOffset(end)./numFrames;
	maxCircHeight = maxCircWidth * htRatio;
	% 	maxCircHeight = chanHeight/4;
	maxCircHeight = maxCircHeight(:)';
	% 	maxCircHeight = median(diff(szCircCy,1,2),1);
	% 	htRatio = mean(chanHeight)./fsResample;
	
	% 	maxCircHeight = htRatio/4;
	% 	n = winSize*floor(numFrames/winSize);
	% 	windowedStd = squeeze(std(reshape(fMean(1:n,:)', numLines, winSize, n/winSize), 1, 2));
	% 	maxCircHeight = mean(windowedStd,2)';
	
	szCircRy = bsxfun(@times, fsz, maxCircHeight);
	szCircRx = bsxfun(@times, fsz, maxCircWidth);	
end




%% CONFIGURE WINDOW & ADD ADDITIONAL INFORMATION (TITLE)

% ADJUST AXES LIMITS & POSITION TO OPTIMIZE VIEWABILITY
xlim([0 numFrames])
ylim([0 max(fMax(:,end))+.1*mean(fRange(:))])
hax.Position = [0.0400    0.0600    0.925    0.90];
hax.Title.String = titleString;




%% ADD GRAPHICS OBJECTS (LINES, PATCHES, ETC.) TO CURRENT AXES FOR EACH CHANNEL
for k=numel(chanIdx):-1:1
	
	% GET CURRENT CHANNEL INDEX, AVAILABLE FRAMES, & COLOR
	lidx = chanIdx(k); % 	t = tCell{lidx};	
	t = find(~fMissing(:,lidx));
	lineColor = channelColors(k,:);
	
	% ADD A LINE FOR EACH OF MIN/MEAN/MAX (3)
	hminline = handle(line(t, fMin(t,k), 'Color', [lineColor , .5],'Parent',hax));
	hmeanline = handle(line(t, fMean(t,k), 'Color', [lineColor , .8],'Parent',hax,'LineWidth',1.25));
	hmaxline = handle(line(t, fMax(t,k), 'Color', [lineColor , .5],'Parent',hax));
	
	% ADD PATCHES BETWEEN LINES TO EMPHASIZE CHANGES
	if ~isempty(hminline) && ~isempty(hmeanline) && ~isempty(hmaxline)
		h(k,1) = hminline;
		h(k,2) = hmeanline;
		h(k,3) = hmaxline;
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
		
		% ADD CIRCLES INDICATING SIZE (TODO!!)
		if ~isempty(Fsize)			
			cxy = [szCircCx(:), szCircCy(:,k)];
			rx = szCircRx(:,k); %cr = szCircRadius(:,k);
			ry = szCircRy(:,k);
			% 			cr(cr<=eps) = eps;
			rx(rx<=eps) = eps;
			ry(ry<=eps) = eps;
			for kcirc = numel(rx):-1:1
				hSizePatch(k,kcirc) = patch(...
					'XData', cxy(kcirc,1) + rx(kcirc) * sin(-pi:pi/10:pi),...
					'YData', cxy(kcirc,2) + ry(kcirc) * cos(-pi:pi/10:pi),...
					'FaceColor', lineColor,...
					'EdgeColor',lineColor,...
					'FaceAlpha',.5,...
					'EdgeAlpha',.7,...
					'Parent',hax);
			end
			% 			hCirc(k) = handle(viscircles(cxy, cr,...
			% 				'EdgeColor', lineColor,...
			% 				'DrawBackgroundCircle', true));
		end
		
	end
	
	
	
end




















