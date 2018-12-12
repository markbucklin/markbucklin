classdef MatlabMethodGenerator < sigutils.internal.emission.MatlabFunctionGenerator        
    % Generate a method in a MATLAB class file.

    % Copyright 2014 The MathWorks, Inc.
    
    properties
        Attributes = {}  % String or cell-string of attributes, such as Access=private or Logical
    end
    
    methods
        function obj = MatlabMethodGenerator(varargin)
            % MatlabMethodGenerator(Name,In,Out)
            obj@sigutils.internal.emission.MatlabFunctionGenerator(varargin{:});
            
            % Set a number of options for the MatlabFunctionGenerator to
            % make it work as a method generator.
            %
            obj.RCSRevisionAndDate = false;
            obj.TimeStampInHeader = false;
            obj.CoderCompatible = false;
            obj.EndOfFileMarker = false;
            
            % Generate local functions separately and explicitly for
            % incorporation at the end of a class file.
            obj.GenerateLocalFcnWithPrimaryFcn = false;
        end
        
        function set.Attributes(obj,val)
            if ischar(val)
                val = {val};
            end
            if ~iscell(val)
                error(message('siglib:MATLABGenerator:AttribStr'));
            end
            obj.Attributes = val;
        end
        
        function str = getAttributeStr(obj)
            % Return comma-separated list of attribute strings.
            str = strjoin(obj.Attributes, ', ');
        end
    end
end
