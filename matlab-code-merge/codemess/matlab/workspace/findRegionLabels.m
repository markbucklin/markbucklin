function report = findRegionLabels(next, numFrames)


if nargin < 2 || isempty(numFrames)
    numFrames = 2048;
end

%% Initialize system for finding labels
report.PL = scicadelic.PixelLabel; 
% DetectionStartDelay 
% RegistrationStartDelay


%% Initialize Systems to Aggregate Image-Stream Statistics

% streamStats = 
% SCq = scicadelic.StatisticCollector;
% SCf = scicadelic.StatisticCollector;
% SCft = scicadelic.StatisticCollector;

rnal

frameIdx = 0;
while frameIdx(end) < numFrames
    %% Get next motion-corrected chunk of frames
    chunk = next();
    
	% Update Index and Timestamp
	frameIdx = chunk.info.idx;
	t = chunk.info.timestamp;
        
	%% Update Visual with Max-Projection of Current Chunk
	fChunk = oncpu( uint8(max(chunk.normalizedSelectedStatistics.uint8RGB,[],4)));
	try
        if exist('hmp','var')
            hmp.CData = fChunk;
        else
            hmp = imshow(fChunk);
        end
        set(hmp.Parent.Title,...
            'String', sprintf('Time: % 22g seconds',t(end)),...
            'Color', [0 0 0]);
        drawnow update
	catch
		warning('failure to update visual')
    end
    
    %% Update PixelLabel system (region finder)
    
    % Delay Cell detection until 5 seconds from start or more to allow
    % statistics to settle
	if t(1)<5
        continue
    end
    
    % Update Statistics for Pre-Processed Image Pixel Intensity
    step(SCf, chunk.data);
    % 		if numel(t) > 1
    % 			ft_quickdirty = bsxfun( @rdivide, diff(out.f,[],3), reshape(diff(t),1,1,[]));
    % 			step(SCft, ft_quickdirty);
    % 		end
    
    % Get Pixel-Activation Metric Sources from Current Chunk
    pixelActivationSource = {...
        chunk.normalizedSelectedStatistics.float.marginalKurtosisOfIntensity,...
        chunk.normalizedSelectedStatistics.float.marginalSkewnessOfIntensityChange};
    
    % Fix NaNs -> 0
    pixelActivationSource = cellfun( @nan2zero, pixelActivationSource, 'UniformOutput', false);
    
    % Combine Sources Using Customizable Function (default is max(Qa,Qb)
    combinationDim = max(cellfun(@ndims,pixelActivationSource)) + 1;
    combinationFcn = @(qs) max(qs, [], combinationDim);
    Qs = cat(combinationDim, pixelActivationSource{:});
    Q = combinationFcn(Qs);
    
    % Update Statistics of Activation Metric
    step(SCq, Q);
    
    % Submit Pixel-Activation Training Data (Update scicadelic.PixelLabel
    update( report.PL, Q);
    
	
	
end