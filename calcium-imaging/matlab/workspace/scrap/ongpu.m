function data = ongpu(data)
warning('ongpu.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if isnumeric(data)
	if ~isa(data, 'gpuArray')
		data = gpuArray(data);
	end
elseif isa(data, 'struct')
	sFields = fields(data);
	for k=1:numel(sFields)
		fn = sFields{k};
		if ~isa([data.(fn)], 'gpuArray')
			data.(fn) = gpuArray(data.(fn)); %TODO: FOR STRUCTARRAYS
		end
		
	end
	
end
