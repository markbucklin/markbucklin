function sOut = unifyStructArray(sIn, catDim)
warning('unifyStructArray.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if nargin < 2
	catDim = 1;
end

N = numel(sIn);
fn = fields(sIn);
for k=1:numel(fn)
	fld = fn{k};	
	fval = cat(catDim,sIn.(fld));
	if isstruct(fval)
		if numel(fval) > 1
			fval = unifyStructArray(fval, catDim);
		end		
	else
		if isa(fval,'gpuArray')
			fval = gather(fval);
		end
	end
		sOut.(fld) = fval;	
end
