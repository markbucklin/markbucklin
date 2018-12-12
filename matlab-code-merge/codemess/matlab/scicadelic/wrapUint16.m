function y = wrapUint16(x)

if x > 65535
	y = uint16(mod(x, 65535) + 1);
else
	y = uint16(x);
end
	






