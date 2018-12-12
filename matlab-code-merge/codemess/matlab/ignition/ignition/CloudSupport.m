
%   Copyright 2013-2015 The MathWorks, Inc.

classdef (Hidden, Sealed) CloudSupport < handle
    
    properties ( Transient, Access = private )
        Support = parallel.internal.cluster.MJSSupport.empty;

        UsePeerLookup = true;
        ReadableMJSAccessFactory
        ReadWriteMJSAccessFactory
        ShouldReactToClusterOnline = false;
    end
    
    properties ( Transient, SetAccess = immutable, GetAccess = private )
        ClusterDetailsFunc
        Cache
        Notifier = []
    end
    
    properties ( Transient )
        % Local copy of the cluster details fetched from cloud console
        ClusterDetails
        Identifier = '';
    end

    methods
        function obj = CloudSupport( clusterDetails, ...
                clusterDetailsFunc, identifier, usePeerLookup,...
                cache, readableAccessFactory, readWriteAccessFactory, notifier )
            obj.ClusterDetails = clusterDetails;
            obj.ClusterDetailsFunc = clusterDetailsFunc;
            obj.Identifier = identifier;
            obj.UsePeerLookup = usePeerLookup;
            obj.Cache = cache;
            obj.ReadableMJSAccessFactory = readableAccessFactory;
            obj.ReadWriteMJSAccessFactory = readWriteAccessFactory;
            if nargin > 7
                obj.Notifier = notifier;
            end
            
            % Try to create the support object
            try
                obj.Support = obj.getSupport();
            catch E
                obj.Support = parallel.internal.cluster.MJSSupport.empty();
                % Catch the case where we can have a valid cluster but no support object
                if ~( strcmp(E.identifier,'parallel:cluster:MJSComputeCloud:ClusterNotReady') || ...
                      strcmp(E.identifier,'parallel:cluster:MJSComputeCloud:ClusterNotRunning') || ...
                      strcmp(E.identifier,'parallel:cluster:MJSComputeCloud:ClusterDeleted') )
                    throw(E);
                end
            end
        end

        function tf = isConnected( obj )
            tf = ~isempty( obj.Support ) && obj.Support.isConnected();
        end
        
    end
    
    methods (Access = ?parallel.cluster.MJSComputeCloud)
        function [serverVersion, minimumCompatibleVersion] = getVersionInformation( obj )
            [serverVersion, minimumCompatibleVersion] = obj.Support.getVersionInformation();
        end        
    end

    methods ( Access = ?parallel.cluster.MJSCloudCluster )
        
        function newState = refreshState( obj )            
            try
                obj.ClusterDetails = obj.ClusterDetailsFunc( obj.Identifier, obj.ClusterDetails );
                % Update the cluster identifier if it has changed. See
                % g1252412.
                newIdentifier = char( obj.ClusterDetails.getClusterID() );
                if ~strcmp( newIdentifier, obj.Identifier )
                    obj.Identifier = newIdentifier;
                end
            catch E
                dctSchedulerMessage( 1, 'Failed to refresh cloud cluster state. Original error: %s', ...
                    E.getReport() );
                throw(E);
            end

            % Get the state from cloud center. If we can get the support object, and the
            % communication check succeeds then the state will be updated to 'online'.
            newState = obj.getVisibleClusterStateFromClusterDetails();
            
            % If we have a support, but the new state means it will not work, we must not
            % try to communicate with it, otherwise the reported state will be wrong
            if obj.isHeadnodeAvailable()
                if isempty( obj.Support )
                    % We have updated state. Try to get a support just in
                    % case we now can
                    try
                        obj.Support = obj.getSupport();
                        % we need to ensure we have a writable access
                        obj.switchToWritableAccess(obj.Support);
                        newState = parallel.internal.types.MJSComputeCloudStates.Ready;
                    catch E %#ok<NASGU>
                        obj.setSupportToEmptyAndNotify();
                        newState = parallel.internal.types.MJSComputeCloudStates.Error;
                    end                        
                else
                    % Check the support we have to make sure the
                    % user-visible state is correct. Pass in the new
                    % cluster details to save another call to cloud console
                    try
                        % we need to ensure we have a writable access
                        obj.switchToWritableAccess(obj.Support);
                        obj.Support = ...
                            obj.checkExistingSupportAndRecreateIfNecessary( obj.ClusterDetails );
                        newState = parallel.internal.types.MJSComputeCloudStates.Ready;
                    catch E
                        dctSchedulerMessage( 4, 'Unable to refresh state. Original error: %s', E.getReport() );
                        % We do not set the support object to empty() here, because if we did
                        % that the next time the state is refreshed we will attempt to create
                        % a support. This may fail and we'll get a failed to build support
                        % error. However in the case of a communication error it is more
                        % helpful to leave the support intact, so that we will always report
                        % the communication error.
                        if strcmp( E.identifier, 'parallel:cluster:MJSComputeCloud:ConnectionToClusterFailed' )
                            newState = parallel.internal.types.MJSComputeCloudStates.CommunicationError;
                        elseif strcmp( E.identifier, 'parallel:cloud:CannotChangeNumWorkersWhenRunning' )
                            % For MPC clusters we need to let this error propagate because 
                            % otherwise we could end up with an unusable cluster object,
                            % which would cause an unhelpful error later; in parpool for example.
                            rethrow(E);
                        else
                            newState = parallel.internal.types.MJSComputeCloudStates.Error;
                        end
                    end
                end
            else
                if ~obj.isSupportUsingGDSJobsAccess()
                    % Support only needs to be emptied if we had been
                    % communicating with a jobManager
                    obj.setSupportToEmptyAndNotify();
                end
            end
        end      

        function newjob = buildChild( obj, mjs, variant, jobId, jobSId )
            import parallel.job.MJSIndependentJob
            import parallel.job.MJSCommunicatingJob
            import parallel.job.MJSConcurrentJob
            import parallel.internal.types.Variant

            try
                switch variant
                  case Variant.IndependentJob
                    newjob = MJSIndependentJob( ...
                        mjs, jobId, jobSId, obj );
                  case Variant.ConcurrentJob
                    newjob = MJSConcurrentJob( ...
                        mjs, jobId, jobSId, obj );
                  case { Variant.CommunicatingSPMDJob, ...
                         Variant.CommunicatingPoolJob }
                    newjob = MJSCommunicatingJob( ...
                        mjs, jobId, variant, jobSId, obj );
                  otherwise
                    error(message('parallel:cluster:MJSUnexpectedType'));
                end
            catch E
                throw( distcomp.handleJavaException( obj, E ) );
            end

        end

    end

    methods ( Access = private )
        support = getSupport( obj )

        newState = getVisibleClusterStateFromClusterDetails( obj )

        [newSupport, supportOK] = checkExistingSupportAndRecreateIfNecessary( obj, varargin )
        
        function setSupportToEmptyAndNotify(obj)
            obj.Support = parallel.internal.cluster.MJSSupport.empty();
            cloudStateNotifier = parallel.internal.cloud.CloudStateNotifier.getInstance();
            cloudStateNotifier.notifyOffline();
        end        
        
        function varargout = invokeWithSupportAndRetry( obj, fcn, errFcn )
            % Invokes the provided function on the support object and retries if this
            % fails. If the provided function throws an error on the second attempt
            % we rethrow the error. If getting the support fails then the provided
            % error function is called (for example displayable items may wish to
            % swallow the error and return a default value).

            try
                support = obj.getSupport();
            catch err
                obj.setSupportToEmptyAndNotify();
                if nargin < 3
                    rethrow( err );
                else
                    [varargout{1:nargout}] = errFcn( err );
                    return
                end
            end

            attemptsLeft = 2;
            while attemptsLeft > 0
                attemptsLeft = attemptsLeft - 1;
                try
                    if obj.ShouldReactToClusterOnline
                        obj.switchToWritableAccess(support);
                        obj.ShouldReactToClusterOnline = false;
                    end
                    [varargout{1:nargout}] = fcn( support );
                    % Once we have succeeded we want to set the working support
                    % object back.
                    obj.Support = support;
                    return
                catch E
                    % If the error is due to the cluster being unexpectedly stopped,
                    % don't attempt to retry anymore, just throw the exception.
                    if ~strcmp(E.identifier, 'parallel:cloud:ForcefullyStopped') && attemptsLeft > 0
                        [support, supportOK] = obj.checkExistingSupportAndRecreateIfNecessary();
                        if supportOK
                            % If the support was ok, then we should not try
                            % again.
                            rethrow( E );
                        end
                    else
                        obj.setSupportToEmptyAndNotify();
                        rethrow( E );
                    end
                end
            end
            
        end        

        function ok = isHeadnodeAvailable( obj )

            import com.mathworks.toolbox.distcomp.wsclients.cloudconsole.CloudConsoleClusterDetails
            import parallel.internal.types.CloudConsoleStates
            import parallel.internal.types.MJSComputeCloudStates
            
           
            if isa( obj.ClusterDetails, 'com.mathworks.toolbox.distcomp.wsclients.cloudconsole.CloudConsoleClusterDetails' )

                headNodeName = char( obj.ClusterDetails.getClusterHeadNodeDNSName() );
                cloudConsoleClusterState = CloudConsoleStates.fromName( char( obj.ClusterDetails.getClusterState() ) );

                % Make sure that only states with a running job manager are
                % allowed
                ok = cloudConsoleClusterState == CloudConsoleStates.Ready &&  ...
                        ~isempty(headNodeName);
            else
                ok = false;
            end
        end

        function err = clusterStoppedErr( obj )
            err = MException(message('parallel:cluster:MJSComputeCloud:ClusterNotRunning', char( obj.ClusterDetails.getClusterName() )));
        end

        function err = commsErr( obj )
            clusterName = char( obj.ClusterDetails.getClusterName() );
            err = MException(message('parallel:cluster:MJSComputeCloud:ConnectionToClusterFailed', clusterName));
        end

        function err = clusterNotReadyErr(obj)
            clusterName = char( obj.ClusterDetails.getClusterName() );
            err = MException(message('parallel:cluster:MJSComputeCloud:ClusterNotReady', clusterName));
        end
        
        function tf = isSupportUsingGDSJobsAccess(obj)
            tf = ~isempty(obj.Support) && ...
                ~obj.Support.IsWritable && ...
                isa(obj.ReadableMJSAccessFactory, 'parallel.internal.cluster.GDSJobsAccessFactory');
        end
        
        function switchToWritableAccess(obj, support)
            % Checks the cluster was not instructed to shut down before
            % switching to writable access
            parallel.cluster.Cloud.hErrorIfClusterShuttingDown(obj.Identifier);
            
            % continue to switch to writable as indicated
            support.switchToWritableAccess();
        end
    end
    
    methods ( Hidden )
        function hSetClusterID( obj, identifier )
            obj.Identifier = identifier;
        end

        function hSetClusterDetails( obj, clusterDetails )
            obj.ClusterDetails = clusterDetails;
        end
        
        function hHandleOnlineEvent(obj, ~, ~)
            obj.ShouldReactToClusterOnline = true;
        end
        
        function hHandleOfflineEvent(obj, ~, ~)
            obj.Support = parallel.internal.cluster.MJSSupport.empty();
            obj.ShouldReactToClusterOnline = false;
        end        
    end
    
% Static helpers
% -------------------------------------------------------------------------

    methods ( Static, Access = private )
        
        function [ok, msg] = doCheckTwoWayCommunications( forceCheck, support )
            [ok, msg] = support.checkTwoWayCommunications( forceCheck );
            % TODO: This check may fail due to a race condition (g861728). As a short-term
            % fix we will retry here if the communication test fails. This should be removed
            % as part of g862303.
            if ~ok
                [ok, msg] = support.checkTwoWayCommunications( true );
            end            
        end
        
    end
    
% Forwarding methods to MJSSupport
% -------------------------------------------------------------------------
    methods

        function [ok, msg] = checkTwoWayCommunications( obj, forceCheck )
        % As we are checking communications with the support itself, we
        % don't want to use invokeWithSupportAndRetry
            support = obj.Support;
            if isempty( support )
                ok = false;
                msg = message('parallel:cloud:SupportEmptyCommCheck').getString();
                return
            end
            [ok, msg] = parallel.internal.cloud.CloudSupport.doCheckTwoWayCommunications( forceCheck, support );
        end 
                
        function waitForMJS( obj )
            fcn = @(s) waitForMJS( s );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function updated = updateMJSAccess( obj )
            fcn = @(s) updateMJSAccess( s );
            updated = obj.invokeWithSupportAndRetry( fcn );
        end   
        
        function job = getJobFromUUID( obj, mjs, jobUUID, jobTypeOrVariant )
            fcn = @(s) getJobFromUUID( s, mjs, jobUUID, jobTypeOrVariant );
            job = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function tasks = getTaskFromUUID( obj, job, jobUUID, taskUUID )
            fcn = @(s) getTaskFromUUID( s, job, jobUUID, taskUUID );
            tasks = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function jl = getJobs( obj, mjs )
            fcn = @(s) getJobs( s, mjs );
            jl = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function varargout = getJobsByState( obj, mjs )
            fcn = @(s) getJobsByState( s, mjs );  
            [varargout{1:nargout}] = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function [ p, q, r, f ] = enumerateJobsInStates( obj )
            fcn = @(s) enumerateJobsInStates( s );
            [ p, q, r, f ] = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function job = buildJob( obj, mjs, variant, entitlement, varargin )
            % There is an optional argument which is the username
            fcn = @(s) buildJob( s, mjs, variant, entitlement, varargin{:} );
            job = obj.invokeWithSupportAndRetry( fcn );
        end
                
        function [connMgr, strategy] = buildConnectionManager( obj )
            fcn = @(s) buildConnectionManager( s );
            [ connMgr, strategy ] = obj.invokeWithSupportAndRetry( fcn );
        end
        
    end
    
    methods  % Callback support
        function registerForJobEvents( obj, mjs, jobSId )
            fcn = @(s) registerForJobEvents( s, mjs, jobSId );
            obj.invokeWithSupportAndRetry( fcn );
        end
        function unregisterForJobEvents( obj, mjs, jobSId )
            fcn = @(s) unregisterForJobEvents( s, mjs, jobSId );
            obj.invokeWithSupportAndRetry( fcn );
        end
        function registerForTaskEvents( obj, mjs, taskSId )
            fcn = @(s) registerForTaskEvents( s, mjs, taskSId );
            obj.invokeWithSupportAndRetry( fcn );
        end
        function unregisterForTaskEvents( obj, mjs, taskSId )
            fcn = @(s) unregisterForTaskEvents( s, mjs, taskSId );
            obj.invokeWithSupportAndRetry( fcn );
        end
        function stashCluster( obj, mjs )
            fcn = @(s) stashCluster( s, mjs );
            obj.invokeWithSupportAndRetry( fcn );
        end
        function unstashCluster( obj, mjs )
            fcn = @(s) stashCluster( s, mjs );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function jobsCell = getJobsFromTypeAndIdArray( obj, mjs, typeAndIdArray )
            fcn = @(s) getJobsFromTypeAndIdArray( s, mjs, typeAndIdArray );
            jobsCell = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function job = createJobFromUUID( obj, mjs, jobUUID, jobTypeOrVariant )
            fcn = @(s) createJobFromUUID( s, mjs, jobUUID, jobTypeOrVariant );
            job = obj.invokeWithSupportAndRetry( fcn );
        end
     end    
    
     methods % ClusterSupport
        function pauseQueue( obj )
            fcn = @(s) pauseQueue( s );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function resumeQueue( obj )
            fcn = @(s) resumeQueue( s );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function logout( obj, userIdentity )
            fcn = @(s) logout( s, userIdentity );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function changePassword( obj, userIdentity )
            fcn = @(s) changePassword( s, userIdentity );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function promoteJob( obj, jobSId )
            fcn = @(s) promoteJob( s, jobSId );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function demoteJob( obj, jobSId )
            fcn = @(s) demoteJob( s, jobSId );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function getClusterLogs( obj, saveLocation )
            fcn = @(s) getClusterLogs( s, saveLocation );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function w = getWorkers( obj, mjs, type )
            fcn = @(s) getWorkers( s, mjs, type );
            supportErrFcn = @( err ) parallel.cluster.MJSWorker.empty();
            w = obj.invokeWithSupportAndRetry( fcn, supportErrFcn );
        end
        
        function val = getOperatingSystem( obj, mjs )
            % Return an empty string if getting the support fails.
            supportErrFcn = @( err ) '';
            fcn = @(s) getOperatingSystem( s, mjs );
            val = obj.invokeWithSupportAndRetry( fcn, supportErrFcn );
        end
        
        function val = getClusterProperties( obj, propNames )
            fcn = @(s) getClusterProperties( s, propNames );
            val = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function setClusterProperties( obj, propNames, propVals )
            fcn = @(s) setClusterProperties( s, propNames, propVals );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function val = requiresMathWorksHostedLicensing( obj )
            fcn = @(s) requireMathWorksHostedLicensing( s );
            val = obj.invokeWithSupportAndRetry( fcn );
        end
     end
     
     methods % JobSupport
        % NB: 'jobSId' is a 2-cells containing { variant, jobUUID }
        % where jobUUID is an array of UUIDs for this variant
        function v = getJobProperties( obj, jobSId, propName )
             fcn = @(s) getJobProperties( s, jobSId, propName );
             v = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function setJobProperties( obj, jobSId, propName, val )
            fcn = @(s) setJobProperties( s, jobSId, propName, val );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function tf = isLeadingTask( obj, jobSId, taskSId )
            fcn = @(s) isLeadingTask( s, jobSId, taskSId );
            tf = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function id = getLeadingTaskID( obj, jobSId )
            fcn = @(s) getLeadingTask( s, jobSId );
            id = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function cw = buildCancelWatchdog( obj, jobSId, msg, timeout )
            fcn = @(s) buildCancelWatchdog( s, jobSId, msg, timeout );
            cw = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function tl = getTasks( obj, job, jobSId )
            fcn = @(s) getTasks( s, job, jobSId );
            tl = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function tasks = buildTasks( obj, job, jobSId, taskInfoCell )
            fcn = @(s) buildTasks( s, job, jobSId, taskInfoCell );
            tasks = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function listenerInfoArray = createListenerInfoArrayForAllEvents( obj )
            fcn = @(s) createListenerInfoArrayForAllEvents( s );
            listenerInfoArray = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function cancelOneJob( obj, jobSId, cancelException )
            fcn = @(s) cancelOneJob( s, jobSId, cancelException );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function destroyOneJob( obj, jobSId )
            fcn = @(s) destroyOneJob( s, jobSId );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function [jobUUID, jobAccess] = prepareJobForSubmission( obj, job, jobSId )
            fcn = @(s) prepareJobForSubmission( s, job, jobSId );
            [jobUUID, jobAccess] = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function submitJob( obj, job, jobSId )
            fcn = @(s) submitJob( s, job, jobSId );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function info = getJobDataStoreInfo( obj )
            fcn = @(s) getJobDataStoreInfo( s );
            info = obj.invokeWithSupportAndRetry( fcn );
        end
     end
    
    methods % TaskSupport
        % NB: 'taskSId' is a 2-cell containing { variant, taskUUID }
        function w = getWorkerForTask( obj, mjs, taskSId )
            fcn = @(s) getWorkerForTask( s, mjs, taskSId );
            w = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function v = getTaskProperties( obj, taskSId, propName )
            fcn = @(s) getTaskProperties( s, taskSId, propName );
            v = obj.invokeWithSupportAndRetry( fcn );
        end
        
        function setTaskProperties( obj, taskSId, propName, val )
            fcn = @(s) setTaskProperties( s, taskSId, propName, val );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function destroyOneTask( obj, jobSId, taskSId )
            fcn = @(s) destroyOneTask( s, jobSId, taskSId );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function cancelOneTask( obj, taskSId, cancelException )
            fcn = @(s) cancelOneTask( s, taskSId, cancelException );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function rerunOrCancelOneTask( obj, taskSId, cancelException )
            fcn = @(s) rerunOrCancelOneTask( s, taskSId, cancelException);
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function submitTaskResult( obj, taskSId, outputItemArray, ...
                errorBytes, error_message, error_id, ...
                warnings, diaryItemArray )
            fcn = @(s) submitTaskResult( s, taskSId, outputItemArray, ...
                errorBytes, error_message, error_id, ...
                warnings, diaryItemArray );
            obj.invokeWithSupportAndRetry( fcn );
        end
        
        function info = getTaskDataStoreInfo( obj )
            fcn = @(s) getTaskDataStoreInfo( s );
            info = obj.invokeWithSupportAndRetry( fcn );
        end
    end
end     
