classdef (CaseInsensitiveProperties = true) SpatialMedianFilter < ignition.core.VideoStreamProcessor
	% MedianFilterTask
	% Set ForceUseCustomHybridFcn to true to use 3D capable function that avoids edge-artifact
	
	
	
	
	
	% CONFIGURATION
	properties
		FilterSize = 3
		PreferHybrid @logical = true
	end
		
	% CONTROL
	properties
	end
	
	% STATE
	properties
	end
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = SpatialMedianFilter(varargin)
			
			import ignition.core.Task
			
			
			obj.TaskList = Task(@ignition.stream.gpu.applyHybridMedianFilterGPU);
			
			
		end
	end
	
	% BASIC INTERNAL SYSTEM METHODS
	methods
		function initialize(obj)
			
			% INITIALIZE
			% 			fillDefaults(obj)
			% 			checkInput(obj, F);
			% 			obj.TuningImageDataSet = [];
			% 			setPrivateProps(obj)
			% 			if ~isempty(obj.GpuRetrievedProps)
			% 				pushGpuPropsBack(obj)
			% 			end
			
			if obj.UseGpu
				% GPU -> HYBRID MEDIAN FILTER (currently only filter size is 3)
				filterSize = 3;
				% 				obj.MedianFilterFcn = @applyHybridMedianFilter;
				obj.MainTaskFcn = @ignition.stream.gpu.applyHybridMedianFilterGPU;
				
				
			else
				% CPU -> BUILTIN MEDFILT2
				filterSize = obj.FilterSize;
				if (numel(filterSize) == 1)
					filterSize = [filterSize filterSize];
				else
					filterSize = filterSize(1:2);
				end
				% 				obj.MedianFilterFcn = @applyMatlabMedianFilter;
				obj.MainTaskFcn = @(F)applyMatlabMedianFilter(obj, F, filterSize);
			end
			
			% UPDATE FILTER SIZE
			obj.FilterSize = filterSize;
			% 			setPrivateProps(obj);
			
		end
	end
	% RUN-TIME HELPER FUNCTIONS
	methods (Access = protected, Hidden)
		function F = applyMatlabMedianFilter(obj, F, filterSize)
			% WILL CALL BUILT-IN MATLAB FUNCTION -> MEDFILT2 (FOR GPU OR CPU)
			
			if nargin < 3
				filterSize = obj.FilterSize;
			end
			if isscalar(filterSize)
				filterSize = [filterSize filterSize];
			end
			[numRows, numCols, numFrames] = size(F);
			
			% RESHAPE TO 2D MATRIX, APPLY, THEN FOLD BACK (SOME EDGE ARTIFACTS)
			F = reshape( ...
				medfilt2( ...
				reshape( F, [numRows, numCols*numFrames]), ...
				filterSize), ...
				[numRows, numCols, numFrames]);
			
			% TODO: PAD SYMMETRIC IF ON GPU, OTHERWISE SPECIFY SYMMETRIC PADDING (NOT ZEROS)
			
		end
	end
	
	
	
	
	
	
end





















