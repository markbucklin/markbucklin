if obj.pUseBuffer
				% LOCAL BUFFER VARIABLES
				bufferSize = obj.BufferSize;
				k = rem(n,bufferSize)+1;
				
				% DETERMINE WHICH/WHERE FRAMES GO INTO CURRENT/UNFILLED BUFFER
				bufIdx = k:k+inputNumFrames-1;
				fitsInBuffer = (bufIdx <= bufferSize);
				
				% PUT INPUT INTO FRAME-BUFFER
				obj.DataBuffer(:,:,bufIdx(fitsInBuffer)) = data(:,:,fitsInBuffer);
				
				% RUN ROI-GENERATION IF BUFFER IS FULL
				if bufIdx(end) >= bufferSize
					fullBuffer = obj.DataBuffer;
					
					% SEND BUFFERED DATA TO GPU IF NOT THERE ORIGINALLY
					if obj.pUseGpu && ~isa(fullBuffer, 'gpuArray')
						fullBuffer = gpuArray(fullBuffer);
					end
					
					% CALL MAIN PROCESSING FUNCTION
					output = processData(obj, fullBuffer);
					obj.OutputAvailable = true;
				else
					obj.OutputAvailable = false;
					output = [];
				end
				
				% PUT ANY REMAINING INPUT INTO NEXT BUFFER
				if any(~fitsInBuffer)
					nOver = nnz(~fitsInBuffer);
					obj.DataBuffer(:,:,1:nOver) = data(~fitsInBuffer);
				end
				
				
else
				
end