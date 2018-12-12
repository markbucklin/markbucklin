function argOut = upperCamelCase(argIn)

if ischar(argIn)
	argOut = upperCamel(argIn);

elseif isstruct(argIn) || isobject(argIn)
	fieldNamesIn = fields(argIn);
	argSize = numel(argIn);
	for k=1:numel(fieldNamesIn)
		inField = fieldNamesIn{k};
		outField = upperCamel(inField);
		[argOut(1:argSize).(outField)] = argIn(:).(inField);		
	end
	if ~isscalar(argIn) && ~isvector(argIn)
		argOut = reshape(argOut, size(argIn));
	end
	
elseif iscell(argIn)	
	argOut = cellfun(@upperCamel, argIn, 'UniformOutput',false);
	
end


end



function c = upperCamel(c)

try
	c = [upper(c(1)) , c(2:end)];
catch
	c(1) = upper(c(1));
end

end




