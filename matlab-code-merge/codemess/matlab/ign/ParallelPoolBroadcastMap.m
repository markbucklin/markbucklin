%ParallelPoolBroadcastMap
% Helper class that holds a map of ID to broadcast value that is replicated
% across all MATLAB Workers and the MATLAB client.
%
% The client must call synchronize before it or any worker can expect to
% get the value for a given key.
%

%   Copyright 2016 The MathWorks, Inc.

classdef (Sealed) ParallelPoolBroadcastMap < handle
    
    properties (SetAccess = immutable)
        % The underlying parallel.pool.Constant that represents the local
        % copy of the map held by each worker.
        WorkerBroadcastMap;
    end
    
    properties (SetAccess = immutable, Transient)
        % The underlying map that represents the local copy of the map held
        % by the client.
        ClientBroadcastMap
    end
    
    properties (SetAccess = private, Transient)
        % A list of IDs that have already been synchronized.
        SynchronizedKeys = {};
    end
    
    methods
        % The main constructor.
        function obj = ParallelPoolBroadcastMap()
            import matlab.bigdata.internal.executor.BroadcastMap;
            obj.ClientBroadcastMap = BroadcastMap();
            obj.WorkerBroadcastMap = parallel.pool.Constant(@BroadcastMap);
        end
        
        % Set the given
        function set(obj, key, partition, value)
            map = obj.getUnderlyingMap();
            if partition.NumPartitions == 1
                map.set(key, value);
            else
                map.setPartitions(key, partition.PartitionIndex, {value});
            end
        end
        
        % Get the entirety of the broadcast value associated with the given
        % key.
        function value = get(obj, key)
            map = obj.getUnderlyingMap();
            value = map.get(key);
        end
        
        % Synchronize the client and all workers for the given broadcast
        % keys.
        %
        % This function can only be called on the client. Once
        % synchronized, the broadcast values corresponding with keys can be
        % used from the client or any worker.
        function synchronize(obj, keys)
            keys = keys(:);
            keys = setdiff(keys, obj.SynchronizedKeys);
            if isempty(keys)
                return;
            end
            
            clientMap = obj.getUnderlyingMap();
            [newClientKeys, newClientValues] = iGetValues(clientMap, keys);
            
            newWorkerKeys = Composite;
            newWorkerValues = Composite;
            spmd
                [newWorkerKeys(:, :), newWorkerValues(:, :)] = doWorkerSynchronize(obj, keys, newClientKeys, newClientValues);
            end
            newWorkerKeys = vertcat(newWorkerKeys{:});
            newWorkerValues = vertcat(newWorkerValues{:});
            
            iSetValues(clientMap, newWorkerKeys, newWorkerValues);
            
            obj.SynchronizedKeys = [obj.SynchronizedKeys; keys];
        end
    end
    
    methods (Access = private)
        % Get the underlying BroadcastMap object.
        function map = getUnderlyingMap(obj)
            if isnumeric(obj.ClientBroadcastMap)
                map = obj.WorkerBroadcastMap.Value;
            else
                map = obj.ClientBroadcastMap;
            end
        end
        
        % Do the worker side of the synchronize function.
        function [newWorkerKeys, newWorkerValues] = doWorkerSynchronize(obj, keys, newClientKeys, newClientValues)
            workerMap = obj.getUnderlyingMap();
            [newWorkerKeys, newWorkerValues] = iGetValues(workerMap, keys);
            
            allNewWorkerKeys = [newClientKeys; gcat(newWorkerKeys, 1)];
            allNewWorkerValues = [newClientValues; gcat(newWorkerValues, 1)];
            iSetValues(workerMap, allNewWorkerKeys, allNewWorkerValues);
        end
    end
end

% Helper function that retrieves for each key the corresponding collection of
% partitions.
% Outputs are:
%  - keys: A N x 1 cell array of keys.
%  - valuePartitions: A N x 2 cell array of {partitionIndices, partitionValues} pairs.
function [keys, valuePartitions] = iGetValues(map, keys)
keys = keys(:);
isMember = map.ismember(keys);
keys = keys(isMember);
if isempty(keys)
    keys = cell(0, 1);
end

valuePartitions = cell(numel(keys), 2);
for ii = 1:numel(keys)
    [partitionIndices, values] = map.getPartitions(keys{ii});
    valuePartitions(ii, :) = {partitionIndices, values};
end
end

% Helper function that sets for each key the corresponding collection of
% partitions.
% Inputs are:
%  - map: The local BroadcastMap object.
%  - keys: A N x 1 cell array of keys.
%  - valuePartitions: A N x 2 cell array of {partitionIndices, partitionValues} pairs.
function iSetValues(map, keys, valuePartitions)
for ii = 1:numel(keys)
    partitionIndices = valuePartitions{ii, 1};
    values = valuePartitions{ii, 2};
    map.setPartitions(keys{ii}, partitionIndices, values);
end
end
