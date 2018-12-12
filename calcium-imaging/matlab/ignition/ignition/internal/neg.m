function x = neg(x)
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
