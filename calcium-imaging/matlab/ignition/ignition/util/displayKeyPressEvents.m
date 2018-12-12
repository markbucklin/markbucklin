function displayKeyPressEvents(figHandle)

if nargin < 1
	figHandle = [];
end

if isempty(figHandle)
	figHandle = get(groot,'CurrentFigure');
end
if isempty(figHandle)
	figHandle = handle(gcf);
end
set(figHandle, 'WindowKeyPressFcn', @keydisplayfunc)



	function keydisplayfunc(src,evnt)
		if strcmp(evnt.Key,'shift')
			return
		else
			disp(['Modifier: ',evnt.Modifier{:}])
			disp(['Key: ',evnt.Key])
			disp(['Character: ',evnt.Character])
			length(evnt.Modifier)
			disp('----------------------')
		end
	end

end
