classdef BehaviorSynchronizedVideo < handle
	
	
	
	
	
	
properties
	FigureHandle
	VideoAxesHandle
	BehaviorAxesHandle
end
	properties
		InitFlag = false
	end
	
	
	
	
	
	
	
	methods
		function obj = BehaviorSynchronizedVideo(figHandle)
			if nargin 
				obj.FigureHandle = figHandle;
			else
				obj.FigureHandle = figure;
			end				
		end
		function initialize(obj, videoData, behaviorData, timeStamp)
			
			
			%ignition.util.setAutoProps2Manual(obj.VideoAxesHandle)
			%ignition.util.setAutoProps2Manual(obj.BehaviorAxesHandle)
			
		end
		function update(obj, videoData, behaviorData, timeStamp)
			if nargin < 4
				timeStamp = [];
			end
			if ~obj.InitFlag
				initialize(obj, videoData, behaviorData, timeStamp);
			end
			
			
			
			
			
		end
		
		
		
	end
	
	
	
	
	
	
	
	
	
	
	
	
end























