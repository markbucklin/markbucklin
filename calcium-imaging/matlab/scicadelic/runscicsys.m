function varargout = runscicsys(sys, inputData, chunkSize)
%
% >> outputData = runscicsys(sys, inputData)
% >> outputData = runscicsys(sys, inputData, chunkSize)

if nargin<3
	chunkSize = 16;
end

[numRows, numCols, numFrames, numChannels] = size(inputData);
numOutputs = min(nargout, getNumOutputs(sys));

idx =  1:chunkSize;

% FIRST CHUNK -> PREALLOCATION OF OUTPUTS
switch numOutputs
	case 0
		step(sys, ongpu(inputData(:,:,idx,:)));
		outputData = [];
		
	case 1
		firstChunk = oncpu(step(sys,ongpu(inputData(:,:,idx,:))));
		if ~isstruct(firstChunk)
			outputData(numRows,numCols,numFrames,numChannels) = firstChunk(end);
			outputData(:,:,idx,:) = firstChunk;
		else			
			outputData(ceil(numFrames/chunkSize)) = firstChunk;
			outputData(1) = firstChunk;
		end
		
	case 2
		[argOut{1}, argOut{2}] = step(sys, ongpu(inputData(:,:,idx,:)));
		for k=1:2
			firstChunk = oncpu(argOut{k});
			if ~isstruct(firstChunk)
				outputArg{k}(numRows,numCols,numFrames,numChannels) = firstChunk(end);
				outputArg{k}(:,:,idx,:) = firstChunk;
			else
				outputArg{k}(ceil(numFrames/chunkSize)) = firstChunk;
				outputArg{k}(1) = firstChunk;
			end
			% 			outputArg{k} = outputData;
			% 			outputData = [];
		end
		
	case 3
		%TODO	
end


% RUN SYSTEM UNTIL DONE
m = 1;
while idx(end)<numFrames	
	idx=idx(end)+(1:chunkSize);
	idx=idx(idx<=numFrames);
	if ~isempty(idx)		
		m = m+1;
		switch numOutputs
			case 0
				step(sys, ongpu(inputData(:,:,idx,:)));
				
			case 1
				chunkOut = oncpu(step(sys,ongpu(inputData(:,:,idx,:))));
				if ~isstruct(chunkOut)
					outputData(:,:,idx,:) = chunkOut;
				else
					outputData(m) = chunkOut;
				end
				
			case 2
				[argOut{1}, argOut{2}] = step(sys, ongpu(inputData(:,:,idx,:)));
				for k=1:2
					chunkOut = oncpu(argOut{k});					
					if ~isstruct(chunkOut)
						outputArg{k}(:,:,idx,:) = chunkOut;
					else
						outputArg{k}(m) = chunkOut;						
					end
				end
				
				
			case 3
				
		end		
		
	else
		break
		
	end
end


if nargout
	switch numOutputs
		case 1
			if ~isstruct(outputData)
				varargout{1} = outputData;
			else
				varargout{1} = unifyStructArray(outputData(:),3);
			end
			
		case 2
			for k=1:2
				if ~isstruct(outputArg{k})
					varargout{k} = outputArg{k};
				else
					try
						varargout{k} = unifyStructArray(outputArg{k}(:),3);
					catch
						try
							varargout{k} = unifyStructArray(outputArg{k}(:),1);
						catch
							varargout{k} = outputArg{k};
						end
					end
				end
			end
			% 			varargout = outputArg(1:nargout);
			
		case 3	
			
	end
end


	
	
	
	
	
	
	
	
	
	
	
	