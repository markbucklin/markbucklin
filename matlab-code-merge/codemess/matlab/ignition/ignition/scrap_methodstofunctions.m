	function numFrames = getNumFrames(F)
			if isnumeric(F)
				numDims = ndims(F);
				if numDims <= 2
					numFrames = 1;
				else
					numFrames = size(F, numDims);
				end
			else
				%TODO
			end
		end
function F = onCpu(~, F)
			% Transfer input to system memory from gpu-device memory
			
			if isnumeric(F)
				% NUMERIC INPUT
				F = gatherifongpu(F);				
			elseif isstruct(F)
				% STRUCTURED INPUT
				sFields = fields(F);
				sNum = numel(F);
				for kField=1:numel(sFields)
					fieldName = sFields{kField};
					for kIdx = 1:sNum						
						F(kIdx).(fieldName) = gatherifongpu(F(kIdx).(fieldName));
					end
				end
			elseif iscell(F)
				% CELL ARRAY INPUT
				for kIdx = 1:numel(F)
					F{kIdx} = gatherifongpu(F{kIdx});
				end
			end
			
			% GATHER-IF-ON-GPU SUBFUNCTION FOR NUMERIC DATA
			function fcpu = gatherifongpu(fgpu)
				if isnumeric(fgpu)
					if isa(fgpu, 'gpuArray') && existsOnGPU(fgpu)
						fcpu = gather(fgpu);
					else
						fcpu = fgpu;
					end
				else
					% TODO: recursive calls?
					fcpu = fgpu;
				end
			end
			
		end	
		function F = ignition.shared.onGpu( F)
			% Transfer input to system memory from gpu-device memory
			% TODO: replace with onPreferredDevice() or xferDataToDevice
			isGpuPref = obj.UseGpu;
			if ~isGpuPref
				return
			end
			
			if isnumeric(F)
				% NUMERIC INPUT
				F = xfergpuifoncpu(F);				
			elseif isstruct(F)
				% STRUCTURED INPUT
				sFields = fields(F);
				sNum = numel(F);
				for kField=1:numel(sFields)
					fieldName = sFields{kField};
					for kIdx = 1:sNum						
						F(kIdx).(fieldName) = xfergpuifoncpu(F(kIdx).(fieldName));
					end
				end
			elseif iscell(F)
				% CELL ARRAY INPUT
				for kIdx = 1:numel(F)
					F{kIdx} = xfergpuifoncpu(F{kIdx});
				end
			end
			
			% GATHER-IF-ON-GPU SUBFUNCTION FOR NUMERIC DATA
			function fgpumem = xfergpuifoncpu(fval)				
				if isnumeric(fval)
					if ~isa(fval, 'gpuArray')
						fgpumem = gpuArray(fval);
					else
						fgpumem = fval;
					end
				else
					% TODO: recursive calls?
					fgpumem = fval;
				end
			end
			
		end
		function className = getClass(~, F)
			if isa(F, 'gpuArray')
				className = classUnderlying(F);
			else
				className = class(F);
			end
		end
		function dataType = getDataType(~, F)
			if isa(F, 'gpuArray')
				dataType = classUnderlying(F);
			elseif (isa(F, 'VideoBaseType'))
				dataType = getClass(obj, F.FrameData);%TODO
			else
				dataType = class(F);
			end
		end
		function flag = isOnGpu(~, F)
			flag = false;
			if (isa(F, 'VideoBaseType'))
				f = F.FrameData;
			else
				f = F;
			end
			if isa(f, 'gpuArray') && existsOnGPU(f)
				flag = true;			
			end
		end
