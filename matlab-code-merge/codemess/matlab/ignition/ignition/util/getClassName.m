function className = getClassName(obj)

try
	fullClassName = strsplit(class(obj), '.');
	className = fullClassName{end};
catch
	className = '';
end
	