function classPkg = getClassPackage(obj)

try
	fullClassName = strsplit(class(obj), '.');
	classPkg = fullClassName{1:end-1};
catch
	classPkg = '';
end
	