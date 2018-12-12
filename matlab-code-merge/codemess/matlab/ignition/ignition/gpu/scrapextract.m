
if isempty(F)
	F = gpuArray.rand(1024,1024,16,'uint16');
end

[fileName,pathName,fileExt] = uigetfile('*.m','Choose a gpu-kernel function to extract PTX info from');

funcName = strtok(fileName,'.');
t = mtree(fileName,'-file');
funcString = sprintf('@%s',funcName);
funcHandle = eval(funcString);

isCalled = false;
stepIn = 'dbstep IN';

while ~isCalled
	
	dbstop
	
end

