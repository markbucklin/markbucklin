function machineToWorkerMappingInit()
; %#ok Undocumented
% Copyright 2012 The MathWorks, Inc.

% Set up and store GPU info
[myHostName, machineToWorkerMapping, myLabIndex] =  ...
    parallel.internal.cluster.getMachineToWorkerMapping();
gmd = parallel.internal.gpu.GPUClusterMediator.getInstance();
gmd.HostName = myHostName;
gmd.MachineToWorkerMapping = machineToWorkerMapping;
gmd.StoredLabIndex = myLabIndex;

end
