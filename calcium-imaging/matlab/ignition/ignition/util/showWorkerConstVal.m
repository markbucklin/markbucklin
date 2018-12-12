function cinfo = showWorkerConstVal(C)



fprintf('WorkerConst: %s\n',class(C))

cval = C.Value;

cinfo.csize = size(cval);
cinfo.class = class(cval);

fprintf('cval: %s\n',class(cval))

if isa(cval, 'uint8')
	cval = distcompdeserialize(C.Value); % distcompserialize64
	fprintf('cval (deserialized): %s\n',class(cval))
end


if isstruct(cval)
	% 	if isfield(cval,'Value')
	% 		cval = cval.Value;
	% 	end
	cinfo.fields = fields(cval);
	
	fprintf('\t %s\n',cinfo.fields{:})
else
	cinfo.fields = [];
	
end

% cwho = whos;
