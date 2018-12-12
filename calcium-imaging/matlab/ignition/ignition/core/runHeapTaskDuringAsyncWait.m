function donorTerminationTracker = runHeapTaskDuringAsyncWait(varargin)

% taskObj is either a task that is to be added to the heap, or a waiting task-processor that will
% process tasks from the heap.

persistent donatingTaskPerformanceProfile heapTaskPerformanceProfile taskHeap
numPriorSamples = 10;
if (nargin >= 1)
	
	tEntrance = tic;
	
	% INITIALIZE PERSISTENT CACHES AS CONTAINER.MAP TYPE
	donatingTaskPerformanceProfile = ...
		ignition.util.persistentMapVariable(donatingTaskPerformanceProfile);
	heapTaskPerformanceProfile...
		= ignition.util.persistentMapVariable(heapTaskPerformanceProfile);
	taskHeap ...
		= ignition.util.persistentMapVariable(taskHeap);
	
	
	if isa(varargin{1},'ignition.core.Task')
		% todo -> add to heap
		taskObj = varargin{1};
		taskID = taskObj.ID;
		if isKey(taskHeap, taskID)
			taskHeap(taskID) = [taskHeap(taskID) taskObj];
		else
			taskHeap(taskID) = taskObj;
		end
		
	elseif isa(varargin{1}, 'ignition.core.TaskExecutor')
		taskExecutor = varargin{1};
		taskID = taskExecutor.CurrentTaskObj.ID;
		% todo -> perhaps should just pass 'Stack' structure with ID
		% elseif isstruct(varargin{1})
		% taskStack = varargin{1};
		% taskID = taskStack.ID;
		donorTerminationTracker = onCleanup( @()cacheDonatingTaskTerminationTime( taskID, tEntrance));
		
		
		% todo -> find best task
		
		
		heapTaskTerminationTracker = onCleanup( @()cacheDonatingTaskTerminationTime( taskID, tEntrance));
		
	end
else
	% CLEAR QUEUE
	
	
end


% BENCHMARK TOTAL ELAPSED TIME FOR TASKS FROM HEAP
	function cacheHeapedTaskTerminationTime( taskID, tIn)
		
	end

% BENCHMARK TIME TO TERMINATION FOR DONATING TASK
	function cacheDonatingTaskTerminationTime( taskID, tIn)
		% This function clocks how long the donating task can expect to wait before it should resume its
		% own execution (presumably higher-priority)
		persistent donatingTaskBenchmarkStorage
		tElapsedSample = toc(tIn);
		donatingTaskBenchmarkStorage = ignition.util.persistentMapVariable(donatingTaskBenchmarkStorage);
		if ~isKey(donatingTaskBenchmarkStorage, taskID) ...
				|| isempty(donatingTaskBenchmarkStorage(taskID))
			storedSamples = tElapsedSample .* [1 ; 1];
		else
			storedSamples = donatingTaskBenchmarkStorage(taskID);
			numSamples = max(1, min( numPriorSamples, numel(storedSamples)) - 1);
			storedSamples = cat(1, tElapsedSample, storedSamples(1:numSamples) );
		end
		
		donatingTaskBenchmarkStorage(taskID) = storedSamples;
		
		% UPDATE AVERAGE
		donatingTaskPerformanceProfile(taskID) = mean(storedSamples(:));
		
	end



end





% todo -> enable execution of independent functions (e.g. from global queue) here during the time
% normally spent waiting for results to return. Implement 'lowPriorityTaskHeap' function with
% persistent task_queue variable containing anonymous functions & estimated processing times. When
% queue/heap is empty -> tic the entrance-time and return onCleanUp class that tocs and caches the
% function finish time... better yet   ----->   every time the 'idle-volunteer' function is
% called, tIn=tic the entrance, Cexit=oncleanup( @()cacheTimeSpent(borrowingTaskID,tIn))  ... and
% also return --> Ccallerterm=onCleanup( @() cacheCallerTerminateTime(donatingTaskID,tIn)) --->
% the onCleanup functions look like:
%
%			function cacheTimeSpent(id,t)
%					tSpent=toc(t);
%					addToBorrowingTaskProfile(id,tSpent);
%
% addTo__TaskProfile() caches last few samples in persistent hash-map, and records average in
% separate donor/borrower task-performance profile defined at parent function level (or globally)
