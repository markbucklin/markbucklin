classdef EventDebugger < dynamicprops
	
	
	
	properties
		
		metaprop
	end
	
	
	methods
		function obj = EventDebugger(varargin)
			if nargin > 1
				eventNum = 0;
				for n = 1:2:nargin
					eventNum = eventNum + 1;
					srcObj = varargin{n};
					eventName = varargin{n+1};
					obj.metaprop{eventNum} = addprop(obj,varargin{n+1});
					obj.(obj.metaprop{eventNum}.Name) = addlistener(...
						srcObj,eventName,@(src,evnt)eventListenDisplay(obj,src,evnt));
				end
			end
		end
		function listenTo(obj,srcObj,eventName)
			addlistener(srcObj,eventName,@(src,evnt)eventListenDisplay(obj,src,evnt))
		end
		function eventListenDisplay(obj,src,evnt)
			disp(evnt.EventName)
			% 						evnt.previewEvent
		end
	end
	
	
end

