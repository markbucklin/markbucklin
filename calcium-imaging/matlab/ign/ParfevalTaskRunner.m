%ParfevalStage
% A class that runs a collection of tasks on the given pool.

%   Copyright 2014-2016 The MathWorks, Inc.

classdef (Sealed, Hidden) ParfevalTaskRunner < handle
    
    properties (GetAccess = private, SetAccess = immutable)
        Pool; % The pool to run the given tasks on.
        LengthOfParfevalQueue = 0; % The number of tasks to queue in parfeval
                                   % at any one time. We limit this because
                                   % the data is serialized at the point of
                                   % being queued on parfeval.
    end
    
    properties (Access = private)
        Futures; % A cell array of futures.
        Tasks; % A cell array of function handles
        NumLaunchedTasks = 0; % The current number of launched tasks.
    end
    
    properties
        ProgressCallback; % A callback that is called once per task completion.
        TaskResultCombiner = struct('append', @(taskResult)[]); % A combiner object for task results.
        OutputServer = []; % An object that represents a client-side server that the workers are allowed to communicate with.
    end
    
    methods
        % Construct a parfeval task runner using the given pool that will
        % call the given outputCallback once per task completion.
        function obj = ParfevalTaskRunner(pool, numTasks)
            validateattributes(pool, {'parallel.Pool'}, {'scalar'});
            obj.Pool = pool;
            obj.LengthOfParfevalQueue = 4 * obj.Pool.NumWorkers;
            
            obj.Futures = cell(numTasks, 1);
            obj.Tasks = cell(numTasks, 1);
            obj.ProgressCallback.Progress = @(progress)[];
        end
        
        % Launch a task to run on the pool.
        function launchTask(obj, task)
            if obj.NumLaunchedTasks < obj.LengthOfParfevalQueue
                obj.Futures{obj.NumLaunchedTasks + 1} = obj.doLaunchTask(task);
            else
                obj.Tasks{obj.NumLaunchedTasks + 1} = task;
            end
            obj.NumLaunchedTasks = obj.NumLaunchedTasks + 1;
        end
        
        % Wait for all tasks to finish.
        function wait(obj)
            if obj.NumLaunchedTasks == 0
                return;
            end
            
            obj.ProgressCallback.Progress(0 / obj.NumLaunchedTasks);
            for ii = 1:obj.NumLaunchedTasks
                future = obj.Futures{ii};
                
                obj.waitOnFuture(future);

                diaries = future.Diary;
                if ~iscell(diaries)
                    diaries = {diaries};
                end
                for jj = 1:numel(diaries)
                    if ~isempty(diaries{jj})
                        disp(diaries{jj});
                    end
                end

                
                if ~isempty(future.Error)
                    err = future.Error;
                    if ~iscell(err)
                        err = {err};
                    else
                        err(cellfun(@isempty, err)) = [];
                    end
                        
                    for jj = 1:numel(err)
                        iHandleError(err{jj});
                    end
                    
                    % If iHandleException does not throw an error, that
                    % indicates the error was a Cancellation from the MPI
                    % ring. In such a case, the true error will be in another
                    % future.
                    continue;
                end
                
                taskResult = fetchOutputs(future, 'UniformOutput', false);
                taskResult = vertcat(taskResult{:});
                
                obj.TaskResultCombiner.append(taskResult);
                obj.ProgressCallback.Progress(ii * 100 / obj.NumLaunchedTasks);
                obj.Futures{ii} = [];
                
                if ii + obj.LengthOfParfevalQueue <= obj.NumLaunchedTasks
                    nextTaskToQueue = obj.Tasks{ii + obj.LengthOfParfevalQueue};
                    obj.Futures{ii + obj.LengthOfParfevalQueue} = obj.doLaunchTask(nextTaskToQueue);
                    obj.Tasks{ii + obj.LengthOfParfevalQueue} = [];
                end
            end
        end
        
        % Cancel all remaining tasks.
        function delete(obj)
            if ~isempty(obj.OutputServer)
                obj.OutputServer.close();
            end
            futures = obj.Futures;
            for ii = 1:numel(futures)
                if ~isempty(futures{ii})
                    cancel(futures{ii});
                end
            end
        end
    end
    
    methods (Access = private)
        % Delegate to task dispatch with a visitor pattern to determine
        % whether parfeval or parfevalOnAll should be used to launch the
        % task.
        function future = doLaunchTask(obj, task)
            launchVisitor = iGetPoolTaskLaunchVisitor(obj.Pool);
            future = task.hLaunchTask(launchVisitor);
        end
        
        % Helper function that waits on either a future, or the combination
        % of a future with the OutputServer.
        %
        % The OutputServer requires the MATLAB thread in order to operate.
        % However, we want to catch when the future ends as this is the
        % control logic side of the wait.
        function waitOnFuture(obj, future)
            if ~isempty(obj.OutputServer)
                pollIntervalInMillis = 500;

                outputServer = obj.OutputServer;
                while ~wait(future, 'finished', 0)
                    outputServer.step(pollIntervalInMillis);
                end
            else
                wait(future);
            end
        end
    end
end

% Provide a visitor that launches a task on the given pool
function launchVisitor = iGetPoolTaskLaunchVisitor(pool)
launchVisitor.runOnSingle = @(task) parfeval(pool, @task.run, 1);
launchVisitor.runOnAll = @(task) parfevalOnAll(pool, @task.run, 1);
end

% Handle an error coming back from parfeval.
% This will throw the customer visible error corresponding to what we
% receive from parfeval. The only exception is if MpiShufflerCancelled is
% received, at which point we expect the true error to be on a different
% future.
function iHandleError(err)
if isa(err, 'ParallelException')
    remoteErr = err.remotecause{1};
    if isa(remoteErr, 'ParallelException')
        % This is the result of MapTask or ReduceTask
        % throwing a ParallelException, which indicates an
        % issue with the user code.
        throw(remoteErr);
    end
    switch (remoteErr.identifier)
        case 'parallel:mapreduce:MpiShufflerCancelled'
            % This indicates a error on a different future caused the job to
            % fail. We ignore this in order to report the true error.
            return;
        case {'MATLAB:UndefinedFunction', ...
                'parallel:fevalqueue:CouldNotInterpretFunction'}
            % There are several different ways that an undefined error
            % could be reported to us, depending on what point it is
            % caught.
            arguments = remoteErr.arguments;
            if isempty(arguments)
                iErr = MException(message('parallel:mapreduce:UndefinedFunctionOrHandleOnWorker'));
            else
                fcn = remoteErr.arguments{1};
                iErr = MException(message('parallel:mapreduce:UndefinedFunctionOnWorker', fcn, fcn));
            end
            iErr = addCause(iErr, err);
            throw(iErr);
    end
end

% An unexpected exception was caught.
iErr = MException(message('parallel:mapreduce:InternalExecutionError'));
iErr = addCause(iErr, err);
throw(iErr);
end

