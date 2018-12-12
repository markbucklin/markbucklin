classdef WarningCleanup < handle
    %WarningCleanup   Define the WarningCleanup class.
    
    %   Copyright 2010 The MathWorks, Inc.

    properties (Access = private)

        LastWarningState;
    end

    methods

        function this = WarningCleanup(varargin)
            %WarningCleanup   Construct the WarningCleanup class.

            this.LastWarningState = warning('off', varargin{:});
        end

        function delete(this)
            %delete Perform the cleanup
            
            last_warn = warning(this.LastWarningState);  %#ok<NASGU>

        end
    end
end

% [EOF]
