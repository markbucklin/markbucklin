function v = array2str(v, prec)

if ~isnumeric(v)
	switch class(v)
		case 'cell'
			v = cellfun(@array2str,v,'UniformOutput',false);
			return
		case 'function_handle'
			v = array2str( feval(v));
			return
		otherwise
			error( sprintf('%s:UnknownInput',mfilename),...
				['Input to array2str must be numeric, '
				'a cell array with numeric contents, '
				'or a function_handle that evaluates to numeric output']...
				);
	end
	end
	
	if isempty(v)
		v = '[]';
		return;
	end
	
	if nargin < 2, prec = 11; end
	
	[r,c] = size(v);
	
	if r > 1
		if c > 1
			
			for indx = 1:r
				cstr{indx} = array2str(v(indx, :), prec);
			end
			
			cstr{1}(end) = [];
			for indx = 2:r-1
				cstr{indx}(1)   = ' ';
				cstr{indx}(end) = [];
			end
			cstr{end}(1) = ' ';
			
			v = sprintf('%s\n', cstr{:});
			v(end) = [];
			
		else
			cstr{1} = sprintf('[%s', array2str(v(1), prec));
			for indx = 2:r
				cstr{indx} = sprintf(' %s', array2str(v(indx), prec));
			end
			cstr{end} = sprintf('%s]', cstr{end});
			v = sprintf('%s\n', cstr{:});
			v(end) = [];
		end
	else
		if c > 1
			cstr = cell(1, length(v));
			
			for indx = 1:c
				cstr{indx} = [array2str(v(indx), prec) ' '];
			end
			
			v = ['[' deblank([cstr{:}]) ']'];
		else
			v = num2str(v, prec);
		end
	end