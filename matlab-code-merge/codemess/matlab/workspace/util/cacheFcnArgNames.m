function argnames = cacheFcnArgNames(argnames, fullpath)
%CACHEFCNARGNAMES Cache argument names passed to parent function.
%   CACHEFCNARGNAMES returns a cell-vector containing strings representing
%   the name of each argument passed to the caller's function interface.
%
%   Empty strings represent arguments that do not have a name.  See
%   INPUTNAME for details on when argument names are returned as empty.

% Copyright 2004-2012 The MathWorks, Inc.

for k = 1:numel(argnames)
    if isempty(argnames{k})
        argnames{k} = '(MATLAB Expression)';
    end
    
    if nargin > 1 && strcmpi(fullpath,'-fullpath')
        fcn_stack = dbstack;
        if length(fcn_stack) > 2
            % get the function name from which the scope was invoked.
            srcpath = getsourcenamefromstack(fcn_stack);
            if ~isempty(argnames{k})
                argnames{k} = sprintf('%s:%s',srcpath, argnames{k});
            end
        end
    end
end

% -------------------------------------------------------------------------
function srcname = getsourcenamefromstack(fcnstack)

fcn_name = '';
idx = strfind(fcnstack(3).file,'.m');
filename = fcnstack(3).file(1:idx-1);
for i = length(fcnstack):-1:3
    % The stack may have many more functions that are not the entry points
    % to the scope instantiation, but are in the dbstack. Add the function
    % name to the path only if the file name matches.
    if strcmpi(strrep(fcnstack(i).file,'.m',''),filename)
        if isempty(fcn_name)
            fcn_name = sprintf('%s',fcnstack(i).name);
        else
            fcn_name = sprintf('%s: %s',fcn_name,fcnstack(i).name);
        end
    end
end
srcname = sprintf('%s',fcn_name);

% [EOF]
