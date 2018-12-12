function x = wrapUnsignedInteger(x, xmax)

if x > xmax
	x = mod(x, xmax) + 1;
end
	






