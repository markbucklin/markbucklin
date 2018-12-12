% WarningSuppressor - custom cleanup-style object for warning suppression which
% can also tell you if the suppressed warning occurred since object creation.

% Copyright 2013 The MathWorks, Inc.
classdef (Hidden) WarningSuppressor < handle
    properties (GetAccess = private, SetAccess = immutable)
        SuppressedWarningID
        WarningState
        LastWarningMessage
        LastWarningID
    end
    methods
        function obj = WarningSuppressor(idToSuppress)
            obj.SuppressedWarningID = idToSuppress;
            obj.WarningState = warning('off', idToSuppress);
            [obj.LastWarningMessage, obj.LastWarningID] = lastwarn('');
        end

        function tf = didSuppressedWarningOccur(obj)
        % Return true the SuppressedWarningID occurred.
            [~, id] = lastwarn();
            tf      = strcmp(id, obj.SuppressedWarningID);
        end

        function delete(obj)
        % Restore previous state
            warning(obj.WarningState);
            lastwarn(obj.LastWarningMessage, obj.LastWarningID);
        end
    end
end
