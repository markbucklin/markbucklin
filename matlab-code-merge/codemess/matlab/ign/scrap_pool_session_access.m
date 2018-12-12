

pool = gcp;



%% SESSION
session = pool.hGetSession();
session.extendShutDownTimeout;
% addSessionListener                       getSessionWorkerNotifier                 
% assertStartupWasSuccessful               getTaskQueue                             
% createParforController                   getTransfer                              
% createSpmdController                     hasSessionStarted                        
% destroyClientSession                     hashCode                                 
% equals                                   isPoolManagerSession                     
% extendShutDownTimeout                    isSessionRunning                         
% getClass                                 isSpmdSupported                          
% getClient                                notify                                   
% getClientSessionInfo                     notifyAll                                
% getCompositeAssistant                    releaseCurrentParforController           
% getDispatcher                            removeSessionListener                    
% getErrorHandler                          setRestartOnClusterChange                
% getFileDependenciesAssistant             setShutdownIdleTimeout                   
% getFutureWaiter                          shutdown                                 
% getLabs                                  startSendPathAndClearNotificationToLabs  
% getListenerExecutor                      stopSendPathAndClearNotificationToLabs   
% getMapReduceAssistant                    supports64BitSerialization               
% getPoolSize                              toString                                 
% getResourceManager                       wait                                     
% getRoleCommGroup                         waitForSessionToStart                    
% getRoleMapping 

%% TRANSFER & TRANSFER MANAGER
xfer = session.getTransfer
rcvr = xfer.getDataReceiver
sndr = xfer.getDataSender
xfermgr = xfer.getTransferManager
xfermgr.initiateTransfer

%% CLIENTINFO
clientInfo = session.getClientSessionInfo;
% equals                                 getRunningDurationMillis               
% getClass                               getSessionIdleAt                       
% getClusterType                         getSize                                
% getError                               getStartTime                           
% getFinishTime                          getState                               
% getIdleShutdownTimeout                 hashCode                               
% getNumWorkersBusy                      notify                                 
% getProfileName                         notifyAll                              
% getRemainingSecondsBeforeShutdown      toString                               
% getRestartOnClusterChange              wait                                   
% getRestartOnPreferredNumWorkersChange  

%% DISPATCHER
dispatch = session.getDispatcher;
dispatchimpl = dispatch.create;
%dispatchimpl.addDispatcher
% rootmsg = dispatch.getRootMessageClass

%% FUTURE SUBMISSION
F = uint16(double(intmax('uint16'))*rand(1024,1024,8));
F = gpuArray(F);
pool = gcp;
import parallel.internal.queue.FutureCreation
fut = parallel.FevalFuture( @ignition.stream.gpu.applyHybridMedianFilterGPU, 1, {F} );
spool = struct(pool);
Q = spool.FevalQueue;
submit(fut,Q)
argsOut = cell(1,1);
[argsOut{:}] = fetchOutputs(fut);


import com.mathworks.toolbox.distcomp.util.CancelWatchdog;
            exitCode = 1;
            timeout  = 480;
            cw       = CancelWatchdog( exitCode, timeout );

	