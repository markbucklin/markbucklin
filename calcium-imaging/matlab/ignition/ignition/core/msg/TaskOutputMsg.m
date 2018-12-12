classdef (ConstructOnLoad) TaskOutputMsg  < event.EventData
  
  properties
	 Data
	 BenchTic
  end
  
  methods
	 function eventData = TaskOutputMsg(data, benchTic)
		
		  eventData.Data = data;		
		  eventData.BenchTic = benchTic;
		
	 end
  end
end
