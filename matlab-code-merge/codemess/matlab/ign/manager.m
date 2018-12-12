function varargout = manager(key, action, handleObject)
%MANAGER Manage all the scope handles.

%   Author(s): J. Schickler
%   Copyright 2007-2012 The MathWorks, Inc.

% We need to maintain a list of Scope handles in a function workspace for
% performance reasons.  If these handles are not held in a function
% workspace, MATLAB will have difficulty resolving cyclic references
% causing the Workspace and Simulink sources to run extremely slowly.
% Using APPDATA or anonymous function workspaces does not work.  All
% objects must be eventually connected to the Framework object as well.
mlock;
persistent handleMap;

key = genvarname(key);

switch action
    case 'remove'
        if isfield(handleMap, key)
            handleMap.(key) = setdiff(handleMap.(key), handleObject);
        end
    case 'add'
        if isfield(handleMap, key)
            newValue = [handleMap.(key) handleObject];
        else
            newValue = handleObject;
        end
        handleMap.(key) = newValue;
    case 'get'
        if isfield(handleMap, key)
            varargout{1} = handleMap.(key);
        else
            varargout{1} = [];
        end
end

% [EOF]
