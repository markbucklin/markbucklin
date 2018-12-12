function varargout = plotMaxMinMeanT(Fmax, Fmin, Fmean, Fsize, idxOptionInput, tSampleInput)
% tSampleInput - may be a vector of timestamps or a sampling frequency, (Fs)


%% MANAGE INPUT ARGUMENTS

% CELL SIZE
if nargin < 4
	Fsize = [];
end
sizeCirclePeriod = 3;

% SUBSET OF CELLS TO PLOT
if nargin < 5
	idxOptionInput = 10;	
end

% CONVERT INPUT TO DOUBLE
Fmax = double(Fmax);
Fmin = double(Fmin);
Fmean = double(Fmean);
[numFrames, numSignals] = size(Fmax);

% TIMESTAMPS FOR EACH FRAME
if nargin < 6	
	tSampleInput = 20;
	fs = tSampleInput;
	tFrame = (0:numFrames-1)./fs;
else
	if numel(tSampleInput) > 1
		tFrame = tSampleInput;
		fs = 1/mean(diff(tFrame(:)));
	else
		fs = tSampleInput;
		tFrame = (1:numFrames)./fs;
	end
end
tFrame = tFrame(:);
fMissing = (Fmax==0);




%% SELECT CHANNELS TO PLOT

% USE IDX-OPTION (SUBSET-IDX) INPUT TO SELECT WHICH CHANNELS TO PLOT
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

% MANAGE SIZE & VERTICAL SPACING OF SELECTED SIGNALS
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
	% 	squishFactor = 1 + .5*floor(numLines/10);
	
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
% 	squishFactor = 1 + .1*floor(numLines/10);
	
end
squishFactor = 1 + .1*floor(numLines/10);




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
h.ax = handle(gca);
hfig = gcf;
whitebg(hfig, 'white')
channelColors = distinguishable_colors(numel(chanIdx));
colormap(gca,channelColors);

% CALCULATE DOWNSAMPLED SIZE SIGNALS FOR CIRCLE OVERLAY
if ~isempty(Fsize)
	normalized = @(x) bsxfun(@rdivide, bsxfun(@minus, x, prctile(x,1,1)), diff(prctile(x,[1,99.99],1),1,1));
	fSize = normalized(double(Fsize(:,chanIdx)));
	fSize(fSize <= eps) = nan;
	% 	tFrame = 1:numFrames; % tFrame = TL.AllFrameInfo.t;	
	% 	resampleFactor = 5;
	% 	fsResample = resampleFactor*fs;
	fsResample = 1/sizeCirclePeriod;
	[fsz, tsz] = resample(fSize, tFrame, fsResample); % [fsz, tsz] = resample(fSize, tFrame, 1/resampleFactor);
	szCircCx = tsz;% + .5/fsResample; % szCircCx = tsz + floor(resampleFactor);
	% 	szCircCx = min(tFrame(end), max(0, tsz(:) + floor(resampleFactor*fs/2)));
	% 	szCircCx = min(numFrames, max(1, tsz(:) + floor(resampleFactor*fs/2)));
	% 	szCircCt = tFrame(szCircCx);
	szCircCy = interp1(tFrame, fMean, szCircCx); % szCircCy = fMean(szCircCx, :); 
	maxCircWidth = min(diff(szCircCx))/20;
	htRatio = [];
% 	htRatio = chanOffset(end)./tFrame(end); % h.ax.DataAspectRatio(2)/h.ax.DataAspectRatio(1)
% 	maxCircHeight = maxCircWidth * htRatio;	
% 	maxCircHeight = maxCircHeight(:)';	
% 	szCircRy = bsxfun(@times, fsz, maxCircHeight);
	szCircRx = bsxfun(@times, fsz, maxCircWidth);	
end




%% CONFIGURE WINDOW & ADD ADDITIONAL INFORMATION (TITLE)

% ADJUST AXES LIMITS & POSITION TO OPTIMIZE VIEWABILITY
xlim([0 tFrame(end)]) % xlim([0 numFrames])
ylim([0 max(fMax(:,end))+.1*mean(fRange(:))])
h.ax.Position = [0.0400    0.0600    0.925    0.90];
h.ax.Title.String = titleString;
h.ax.XLabel.String = sprintf('Time (s)     Fs = %03.3g Hz', fs);
h.ax.YTick = [];
h.ax.YTickLabel = [];



%% ADD GRAPHICS OBJECTS (LINES, PATCHES, ETC.) TO CURRENT AXES FOR EACH CHANNEL
for kChan = numel(chanIdx):-1:1
	
	% GET CURRENT CHANNEL INDEX, AVAILABLE FRAMES, & COLOR
	curIdx = chanIdx(kChan); % 	t = tCell{lidx};	
	k = find(~fMissing(:,curIdx));
	t = tFrame(k);
	lineColor = channelColors(kChan,:);
	
	% ADD A LINE FOR EACH OF MIN/MEAN/MAX (3)
	h.minline(kChan) = handle(line('XData', t, 'YData', fMin(k,kChan), 'Color', [lineColor , .5],'Parent',h.ax));
	h.meanline(kChan) = handle(line('XData', t, 'YData',  fMean(k,kChan), 'Color', [lineColor , .8],'Parent',h.ax,'LineWidth',1.25));
	h.maxline(kChan) = handle(line('XData', t, 'YData',  fMax(k,kChan), 'Color', [lineColor , .5],'Parent',h.ax));
	hLine(kChan,:) = [h.minline(kChan) , h.meanline(kChan) , h.maxline(kChan)];
	% ADD PATCHES BETWEEN LINES TO EMPHASIZE CHANGES
	if ~isempty(hLine) % ~isempty(h.minline) && ~isempty(h.meanline) && ~isempty(h.maxline)		
		h.lowerpatch(kChan) = patch(...
			'XData',[t;flipud(t)],...
			'YData',[fMin(k,kChan);fMean(flipud(k),kChan)],...
			'FaceVertexCData', kChan.*ones(2*numel(k),1),...
			'FaceColor', 'interp',...
			'EdgeColor','none',...
			'FaceAlpha',.07,...
			'Parent',h.ax);
		h.upperpatch(kChan) = patch(...
			'XData',[flipud(t);t],...
			'YData',[fMean(flipud(k),kChan);fMax(k,kChan)],...
			'FaceVertexCData', kChan.*ones(2*numel(k),1),...
			'FaceColor', 'interp',...
			'EdgeColor','none',...
			'FaceAlpha',.05,...
			'Parent',h.ax);
		
		% ADD CIRCLES INDICATING SIZE (TODO!!)
		if ~isempty(Fsize)
			if isempty(htRatio)
				htRatio = h.ax.DataAspectRatio(2)/h.ax.DataAspectRatio(1);
			end
			cxy = [szCircCx(:), szCircCy(:,kChan)];
			rx = szCircRx(:,kChan);
			ry = rx * htRatio;
			rx(rx<=eps) = eps;
			ry(ry<=eps) = eps;
			for kCirc = numel(rx):-1:1
				h.sizecircle(kChan,kCirc) = patch(...
					'XData', cxy(kCirc,1) + rx(kCirc) * sin(-pi:pi/10:pi),...
					'YData', cxy(kCirc,2) + ry(kCirc) * cos(-pi:pi/10:pi),...
					'FaceColor', lineColor,...
					'EdgeColor',lineColor,...
					'FaceAlpha',.5,...
					'EdgeAlpha',.7,...
					'Parent',h.ax);
			end
		end
		
	end
	
	
	
end


% ADDITIONAL SETTINGS
set(hLine,...
	'AlignVertexCenters', 'on',...
	'HitTest', 'off',...
	'PickableParts', 'none')




if nargout
	varargout{1} = h;
end













