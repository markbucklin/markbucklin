function displayStruct(s)

flds = fields(s);
s = s(1);
for k=1:numel(flds)
	fprintf('\n-------------------\n%s\n-------------------\n',flds{k})
	disp(s.(flds{k}))
end