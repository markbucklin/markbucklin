function eventListenDisplay(src,evnt)
if isstruct(evnt)
	if isfield(evnt,'EventName')
		disp(evnt.EventName)
	else
		disp(fields(evnt))
	end
else
	disp(evnt)
end
