classdef Parameter < Simulink.Parameter
%AUTOSAR.Parameter  Class definition.

%   Copyright 2009-2015 The MathWorks, Inc.
properties(PropertyType = 'char', ...
        AllowedValues = {'NotAccessible'; ...
        'ReadOnly';...
        'ReadWrite'}) %#ok<ATUNK>
    SwCalibrationAccess = 'ReadWrite';
end
properties(PropertyType = 'char')
    DisplayFormat = '';
end

  methods
    %---------------------------------------------------------------------------
    function setupCoderInfo(h)
      % Use custom storage classes from this package
      useLocalCustomStorageClasses(h, 'AUTOSAR');
    end
    
    function h = Parameter(varargin)
        %PARAMETER  Class constructor.
        
        % Call superclass constructor with variable arguments
        h@Simulink.Parameter(varargin{:});
    end % end of constructor

  end % methods
  methods (Hidden)
      %-----------------------------------------------------------------------------------------------
      function dlgStruct = getDialogSchema(obj, name)
          helpPages.parameter_help = 'autosar_parameter';
          helpPages.signal_help = 'autosar_signal';
          helpPages.mapfile = '/ecoder/helptargets.map';
          dlgStruct = dataddg(obj, name, 'data', false, helpPages);
      end
  end
end % classdef
