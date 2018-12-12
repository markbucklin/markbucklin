classdef EventDef < sigutils.internal.emission.PropertyDef
    %EventDef Event definition object
    %
    % EventDef(Name,H1Line,Attr,Desc) creates a event
    % definition object for a MATLAB class file.  EventDef objects are
    % intended for use by SystemObjectGenerator to define event
    % definitions in System object files.
    %
    % See also: EventDB, MatlabClassGenerator, SystemObjectGenerator.
        
    % Copyright 2014 The MathWorks, Inc.
    
    methods
        function obj = EventDef(name,h1line,attr,desc)
            % Create a new event definition object.
            % EventDef(Name,H1Line,Attr,desc) defines a new
            % event with Name and single-line summary H1Line as strings.
            % Attributes of the event, such as 'ListenAccess=private' or
            % 'Hidden', may be passed as either a string or a cell-string
            % using Attr.
            
            if nargin>0
                obj.Name = name;
            end
            if nargin>1
                obj.H1Line = h1line;
            end
            if nargin>2
                obj.Attributes = attr;
            end
            if nargin>3
                obj.Help = desc;
            end
        end
        
        function str = getEventDeclStr(obj)
            % Return event declaration, including H1 line, help and name.
            str = renderPropertyDecl(obj);
        end
    end
end
