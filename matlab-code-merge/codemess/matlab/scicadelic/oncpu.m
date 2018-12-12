function data = oncpu(data)

if isa(data, 'gpuArray')		
	data = gather(data);

elseif isa(data, 'struct')
	
	sFields = fields(data);
	% 	sVals = struct2cell(dstatFt);
	for k=1:numel(sFields)
		fn = sFields{k};
		if isa([data.(fn)], 'gpuArray')
			data.(fn) = gather(data.(fn)); %TODO
		end
		% 		if isa(sVals{k}, 'gpuArray')
		% 			data.(fn) = gather(sVals{k});
		% 		end
	end
	
end