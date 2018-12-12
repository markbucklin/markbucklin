function out = bsxCellFun( fcn, varargin)

% todo!!!!!!!



function cMatch = compareCellContent(ca, cb)
cMatch = false;
try
	if isempty(ca) && isempty(cb)
		cMatch = true;
	elseif all(size(ca) == size(cb)) && isa(ca, class(cb))
		if iscell(ca) && iscell(cb)
			cInnerMatch = cellfun(@compareCellContents, ca(:), cb(:));
			cMatch = all(cInnerMatch(:));
		elseif isstruct(ca) && isstruct(cb)
			cInnerMatch = compareStruct( ca, cb);
			cMatch = all(cInnerMatch(:));
		else
			cMatch = all(ca(:) == cb(:));
		end
	end
catch
end

end
