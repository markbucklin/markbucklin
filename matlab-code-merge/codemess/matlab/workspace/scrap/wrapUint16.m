function y = wrapUint16(x)
warning('wrapUint16.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if x > 65535
	y = uint16(mod(x, 65535) + 1);
else
	y = uint16(x);
end
	






