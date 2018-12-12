function szOut = padSize(varargin)


% MULTIPLE INPUT TYPE, CELL ARRAY OR MULTIPLE ARGUMENTS
if (nargin == 1) && iscell(varargin{1})
	argIn = varargin{1};
	outTypeCell = true;
else
	argIn = varargin;
	outTypeCell = false;
end

% PAD TO EXPAND
argSize = cellfun(@size, argIn, 'UniformOutput', false);
numDimsIn = cellfun(@numel, argSize);

% DETERMINE NUMBER OF COMMON DIMENSIONS
% todo -> if (nargin > 1) && isscalar(varargin
numDimsOut = max(numDimsIn);


padFcn = @(d) [d , ones(1,numDimsOut-numel(d))];
argSize = cellfun( padFcn, argSize, 'UniformOutput', false);

% todo singleton expansion



if outTypeCell
	% OUTPUT AS CELL ARRAY
	szOut = argSize;
	
else
	% OUTPUT AS STRUCT
	for k = 1:nargin
		argName{k} = inputname(k);
	end
	szOut = cell2struct(argSize(:), argName, 1);
	
end






