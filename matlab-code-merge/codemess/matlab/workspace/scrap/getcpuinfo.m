

%binDir = [matlabroot,filesep,'bin',filesep,'win64'];
[status, cpuInfo] = system(fullfile(matlabroot,'bin','win64','cpuid_info.exe'))
[status, cpuInfo] = system(fullfile(matlabroot,'bin','win64','cpuid_info.exe'))



perftracer = PerfTools.Tracer

microtimer = performance.utils.getMicrosecondTimer

performance.utils.getModuleList