
tosec = @(s) uint32(floor(s));
fromSeconds = @(s) struct('s',tosec(s), 'ns',uint32((s-single(tosec(s)))*1e6)*uint32(1e3));

us2s = @(us) uint32(floor(single(us)/single(1e6)));
fromMicros = @(us) struct('s', us2s(us), 'ns', (us - (us2s(us)*1e6))*1e3);

test = @(t) struct('fromSeconds',fromSeconds(t),'fromMicros',fromMicros(uint32(t*1e6)));
displayStruct(test(cputime))