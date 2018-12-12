

import ignition.core.*


% ------ COMPOSITE TASK (CONFIGURABLE/INITIALIZED/SYNCHRONOUS)
obj = ignition.io.FileStreamTask() ; % CompositeTask();


% ------ CONFIGURATION TASK
% OPERATION & TASK
configOp = Operation( @ignition.io.tiff.configureTiffFileStream, 2, 1);
configTask = Task( configOp);
configDep(1) = registerDependency(obj, 'FileInputObj'); % -> requireConfigurableProp(obj)
configDep(2) = registerDependency(obj, 'ParseFrameInfoFcn');
supplyInitialDependency( configTask, configDep );
% configDep(1) = Dependency( @ignition.io.FileWrapper.empty);
% configDep(2) = Dependency( @ignition.io.tiff.parseHamamatsuTiffTag);
% configTask = Task( configOp, configDep);


% ------ INTITIALIZATION TASK
% OPERATION & TASK
initOp = Operation( @ignition.io.tiff.initializeTiffFileStream, 1, 2 );
initTask = Task( initOp);
initDep(1) = registerDependency( configTask, 1 ); % requestStaticDependency
supplyInitialDependency( initTask, initDep ); % todo -> clean up initial crap
% initTask = Task( initOp, initDep );
% initTask = Task( initOp, registerDependency(configTask,1) );




% ------ FRAME-PRODUCER (READ) TASK
% OPERATION & TASK
readOp = Operation( @ignition.io.tiff.readTiffFileStream, 2, 4);
readTask = Task(readOp);
% REQUEST UPSTREAM DEPENDENCIES
readConfigInitDep = registerDependency(initTask, 1); % config
readCacheInitDep = registerDependency(initTask, 2); % cache
readCacheReentrantDep = registerDependency( readTask, 4);
% SUPPLY TASK DEPENDENCIES
supplyStaticDependency( readTask, readConfigInitDep, 1 );
supplyInitialDependency( readTask, readCacheInitDep, 2 );
supplyDependency(readTask, readCacheReentrantDep, 2);
%readDep(1) = supplyStaticDependency( obj, 'Configuration' );









