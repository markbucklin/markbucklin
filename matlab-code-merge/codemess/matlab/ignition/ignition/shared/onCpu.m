function F = onCpu(F)
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
