function [cwho,cfields] = showWorkerConstVal(C)



fprintf('WorkerConst: %s\n',class(C))

cval = C.Value;

fprintf('cval: %s\n',class(cval))

if isa(cval, 'uint8')
	cval = distcompdeserialize(C.Value);
	fprintf('cval (deserialized): %s\n',class(cval))
end


if isstruct(cval)
	% 	if isfield(cval,'Value')
	% 		cval = cval.Value;
	% 	end
	cfields = fields(cval);
	
	fprintf('\t %s\n',cfields{:})
else
	cfields = [];
	
end

cwho = whos;