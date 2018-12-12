function saveData2Mp4(F,varargin)

fps = [];
filename = [];

if nargin > 1
	for k=1:nargin
		arg = varargin{k};
		if isnumeric(arg)
			fps = arg;
		else
			filename = arg;
		end
	end
end

if isempty(filename)
	[filename, filedir] = uiputfile('*.mp4');
	filename = fullfile(filedir,filename);
end
if isempty(fps)
	fps = 24;
end

if size(F,3) ~= 3
	
	% ============================================================
	% DETERMINE COLOR/TIME DIMENSIONS
	% ============================================================
	[numRows, numCols, dim3, dim4] = size(F);
	if dim3 < 4
		numChannels = dim3;
		numFrames = dim4;
		colorDim = 3;
		timeDim = 4;
		
	elseif dim4 < 4
		numChannels = dim4;
		numFrames = dim3;
		colorDim = 4;
		timeDim = 3;
		
	else
		error('IMRGBPLAY currently only handles 3 color channels')
		
	end
	
	
	% ============================================================
	% RESCALE
	% ============================================================
	% inputClim = approximateClim(F);
	if ~isa(F, 'uint8')
		lowLim = approximateFrameMinimum(F, .20);
		highLim = approximateFrameMaximum(F, .05);
		% lowLim = gather(temporalArFilterRunGpuKernel(gpuArray(lowLim), .97));
		% highLim = gather(temporalArFilterRunGpuKernel(gpuArray(highLim), .97));
		limRange = highLim - lowLim;
		F = bsxfun(@times, bsxfun(@minus, F, lowLim), 1./limRange);
		if colorDim ~= 3
			F = permute(F, [1 2 colorDim timeDim]);
		end
		F = uint8(255.*F);
	else
		lowLim = 0;
		highLim = 255;
	end
	
	
	
	
	
	% 	[numRows, numCols, numFrames, numChannels] = size(F);
	% 	switch numChannels
	% 		case 1
	% 			F = repmat(reshape(F, numRows, numCols, 1, numFrames), 1, 1, 3, 1);
	% 		case 2
	% 			F = permute(F, [1 2 4 3]);
	% 			F = cat( 3, F, F(:,:,1,:));
	% 		case 3
	% 			F = permute(F, [1 2 4 3]);
	% 	end
	%

	
	
	% 	 nframes = size(data,3);
	% 	 n = nframes - rem(nframes,3);
	%    data = reshape(data(:,:,1:n),[sz(1), sz(2), 3, n/3]);
	
	
	% 	 %    data = permute(shiftdim( data, -1), [2 3 1 4]);
end


profile = 'MPEG-4';
writerObj = VideoWriter(filename,profile);
writerObj.FrameRate = fps;
writerObj.Quality = 95;

numMegaBytes = MB(F);
numGigaBytes = GB(F);
estimatedSaveTime = 10;
tOpen = tic;


open(writerObj)

% close(writerObj)


% CURRENTLY USELESS IN THIS FUNCTION: TODO
vidWriteTimer = timer(...
	'ExecutionMode', 'singleShot',...
	'StartDelay', estimatedSaveTime,...
	'StartFcn', @writeVidData, ...
	'TimerFcn', @closeFile, ...
	'StopFcn', @deleteTimer, ...
	'ErrorFcn', @sendFidToBase);


% writeVideo(writerObj, data)
start(vidWriteTimer)


	function writeVidData(~, ~)
		writeVideo(writerObj, F)
	end

	function closeFile(~, ~)
		close(writerObj)
		tElapsed = toc(tOpen);
		writeSpeedMBPS = numMegaBytes/tElapsed;
		fprintf(['MP4 Video Write Complete:\n\t',...
			'%d GB written in %3.4g seconds (or better)\n\t',...
			'--> %3.4g MB/s\n\n'], numGigaBytes, tElapsed, writeSpeedMBPS)
	end

	function deleteTimer(src, ~)
		delete(src)
	end

	function sendFidToBase(~,~)
		fprintf('An error occurred while attempting to close VideoWriter object: \n\t->sent to base workspace\n')
		assignin('base','writerObj',writerObj);
	end



end
