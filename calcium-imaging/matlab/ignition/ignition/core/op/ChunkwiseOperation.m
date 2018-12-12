%ChunkwiseOperation
% An operation that acts on each chunk of data.

% Copyright 2015-2016 The MathWorks, Inc.

classdef (Sealed) ChunkwiseOperation < matlab.bigdata.internal.lazyeval.Operation
    properties (SetAccess = immutable)
        % The function handle for the operation.
        FunctionHandle;
    end
    
    methods
        % The main constructor.
        function obj = ChunkwiseOperation(functionHandle, numInputs, numOutputs)
            obj = obj@matlab.bigdata.internal.lazyeval.Operation(numInputs, numOutputs);
            obj.FunctionHandle = functionHandle;
        end
    end
    
    % Methods overridden in the Operation interface.
    methods
        function task = createExecutionTasks(obj, taskDependencies, inputFutureMap, isInputReplicated)
            import matlab.bigdata.internal.executor.ExecutionTask;
            import matlab.bigdata.internal.lazyeval.ChunkwiseProcessor;
            
            processorFactory = ChunkwiseProcessor.createFactory(...
                obj.FunctionHandle, obj.NumOutputs, inputFutureMap, isInputReplicated);
            
            task = ExecutionTask.createSimpleTask(taskDependencies, processorFactory);
        end
    end
end