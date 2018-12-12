function isMatch = compareStruct(sA, sB)

% todo -> cleanup, speadup, remove compareCellContents -> make single 'compare' function??
matchSize = size(sA);

try
	if ~isscalar(sA) || ~isscalar(sB)
		sz.a = getPaddedSize(sA,4);
		sz.b = getPaddedSize(sB,4);
		matchSize = max(sz.a , sz.b);
		
		assert( all( (sz.a==1) | (sz.b==1) | (sz.a==sz.b) ), 'Dimension mismatch')
		
		if ~all(sz.a == sz.b)
			% 		if any(sz.a==1) || any(sz.b==0)
			% 			isMatch = false;
			% 			return
			% 		end
			sA = repmat(sA, max(1, sz.b./max(1,sz.a)));
			sB = repmat(sB, max(1, sz.a./max(1,sz.b)));
		end
		
	end
	
	cA = struct2cell(sA);
	cB = struct2cell(sB);
	
	
	isMatch = shiftdim( all( cellfun(@compareCellContent, cA, cB), 1), 1);
	
	
catch
	isMatch = false(matchSize);
end




end

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





% if numel(a) ~= numel(b)
% todo
% 	a = a(:);
% 	b = b(:)'
% 	a = repmat(a, 1,size(b,2))
% 	b = repmat(b, size(a,1), 1)
% end
