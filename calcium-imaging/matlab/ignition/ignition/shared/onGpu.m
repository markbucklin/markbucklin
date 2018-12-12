function F = onGpu(F)
% Transfer input to system memory from gpu-device memory



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
