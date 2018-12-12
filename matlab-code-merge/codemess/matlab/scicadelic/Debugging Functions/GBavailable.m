function nGB = GBavailable()
% GB: RETURNS THE NUMBER OF GIGABYTES AVAILABLE IN PHYSICAL MEMORY

[~, systemMemory] = memory;
nGB = systemMemory.PhysicalMemory.Available/(2^30);


% m = whos('varname');
% nGB = m.bytes/2^30;