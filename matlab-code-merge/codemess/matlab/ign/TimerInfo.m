classdef TimerInfo < event.EventData
    % Information associated with the TimerFired event of a internal.IntervalTimer.
        
    % Copyright 2010 The MathWorks, Inc.
    % $Revision: 1.1.6.1 $  $Date: 2010/09/15 11:12:25 $

    properties
        Time
        ExecutionCount 
    end
    
    methods
        function obj = TimerInfo(executionCount)
        % Constructor
            obj.Time = clock;
            obj.ExecutionCount = executionCount;
        end
    end
end
