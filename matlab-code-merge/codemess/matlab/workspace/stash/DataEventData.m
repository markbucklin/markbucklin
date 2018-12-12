classdef DataEventData < event.EventData
    %DataEventData   Define the DataEventData class.

    %   Copyright 2012 The MathWorks, Inc.

    properties (SetAccess = protected)
        Data;
    end

    methods

        function this = DataEventData(newData)
            %DataEventData   Construct the DataEventData class.
            this.Data = newData;
        end
    end
end

% [EOF]
