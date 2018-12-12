

pool = gcp;
session = pool.hGetSession();
session.extendShutDownTimeout;
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


dispatch = session.getDispatcher;

dispatchimpl = dispatch.create;

%dispatchimpl.addDispatcher

% rootmsg = dispatch.getRootMessageClass




