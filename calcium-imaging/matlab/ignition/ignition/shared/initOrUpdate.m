function updateVal = initOrUpdate( updateFcn, currentVal, updateVal)
% initOrUpdate - convenience function for updating a variable/property that may be initialized as empty
%			>> obj.maxval = initOrUpdate( @max, obj.maxval, newval )


if ~isempty(currentVal)	
	updateVal = feval(updateFcn, currentVal, updateVal);
end
