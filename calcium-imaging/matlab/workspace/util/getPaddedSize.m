function szOut = getPaddedSize( val, numDims)


% function szOut = getPaddedSize( varargin)
% MULTIPLE INPUT TYPE, CELL ARRAY OR MULTIPLE ARGUMENTS
% argIn = varargin(1:(nargin-1));	
% numDims = varargin{end};
% argSize = cellfun(@size, val, 'UniformOutput', false);
% numDimsIn = cellfun(@numel, argSize);



d = size(val);
szOut = [d , ones(1,numDims-numel(d))];

% DETERMINE NUMBER OF COMMON DIMENSIONS
% todo -> if (nargin > 1) && isscalar(varargin
% numDimsOut = max(numDimsIn);


%padFcn = @(d) [d , ones(1,numDimsOut-numel(d))];
%argSize = cellfun( padFcn, argSize, 'UniformOutput', false);

% todo singleton expansion



% if outTypeCell
% 	% OUTPUT AS CELL ARRAY
% 	szOut = argSize;
% 	
% else
% 	% OUTPUT AS STRUCT
% 	for k = 1:nargin
% 		argName{k} = inputname(k);
% 	end
% 	szOut = cell2struct(argSize(:), argName, 1);
% 	
% end
% 





