function val = initIfEmpty( val, initValFcn, varargin)


% todo: support cell arrays
% todo: make similar function fevalIfTrue( cond, fcn, varargin)

if isempty(val)
	
	if isa(initValFcn, 'function_handle')
		val = feval( initValFcn, varargin{:});
		
	elseif ischar(initValFcn)
		val = eval(initValFcn);
		
	else
		error('Value initialization function must be a function handle or character array')
		
	end
	
end