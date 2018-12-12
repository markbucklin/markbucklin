function flag = isMultipleCall()
flag = false;
s = dbstack();
if numel(s)<=2
	return
end

stackCallNames = {s(:).name};
callerName = s(2).name;
callerMatch = strcmp( callerName, stackCallNames);
if nnz(callerMatch) > 1
	flag = true;
end

end
