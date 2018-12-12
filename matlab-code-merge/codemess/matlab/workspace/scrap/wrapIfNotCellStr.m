function cstr = wrapIfNotCellStr(cstr)
if ~iscellstr(cstr)
	cstr = {cstr};
end
end