function inarg = getInputArguments(names,obj,objdefault)

%
% GETINPUTARGUMENTS  Generate input argument strings for any command by
% comparing the fieldnames NAMES between the instance OBJ and its default
% version OBJDEFAULT
%
 
% Author(s): Erman Korkut 05-Oct-2012
% Copyright 2012 The MathWorks, Inc.

inarg = {};
for ct = 1:numel(names)
    prop = obj.(names{ct});
    if ~isequal(objdefault.(names{ct}),prop)
        if ischar(prop)
            inarg{end+1} = sprintf('''%s'',''%s''',names{ct},prop);
        elseif islogical(prop)
            if prop
                inarg{end+1} = sprintf('''%s'',true',names{ct});
            else
                inarg{end+1} = sprintf('''%s'',false',names{ct});
            end
        else
            inarg{end+1} = sprintf('''%s'',%d',names{ct},prop);
        end            
    end
end
