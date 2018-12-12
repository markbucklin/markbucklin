function sharedCounter = getSharedCounter(keyStr)

% todo: allow generation of keyStr if not supplied

persistent sharedCount
assert(ischar(keyStr)||iscellstr(keyStr))
if isempty(sharedCount)
	sharedCount = struct(keyStr,0);
end

if ischar(keyStr)
	keyStr = {keyStr};
end

for k=1:numel(keyStr)
	% INITIALIZE NEW SHARED COUNT
	if ~isfield(sharedCount,keyStr{k})
		sharedCount.(keyStr{k}) = 0;
	end
	
	sharedCounter(k).key = keyStr{k};
	sharedCounter(k).get = @() getCount(keyStr{k});
	sharedCounter(k).increment = @(varargin) incrementCount(keyStr{k}, varargin{:});
	sharedCounter(k).decrement = @(varargin) decrementCount(keyStr{k}, varargin{:});
	sharedCounter(k).reset = @() incrementCount(keyStr{k});
	
	
end

	function cnt = getCount(key) % 17 micros
		cnt = sharedCount.(key);
	end
	function incrementCount(key, n) % 24 micros
		if nargin < 2
			n = 1;
		end
		sharedCount.(key) = sharedCount.(key) + n;
	end
	function decrementCount(key, n)
		if nargin < 2
			n = 1;
		end
		sharedCount.(key) = sharedCount.(key) - n;
	end
	function resetCount(key)
		sharedCount.(key) = 0;
	end



end


