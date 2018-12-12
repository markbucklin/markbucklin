warning('featureScraps.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
warning('featureScraps.m being called from scrap directory: Z:\Files\ignition\ignition\scrap')
version -java
feature getpid

% md = feature('dumpmem')

% force garbage collection
java.lang.System.gc
feature('GpuAllocPoolSizeKb',0)


ci = getcallinfo(which('ignition.System'))
o = mtree('ignition.System')
% matlab.internal.getcode





% 	NET.addAssembly('System.Speech');
% ss = System.Speech.Synthesis.SpeechSynthesizer; 
% ss.Volume = 100 
% Speak(ss,'You can use .NET Libraries in MATLAB')
	
