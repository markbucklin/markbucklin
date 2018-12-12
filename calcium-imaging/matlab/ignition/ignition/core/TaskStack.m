classdef TaskStack < ignition.core.Object & handle
	% TaskCache - initialization, update, & storage of a persistent variables used by a Task
	
	
	
	%Stack @ignition.core.TaskStack
				% (or) Data @ignition.core.TaskData
				% (maybe) Data & Stack, where Stack stores the following:
				% -> Stack.config
				% -> Stack.state
				% -> Stack.data
				% -> Stack.taskid
				% -> Stack.performance
				% -----> (perhaps) should all be defined in (derived) TaskExecutor
	
	
	
		properties (SetAccess = protected)
			InitializeFcn @function_handle
			PreTaskFcn @function_handle
			PostTaskFcn @function_handle
			% DependentTaskObj
			% DependentTaskInputIdx
		end
		properties (SetAccess = protected, SetObservable)
			Cache @struct
		end
		
		% ConstantCache
		% DynamicCache
		% TaskVolatileCache
		% TunableCache
		
		
		methods
			function obj = TaskStack(varargin)
				if nargin
					parseConstructorInput(obj, varargin{:});
				end
					
			end			
			function lock(obj)
			end
			function release(obj)
			end
			function cache = acquireLockedCache(obj)
			end
			function update(obj, cache)
			end
		end
	
	
	
	
	
	
	
	
	
	
end








% CACHE MANAGER
% cm = ignition.alpha.CacheManager
% cs = cm.CacheStore
% setupForExecution( cm, fields(obj.Cache) ) % ??
% 

% TWO-LEVEL-CACHE
% obj = ignition.alpha.TwoLevelCache
% add(obj, 'Configuration Input', 'FileInputObj', @ignition.io.FileWrapper )
% add(obj, 'Configuration Input', 'ParseFrameInfoFcn', @ignition.io.tiff.parseHamamatsuTiffTag )
% add(obj, 'Tunable Task Settings', 'FirstFrameIdx', 0)
% add(obj, 'Tunable Task Settings', 'NextFrameIdx', 0)
% add(obj, 'Tunable Task Settings', 'LastFrameIdx', 0)
% add(obj, 'Tunable Task Settings', 'NumFramesPerRead', 8)
% retrieve( obj, 'NumFramesPerRead')
% [~,config] = retrieveArrayIfPresent( obj, 'ConfigurationInput')
% [~,config] = retrieveArrayIfPresent( obj, 'Configuration Input')