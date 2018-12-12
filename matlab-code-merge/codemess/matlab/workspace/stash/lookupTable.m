function table = lookupTable(varargin)
%   Creates a lookup table for a collection of key/value pairs.  Keys can
%   be ANY data-type (although indexing over function handles might
%   produce unexpected/incorrect behavior)
%
%   Examples:
%
%       weatherStruct = struct('clouds', 'rain', 'windy', 'cold');
%       obj = weatherObject(weatherStruct, ... ); 
%       tbl = lookupTable('today''s weather', weatherStruct,     ...
%                                obj        ,'found weather obj',...
%                              0.0123       ,'random data here');
%
%       A = tbl('today''s weather')
%         = weatherStruct
%
%       A = tbl(obj)
%         = 'found weather obj'
%
%       A = tbl(0.0123)
%         = 'random data here'
%
%       k = tbl.key(1)   %equal to first element of key
%         = 'today''s weather'
%
%       v = tbl.value(2) %equal to second element of value
%         = 'found weather obj'
%
%       key = tbl.contents('-key'), and value = tbl.contents('-value')
%       return the table's key and value data
%
%
%       KEYWORDS: lookup table, function handle, cell, cellfun

%Check input args:
num = numel(varargin);
assert(~rem(num,2),'lookupTable:badNargin',...
    'nargin == %g, lookupTable takes an even number of input arguments',nargin)
%Make function handle:
table = makeLookupTable(varargin{:});

    function table = makeLookupTable(varargin)
        enum  = 1:2:num;
        key   = {varargin{enum}};
        value = {varargin{enum+1}};

        table.lookup   = @(param)value(...
                       cellfun(@(x)isequal(param,x),key)...
                       );
                   
        table.key      = @(varargin)key{...
                       varargin{:}...
                       };
                   
        table.value    = @(varargin)value{...
                       varargin{:}...
                       };
                   
        table.contents = @getTableContents;
        
        function contents = getTableContents(param)
            switch param
                case '-key'
                    contents = arrayfun(@(k)table.key(k),1:(num/2),'UniformOutput',false);
                case '-value'
                    contents = arrayfun(@(k)table.value(k),1:(num/2),'UniformOutput',false);
                otherwise
                    error('lookupTable:badReference',...
                        'Bad reference, valid parameters are ''-key'' and ''-value''')
            end
        end
    end
end
