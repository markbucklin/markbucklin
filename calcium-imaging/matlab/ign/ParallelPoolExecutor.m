%ParallelPoolExecutor
% Parallel pool implementation of the PartitionArrayExecutor interface.
%

%   Copyright 2016 The MathWorks, Inc.

classdef (Sealed) ParallelPoolExecutor < matlab.bigdata.internal.executor.PartitionedArrayExecutor
    properties (SetAccess = immutable)
        % The parallel pool to use for execution.
        Pool
        
        % A logical scalar that indicates whether all MATLAB Workers are
        % local to the client.
        AreWorkersLocal;
        
        % The underlying cache manager.
        CacheManager;
    end
    
    methods
        % The main constructor.
        function obj = ParallelPoolExecutor(pool)
            import matlab.bigdata.internal.util.TempFolder;
            import parallel.internal.bigdata.ParallelPoolCacheManager;
            
            if nargin < 1
                pool = gcp('nocreate');
            end
            validateattributes(pool, {'parallel.Pool'}, {'nonempty'}, 'ParallelPoolExecutor', 'pool');
            if ~isvalid(pool)
                error(message('MATLAB:class:InvalidHandle'));
            elseif ~pool.Connected
                error(message('parallel:lang:pool:InvalidPool'));
            elseif ~pool.SpmdEnabled
                error(message('parallel:mapreduce:SpmdEnabledRequired'));
            end
            obj.Pool = pool;
            
            obj.AreWorkersLocal = isa(obj.Pool.Cluster, 'parallel.cluster.Local');
            
            obj.CacheManager = ParallelPoolCacheManager(pool);
        end
    end
    
    % Methods overridden in the PartitionedArrayExecutor interface.
    methods
        % Execute the provided graph of tasks.
        function varargout = execute(obj, taskGraph)
            import matlab.bigdata.internal.util.TempFolder;
            import matlab.bigdata.internal.executor.ProgressReporter;
            
            pr = ProgressReporter.getCurrent();
            
            [stageTasks, shuffleStrategyMap, broadcastMap] = obj.buildStageTasks(taskGraph);
            
            numTasks = numel(stageTasks) - obj.countNumPureBroadcastStages(stageTasks);
            numPasses = obj.countNumDatastoreStages(stageTasks);
            
            pr.startOfExecution(obj.getName(), numTasks, numPasses);
            for ii = 1:numel(stageTasks)
                isFullPass = stageTasks(ii).ExecutionPartitionStrategy.IsDatastorePartitioning;
                
                if iIsPureBroadcast(stageTasks(ii))
                    % Data that is in broadcast state both exists in the
                    % local MATLAB and is small. The overhead is too high
                    % to execute this on the pool so we do serial
                    % execution.
                    obj.executeStageTaskLocally(stageTasks(ii));
                else
                    pr.startOfNextTask(isFullPass);
                    obj.executeStageTaskOnPool(stageTasks(ii), shuffleStrategyMap, broadcastMap, pr);
                    pr.endOfTask();
                end
                
            end
            pr.endOfExecution();
            
            outputTasks = taskGraph.OutputTasks;
            varargout = cell(size(outputTasks));
            for ii = 1:numel(outputTasks)
                % The convertToIndependentTasks logic dictates that all
                % output tasks will write their output to the broadcast map
                % during evaluation of the stage tasks.
                varargout{ii} = broadcastMap.get(outputTasks(ii).Id);
            end
        end
        
        % Count the number of passes required to execute the provided graph
        % of tasks.
        function numPasses = countNumPasses(obj, taskGraph)
            import matlab.bigdata.internal.util.TempFolder;
            
            [stageTasks, ~] = obj.buildStageTasks(taskGraph);
            numPasses = obj.countNumDatastoreStages(stageTasks);
        end
        
        % Check whether this executor is valid.
        function tf = checkIsValid(obj)
            % This means that a given tall array attached to this executor
            % will no longer be valid once the pool is deleted, or closed
            % due to idle timeout.
            tf = isvalid(obj.Pool) && obj.Pool.Connected;
        end
        
        %CHECKDATASTORESUPPORT Check whether the provided datastore is supported.
        function checkDatastoreSupport(~, inputds)
            if ~isa(inputds, 'matlab.io.datastore.SplittableDatastore')
                classnameParts = strsplit(inputds, '.');
                datastoreType = regexprep(classnameParts{end}, 'Datastore$' ,'');
                error(message('parallel:bigdata:UnsupportedDatastore', datastoreType, obj.getName()));
            end
        end
    end
    
    methods (Access = private)
        % Count the number of stages that have execution across a
        % datastore.
        function numStages = countNumDatastoreStages(obj, stageTasks) %#ok<INUSL>
            numStages = 0;
            for ii = 1:numel(stageTasks)
                numStages = numStages + stageTasks(ii).ExecutionPartitionStrategy.IsDatastorePartitioning;
            end
        end
        
        % Count the number of stages that are pure broadcast.
        function numStages = countNumPureBroadcastStages(obj, stageTasks) %#ok<INUSL>
            numStages = 0;
            for ii = 1:numel(stageTasks)
                numStages = numStages + iIsPureBroadcast(stageTasks(ii));
            end
        end
        
        % Execute the provided independent stage serially.
        function executeStageTaskLocally(obj, task) %#ok<INUSL>
            assert(iIsPureBroadcast(task));
            
            partitionStrategy = task.ExecutionPartitionStrategy;
            partitionIndex = 1;
            numExecutorPartitions = 1;
            partition = partitionStrategy.createPartition(partitionIndex, numExecutorPartitions);
                
            dataProcessor = feval(task.DataProcessorFactory, partition);
            while ~dataProcessor.IsFinished
                process(dataProcessor, false(0));
            end
        end
        
        % Execute the provided independent stage on the pool.
        function executeStageTaskOnPool(obj, task, shuffleStrategyMap, broadcastMap, progressReporter)
            import matlab.bigdata.internal.executor.ExecutionTask;
            import matlab.bigdata.internal.executor.ProgressReporter;
            import parallel.internal.bigdata.PartitionedArrayTask;
            import parallel.internal.mapreduce.ParfevalTaskRunner;
            import parallel.internal.mapreduce.ShuffleSortTask;
            
            obj.CacheManager.setupForExecution(task.CacheEntryKeys);
            broadcastMap.synchronize({task.InputBroadcasts.Id});
            
            partitionStrategy = task.ExecutionPartitionStrategy;
            dataProcessorFactory = task.DataProcessorFactory;
            numExecutorPartitions = iGetNumPartitions(partitionStrategy, obj.Pool);
            
            shuffleInputs = task.InputShuffles;
            shuffleOutputs = task.OutputShuffles;
            if obj.AreWorkersLocal
                % If all workers are local to the client, then we do not
                % need to perform any shuffle work.
                shuffleInputs = ExecutionTask.empty();
                shuffleOutputs = ExecutionTask.empty();
            end

            % Decide how to schedule the work among workers. This depends on
            % whether workers might already have some of the data cached,
            % as well as whether previous stage tasks generated location
            % specific output.
            if any(~arrayfun(@(task)task.ExecutionPartitionStrategy.IsBroadcast, shuffleInputs))
                % At least one shuffle input is not broadcast, which means
                % it is already partitioned across the workers. We need to
                % schedule execution of partitions to the workers where the
                % corresponding data exists.
                lockedFunctor = iCreateStripedScheduleMap(obj.Pool.NumWorkers, numExecutorPartitions);
                freeIndices = [];
            else
                % We are free to schedule partitions to any partitions. For
                % the purposes of caching, we choose to schedule partitions
                % for which cache entries exist to the corresponding
                % worker. All other tasks are scheduled in a way that
                % allows for load balancing.
                cachedIndicesMap = obj.CacheManager.getCachedPartitionIndices(task.CacheEntryKeys);
                [lockedIndices, freeIndices] = iDetermineScheduling(cachedIndicesMap, numExecutorPartitions);
                
                if all(cellfun(@isempty, lockedIndices))
                    lockedFunctor = [];
                else
                    lockedFunctor = @(id) lockedIndices{id};
                end
            end
            
            numTasks = ~isempty(lockedFunctor) + numel(freeIndices) + numel(shuffleOutputs);
            taskRunner = ParfevalTaskRunner(obj.Pool, numTasks);
            
            % Schedule the execution that depends on location.
            if ~isempty(lockedFunctor)
                taskRunner.launchTask(PartitionedArrayTask(dataProcessorFactory, ...
                    lockedFunctor, numExecutorPartitions, partitionStrategy));
            end
            
            % Schedule any remaining execution that does not depend on location.
            for partitionIndex = freeIndices(:)'
                taskRunner.launchTask(PartitionedArrayTask(dataProcessorFactory, ...
                    partitionIndex, numExecutorPartitions, partitionStrategy));
            end
            
            % Schedule the communication part of the work.
            isFinalizeRequired = true;
            for shuffleExecutionTask = shuffleOutputs(:)'
                shuffleStrategy = shuffleStrategyMap(shuffleExecutionTask.Id);
                
                if shuffleExecutionTask.OutputPartitionStrategy.IsBroadcast
                    % If broadcast output, we need to broadcast the single
                    % partition to all workers.
                    partitionIndexMap = @(~)1;
                else
                    % Otherwise we decide at this point to send each
                    % partition to a predetermined worker.
                    numWorkers = obj.Pool.NumWorkers;
                    numPartitions = iGetNumPartitions(shuffleExecutionTask.OutputPartitionStrategy, obj.Pool);
                    partitionIndexMap = iCreateStripedScheduleMap(numWorkers, numPartitions);
                end
                taskRunner.launchTask(ShuffleSortTask(partitionIndexMap, isFinalizeRequired, shuffleStrategy));
            end
            
            % The struct is for compatibility with core MATLAB status
            % reporter.
            taskRunner.ProgressCallback = struct('Progress', @(value)progressReporter.progress(value/100));
            taskRunner.wait();
            
            broadcastMap.synchronize({task.OutputBroadcasts.Id});
        end
        
        % Convert the input task graph into an array of independent tasks
        % that can be executed one by one.
        %
        % This returns:
        %  - stageTasks: An array of independent ExecutionTask instances.
        %  - shuffleStrategyMap: A map from task ID to corresponding
        %  ShuffleSortStrategy instance.
        %
        % It is important that shuffleStrategyMap is captured and lives for
        % the lifetime of the execution. The underlying ShuffleSortStrategy
        % instances hold onto resources that are used by the workers.
        %
        function [stageTasks, shuffleStrategyMap, broadcastMap] = buildStageTasks(obj, taskGraph)
            import parallel.internal.bigdata.ParallelPoolBroadcastMap;
            cacheManager = obj.CacheManager;
            shuffleStrategyMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            broadcastMap = ParallelPoolBroadcastMap();
            stageTasks = matlab.bigdata.internal.executor.convertToIndependentTasks(taskGraph, ...
                'CreateShuffleStorageFunction', @(task) obj.createShuffleStorage(task, shuffleStrategyMap), ...
                'CreateBroadcastStorageFunction', @(task) obj.createBroadcastStorage(task, broadcastMap), ...
                'GetCacheStoreFunction', @cacheManager.getCacheStore, ...
                'NumAnyToAnyOutputPartitions', obj.Pool.NumWorkers);
            
            for stageTask = stageTasks(:)'
                executionStrategy = stageTask.ExecutionPartitionStrategy;
                if executionStrategy.IsDatastorePartitioning && ~executionStrategy.IsSplittable
                    classnameParts = strsplit(class(executionStrategy.Datastore), '.');
                    datastoreType = regexprep(classnameParts{end}, 'Datastore$' ,'');
                    error(message('parallel:bigdata:UnsupportedDatastore', datastoreType, obj.getName()));
                end
            end
        end
        
        % Create a shuffle point where data is stored to an intermediate
        % storage, then read in a "shuffled" order by the next task.
        function [writerFactory, readerFactory] = createShuffleStorage(obj, task, shuffleStrategyMap)
            import matlab.bigdata.internal.executor.OutputCommunicationType;
            import parallel.internal.bigdata.RemoteShuffleSortStrategy;
            import parallel.internal.bigdata.SinkAdapterWriter;
            import parallel.internal.bigdata.SourceAdapterReader;
            import parallel.internal.bigdata.TrivialPartitioner;
            import parallel.internal.mapreduce.SqliteRemoteCopyShuffleSortStrategy;
            import parallel.internal.mapreduce.SqliteShuffleSortStrategy;
            
            % We disable usage of worker ID by the shuffle sort strategy as
            % this option introduces non-deterministic ordering of data.
            % There are ways to use worker ID without introducing
            % non-deterministic ordering, this is a potential optimization.
            useWorkerId = false;
            numOutputPartitions = iGetNumPartitions(task.OutputPartitionStrategy, obj.Pool);
            if obj.AreWorkersLocal
                shuffleSortStrategy = SqliteShuffleSortStrategy(numOutputPartitions, TrivialPartitioner(), useWorkerId);
            else
                shuffleSortStrategy = RemoteShuffleSortStrategy(...
                    SqliteRemoteCopyShuffleSortStrategy(numOutputPartitions, TrivialPartitioner(), useWorkerId));
            end
            
            outputCommunicationType = task.OutputCommunicationType;
            
            writerFactory = @(partition) SinkAdapterWriter(...
                shuffleSortStrategy.createMapOutputSink(partition.PartitionIndex), ...
                iGetDefaultKey(partition, outputCommunicationType));
            
            if task.OutputPartitionStrategy.IsBroadcast
                % When a given piece of intermediate data is in broadcast
                % state, it has only 1 partition. Every data processor that
                % requires this data must read from partition 1.
                broadcastPartitionIndex = 1;
                readerFactory = @(partition) SourceAdapterReader(...
                    shuffleSortStrategy.createReduceInputSource(broadcastPartitionIndex));
            else
                readerFactory = @(partition) SourceAdapterReader(...
                    shuffleSortStrategy.createReduceInputSource(partition.PartitionIndex));
            end
            
            shuffleStrategyMap(task.Id) = shuffleSortStrategy; %#ok<NASGU>
        end
        
        % Create a broadcast variable that will receive the output of a
        % broadcast execution task.
        function [setterFunction, getterFunction] = createBroadcastStorage(obj, task, broadcastMap) %#ok<INUSL>
            taskId = task.Id;
            
            setterFunction = @(partition, value) broadcastMap.set(taskId, partition, value);
            getterFunction = @() broadcastMap.get(taskId);
        end
        
        % Get a user visible string that represents this execution
        % environment.
        function name = getName(obj)
            profileName = obj.Pool.Cluster.Profile;
            if isempty(profileName)
                name = getString(message('parallel:bigdata:ParallelPoolName'));
            else
                name = getString(message('parallel:bigdata:ParallelPoolWithProfileName', profileName));
            end
        end
    end
end

% For the provided partition and output communication type, get the default
% key that should be written to the intermediate data store.
function defaultKey = iGetDefaultKey(partition, outputCommunicationType)
import matlab.bigdata.internal.executor.OutputCommunicationType;

switch outputCommunicationType
    case OutputCommunicationType.Simple
        defaultKey = partition.PartitionIndex;
    case OutputCommunicationType.Broadcast
        defaultKey = 1;
    case OutputCommunicationType.AllToOne
        defaultKey = 1;
    case OutputCommunicationType.AnyToAny
        % In AnyToAny communication, the partition indices should be
        % specified by the data processor implementation underlying the
        % task.
        defaultKey = [];
end
end

% Helper function that deals with the fact that DesiredNumPartitions can be
% empty.
function numPartitions = iGetNumPartitions(strategy, pool)
numPartitions = strategy.DesiredNumPartitions;
if ~strategy.IsNumPartitionsFixed && strategy.IsDatastorePartitioning && strategy.IsSplittable
    % We use numpartitions(ds, pool) as this limits the number of
    % partitions to 3x the number of workers. This is more optimal for
    % early exit and means less shuffle-sort data.
    numPartitions = max(numpartitions(strategy.Datastore, pool), 1);
elseif isempty(numPartitions)
    numPartitions = pool.NumWorkers;
end
end

% Create a map from Worker ID to array of partition ids that apply a
% striped pattern.
function fcn = iCreateStripedScheduleMap(numWorkers, numPartitions)
fcn = @nWorkerIdToPartitionIdMap;
    function partitionIndices = nWorkerIdToPartitionIdMap(id)
        partitionIndices = id : numWorkers : numPartitions;
    end
end

% Helper function that determines the scheduling of partitions
% 1:numPartitions based on the given array of cached partition indices
% from each worker.
function [lockedIndices, freeIndices] = iDetermineScheduling(cachedPartitionIndices, numPartitions)
lockedIndices = cachedPartitionIndices;

allIndices = [];
for ii = 1:numel(lockedIndices)
    lockedIndices{ii} = setdiff(cachedPartitionIndices{ii}, allIndices);
    allIndices = union(allIndices, lockedIndices{ii});
end
freeIndices = setdiff(1:numPartitions, allIndices);
end

% Helper function that returns true if a given stage task executes in
% broadcast mode with broadcast output.
function tf = iIsPureBroadcast(stageTask)
tf = stageTask.ExecutionPartitionStrategy.IsBroadcast && isempty(stageTask.OutputShuffles);
end
