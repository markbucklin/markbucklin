classdef (CaseInsensitiveProperties, TruncatedProperties) ...
		TaskLink ...
		< ign.core.UniquelyIdentifiable ...
		& ign.core.CustomDisplay ...
		& ign.core.Handle ...
		& matlab.mixin.Heterogeneous
% TODO -> Inherit from FrameBuffer or ViceVersa???	
	
	
	
	% SOURCE (UPSTREAM) & TARGET (DOWNSTREAM)
	properties (SetAccess = protected)
		SourceTaskOutput
		TargetTaskInput
		Enabled = false
		DataEventsDisabled = false;
	end
	
	properties (SetAccess = protected)
		NewDataListener		% -> DataAvailable
		DataReadListener	% -> SpaceAvailable
	end
	
	
	
	events (NotifyAccess = protected)
		Closed
		Opened
	end
	
	
	
	
	methods
		function obj = TaskLink( sourceTaskOutput, targetTaskInput)
			
			% ASSIGN SOURCE & TARGET OF THIS LINK (TASKOUTPUT & TASKINPUT)
			obj.SourceTaskOutput = sourceTaskOutput;
			obj.TargetTaskInput = targetTaskInput;
			
			% ATTACH LISTENER TO PRODUCTION OF NEW DATA FROM UPSTREAM TASK
			newDataFcn = @(~,evt) transferData( evt.AffectedObject, targetTaskInput );
			obj.NewDataListener = addlistener( ...
				sourceTaskOutput, 'Data', 'PostSet', newDataFcn );
			obj.NewDataListener.Recursive = true; % todo->check
			
			% ATTACH LISTENER TO CONSUMPTION OF DATA BY DOWNSTREAM TASK
			signalReadyFcn = @(~,~) fprintf( 'DataRead\n'); % todo -> fire empty notification
			% signalReadyFcn = @(~,~) notify(sourceTaskOutput, 'Empty')
			obj.DataReadListener = addlistener( ...
				targetTaskInput, 'Data', 'PostGet', signalReadyFcn );
			
			
		end
		function open(obj)
			
			[obj.Enabled] = deal(true);						
			notify(obj, 'Opened');
			
		end
		function close(obj)			
			
			[obj.Enabled] = deal(false);			
			notify(obj, 'Closed');
			
		end
		function delete(obj)
			try
				delete(obj.NewDataListener)
				delete(obj.DataReadListener)
			catch
			end
		end
	end
	
	
	% todo -> perhaps better to wrap Data transfer with EventData message
	%{
	methods(Access='private')
		function onDataReceived(obj)
			% Handle data received event from engine.
			
			% Notify any listeners with the amount of data available.
			% If no data is available to read, don't send the event.
			count = obj.SourceTaskOutput.DataAvailable;
			if count > 0
				notify(obj.SourceTaskOutput, 'DataWritten', ...
					ign.core.tasks.DataEventInfo(count));
			end
		end
		function onDataSent(obj)
			% Handle data sent event from engine.
			
			% Notify any listeners with the amount of space available.
			% If no space is available to write, don't send the event.
			space = obj.TargetTaskInput.SpaceAvailable;
			if space > 0
				notify(obj.TargetTaskInput, 'DataRead', ...
					ign.core.tasks.DataEventInfo(space));
			end
		end
	end
	%}
	
	

	
	
end


% TRANSFER FUNCTION -> RESPONSE TO NEW DATA EVENT
function transferData( sourceTaskOutputObj, targetTaskInputObj )
% todo -> try
if numel(targetTaskInputObj) == 1
	targetTaskInputObj.Data = sourceTaskOutputObj.Data;
else
	[targetTaskInputObj.Data] = deal(sourceTaskOutputObj.Data);
end
end



