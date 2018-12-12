function displayScrollWheelEvents(figHandle)

if nargin < 1
	figHandle = [];
end

if isempty(figHandle)
	figHandle = get(groot,'CurrentFigure');
end
if isempty(figHandle)
	figHandle = handle(gcf);
end
set(figHandle, 'WindowScrollWheelFcn', @scrollWheelFcn)


	
	
	function scrollWheelFcn(src,evnt)
		eventName = evnt.EventName;
		vScrollCount = evnt.VerticalScrollCount;
		vScrollAmount = evnt.VerticalScrollAmount;		
		hFig = handle(src);
		curPos = hFig.CurrentPoint;
		curObjName = get(hFig.CurrentObject, 'Tag');
		curObjType = get(hFig.CurrentObject, 'Type');
		
		fprintf('%s \n\tCount: %d \n\tAmount: %d \n\tPosition: %3.4g %3.4g\n\tCurrent Char: %s\n\n',...
			eventName, vScrollCount, vScrollAmount, curPos(1), curPos(2), src.CurrentCharacter)
		
	end

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