function lookList = lookforAsync( lookTerms )

if ischar(lookTerms)
	lookTerms = {lookTerms};
end

for k=1:numel(lookTerms)
	str = lookTerms{k};
	lookfut.(str) = parfeval(@() evalc( sprintf('lookfor %s -all',str) ), 1);
end


for k=1:numel(lookTerms)
	str = lookTerms{k};

end

% todo

fld = fields(lookfut); for k=1:numel(fld), looklist.(fld{k}) = fetchOutputs(lookfut.(fld{k})), end






% 
% 
% lookfut.undoc = parfeval(@() evalc( 'lookfor undocumented -all' ), 1)
% lookfut.task = parfeval(@() evalc( 'lookfor task -all' ), 1)
% lookfut.stream = parfeval(@() evalc( 'lookfor stream -all' ), 1)