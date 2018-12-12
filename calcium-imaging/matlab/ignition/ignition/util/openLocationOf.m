function openLocationOf(itemNameInput)

try
itemPath = which(itemNameInput,'-all');
fprintf('Opening all locations containing files called by %s\n',itemNameInput);
for k=1:numel(itemPath)
	[itemDir,itemName,itemExt] = fileparts(itemPath{k});
	fprintf('\n%i - %s%s\n\t(%s)\n', k, itemName, itemExt, itemDir);
	winopen(itemDir);
end


catch me
	msg = getReport(me);
	disp(msg)
end
