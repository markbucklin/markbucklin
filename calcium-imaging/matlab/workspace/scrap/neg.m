function x = neg(x)
warning('neg.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% 
% DESCRIPTION:
%		Applies lower limit of 0 to input, returning negative values of input, or 0 where input positive
%
% USAGE:
%		>> F = neg(F);
%
% SEE ALSO:
%		POS, RAIL
%



x = min(0, x);
