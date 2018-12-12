function [F, reverseFormatFcn] = formatVideoNumericArray( Finput, useFloat)

% SPECIFY DIMENSION (4th) FOR SEQUENTIAL FRAMES
frameDim = 4;

% SET FLOATING-POINT PRECISION (IF SPECIFIED)
inputDataType = ignition.shared.getDataType(Finput);
if (nargin > 1) && useFloat
	if isa(Finput, 'gpuArray')
		outputDataType = 'single';
	else
		outputDataType = 'double';
	end
else
	outputDataType = inputDataType;
end


% FORMAT OUTPUT DEPENDING ON CLASS OF INPUT
if isnumeric(Finput)
	% CAST INPUT TO FLOATING-POINT (OR DIRECT-COPY)
	if isa(Finput, outputDataType)
		F = Finput;
		reverseFormatFcn = @directCopy;
	else
		F = cast(Finput, outputDataType);
		reverseFormatFcn = @directCast;
	end
	
else
	% CONCATENATE FRAMES FROM CELL, STRUCT, OR OBJECT ARRAY
	numFramesPerContainer = cellfun( @(fcell) ignition.shared.getNumFrames(fcell), Finput);
	containerArraySize = size(Finput);
	
	if iscell(Finput)
		% CELL ARRAY OF FRAMES OR FRAME-SEGMENTS
		F = cat(frameDim, Finput{:});
		% todo -> handle multi-channel 2D cell array
		
		reverseFormatFcn = @splitFramesToCell;
		% 		reverseFormatFcn = @(f) splitFramesToCell(f,numFramesPerCell);
		
	elseif isa(Finput,'ignition.core.type.DataContainerBase') % todo -> DataArray or use isobject
		% DATA-CONTAINER OBJECT
		F = getData(Finput);
		reverseFormatFcn = @(f) copyWithNewData(Finput, f); % todo -> may be faster to use setData??
		% reverseFormatFcn -> construct new data containers			
		
	elseif isstruct(Finput)
		% STRUCTURE ARRAY OF FRAMES (e.g. from getframe(gca))
		frameStructFields = fields(Finput);
		nonDataFields = frameStructFields;
		nonDataVals = struct2cell(Finput);
		validDataFieldNames = {'data','Data','Value','CData','cdata'};
		dataFieldName = '';		
		for k=1:numel(frameStructFields)
			dataFieldRecognized = strcmp(frameStructFields{k},validDataFieldNames);
			if any(dataFieldRecognized)
				dataFieldName = frameStructFields{k};
				nonDataFields(k) = [];			
				nonDataVals(:,k) = []; % todo -> check
				break
			end
		end
		assert(~isempty(dataFieldName), 'No valid data fields detected in input');
		F = cat(frameDim, Finput.(dataFieldName));
		reverseFormatFcn = @splitFramesToStruct;
		
		% todo:
		% composite array
		% buffered data elements
		
	else
		
		
		% UNHANDLED TYPE OF INPUT (todo)
		error('Input type not handled')
	end
end



% todo -> also return function_handle for assigning stream output


	function fOut = directCopy(fIn)
		fOut = fIn;
	end
	function fOut = directCast(fIn)
		fOut = cast(fIn,inputDataType);
	end
	function fOut = splitFramesToCell(fIn)
		% todo: handle multi-channel cell arrays
		fOut = cell(containerArraySize);
		containerIdx = 0;
		frameIdx = 0;
		% 		numContainers = prod(containerArraySize); % todo: check functionality
		numFrames = sum(numFramesPerContainer(:)); %todo
		while frameIdx(end) < numFrames
			containerIdx = containerIdx + 1;
			frameIdx = frameIdx(end) + (1:numFramesPerContainer(containerIdx));
			fOut{containerIdx} = fIn(:,:,:,frameIdx);
		end
	end
	function fOut = splitFramesToStruct(fIn)
		% 		fOut = Finput; % todo -> preserve

		containerIdx = 0;
		frameIdx = 0;
		% 		numContainers = prod(containerArraySize); % todo: check functionality
		numFrames = sum(numFramesPerContainer(:)); %todo
		frameData = cell(1,numFrames);
		while frameIdx(end) < numFrames
			containerIdx = containerIdx + 1;
			frameIdx = frameIdx(end) + (1:numFramesPerContainer(containerIdx));
			frameData{containerIdx} = fIn(:,:,:,frameIdx);
			% 			fOut(containerIdx).(dataFieldName) = fIn(:,:,:,frameIdx);
		end
		fldNames = [ {dataFieldName} , nonDataFields(:)'];
		fldVals = [ frameData , nonDataVals];
		fOut = cell2struct(fldVals, fldNames, 1); % todo -> check
		
	end




end







