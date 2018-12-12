function nMB = MB(varname)
% GB: RETURNS THE NUMBER OF GIGABYTES HELD IN MEMORY BY GIVEN INPUT
m = whos('varname');
nMB = m.bytes/2^20;