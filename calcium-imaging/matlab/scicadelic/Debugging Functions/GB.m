function nGB = GB(varname)
% GB: RETURNS THE NUMBER OF GIGABYTES HELD IN MEMORY BY GIVEN INPUT
m = whos('varname');
nGB = m.bytes/2^30;