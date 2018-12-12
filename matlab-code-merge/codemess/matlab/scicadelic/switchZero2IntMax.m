function F = switchZero2IntMax(F)
% val = intmax(class(F));
if (F == 0)
	F = uint16(65535);
end


