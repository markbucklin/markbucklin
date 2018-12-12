function x = pos(x)
warning('pos.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% 
% DESCRIPTION:
%		Applies lower limit of 0 to input, returning positive valuesof input, or 0 where input negative
%
% USAGE:
%		>> F = pos(F);
%
% SEE ALSO:
%		NEG, RAIL
%



x = max(0, x);
