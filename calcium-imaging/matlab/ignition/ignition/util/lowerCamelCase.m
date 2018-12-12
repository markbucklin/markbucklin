function argOut = lowerCamelCase(argIn)

if ischar(argIn)
	argOut = lowerCamel(argIn);

elseif isstruct(argIn) || isobject(argIn)
	fieldNamesIn = fields(argIn);
	argSize = numel(argIn);
	for k=1:numel(fieldNamesIn)
		inField = fieldNamesIn{k};
		outField = lowerCamel(inField);
		[argOut(1:argSize).(outField)] = argIn(:).(inField);		
	end
	if ~isscalar(argIn) && ~isvector(argIn)
		argOut = reshape(argOut, size(argIn));
	end
	
elseif iscell(argIn)	
	argOut = cellfun(@lowerCamel, argIn, 'UniformOutput',false);
	
end


end



function c = lowerCamel(c)

try
	c = [upper(c(1)) , c(2:end)];
catch
	c(1) = upper(c(1));
end

end




