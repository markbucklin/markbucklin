function x = wrapUnsignedInteger(x, xmax)
warning('wrapUnsignedInteger.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if x > xmax
	x = mod(x, xmax) + 1;
end
	






