function showFields(s, showFcn, filterFcn)


if nargin < 3
    filterFcn = @(varargin) true;
end
if nargin < 2
    showFcn = @defaultShowFcn;
end

names = fields(s);
for k=1:numel(names)
    name = names{k};
    val = s.(name);
    if isstruct(val)
        showFields(val, showFcn, filterFcn)
        continue
    end
    
    if filterFcn(val)
        fprintf('Showing: %s\n', name);
        showFcn(val)        
    end
end

end

function defaultShowFcn(x)
if numel(x) <= 10
    disp(x)
else
    disp(description(x))
end
end

function d = description(x)
d = struct(...
    'size',size(x),...
    'class',class(x));
end