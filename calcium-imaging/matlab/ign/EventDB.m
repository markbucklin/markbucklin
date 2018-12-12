classdef EventDB < sigutils.internal.emission.PropertyDB
    % Database holding multiple EventDef event definition objects.
    % Used by SystemObjectGenerator to define and emit event definitions
    % in System object files.
    
    % Copyright 2014 The MathWorks, Inc.
    
    methods
        function obj = EventDB(e)
            obj.PropertyList = sigutils.internal.emission.EventDef.empty;
            if nargin>0
                add(obj,e);
            end
        end
    end

    methods(Access=protected)
        function h = getSectionHeader(~)
            h = 'events';
        end
    end
end
