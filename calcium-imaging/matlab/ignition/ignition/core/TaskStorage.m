classdef TaskStorage < ignition.core.object & handle
	% TaskStorage - provides initialization, update, and recursion & storage of a persistent variables used by a Task
	
	
	
	
	
	
	
		properties (SetAccess = protected)
			InitializeOp @ignition.core.Operation
			PreTaskOp @ignition.core.Operation
			PostTaskOp @ignition.core.Operation
			DependentTaskObj
			DependentTaskInputIdx
		end
		properties (SetAccess = protected, SetObservable)
			Storage @struct
		end
		
		% ConstantCache
		% DynamicCache
		% TaskVolatileCache
		% TunableCache
		
		
		methods
			function obj = TaskStorage(varargin)
				if nargin
					parseConstructorInput(obj, varargin{:});
				end
					
			end			
			function lock(obj)
			end
			function release(obj)
			end
			function store = acquireLockedStorage(obj)
			end
			function update(obj, stor)
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