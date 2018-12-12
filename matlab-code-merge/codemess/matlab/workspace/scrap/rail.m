function F = rail(F, lims)
warning('rail.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% 
% DESCRIPTION:
%		Applies specified limits to data using x = max(x, lims(1)) and x = min(x,lims(2))
%
% USAGE:
%		>> F = rail( F, [lowLim highLim]);
%		>> F = rail( F, [-1 1]);
%
% SEE ALSO:
%		POS, NEG
%

lowLim = cast(lims(1), 'like',F);
highLim = cast(lims(2), 'like',F);
F = max(lowLim, min(highLim, F));

