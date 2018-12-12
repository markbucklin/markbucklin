classdef (CaseInsensitiveProperties = true) HybridMedianFilter < ignition.core.VideoStreamProcessor
	% HybridMedianFilter
	% Set ForceUseCustomHybridFcn to true to use 3D capable function that avoids edge-artifact
	
	
	
	
	
	% USER SETTINGS
	properties (Nontunable)
		FilterSize = 3
	end
	properties (Nontunable, Logical)
	end
	
	% STATES
	properties (DiscreteState)
	end
	properties (SetAccess = ?ignition.core.Object, Logical)
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = ?ignition.core.Object, Hidden, Nontunable)
		% 		MedianFilterFcn
	end
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = HybridMedianFilter(varargin)
			
			
			% 			setProperties(obj,nargin,varargin{:});
			
			% PARSE INPUT
			parseConstructorInput(obj,varargin{:});
			
			% GET NAME OF PACKAGE CONTAINING CLASS
			% 			getCurrentClassPackage
			% 			obj.SubPackageName = currentClassPkg;
			
			
			
			% 			obj.CanUseInteractive = true;
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
	methods (Access = ?ignition.core.Object)
		% 		function F = runMainTask(obj,F)
		%
		% 			try
		% 				F = obj.MedianFilterFcn(obj, F);
		% 			catch
		% 				if obj.UseGpu
		% 					% 					F = hybridMedianFilterRunGpuKernel(F);
		% 					F = ignition.stream.gpu.applyHybridMedianFilterGPU(F);
		% 				else
		% 					F = applyMatlabMedianFilter(obj, F);
		% 				end
		% 			end
		%
		% 			% 			F = feval(obj.MedianFilterFcn, F);
		% 			% 			F = applyMedianFilter(obj, F);
		%
		% 		end
		% 		function resetImpl(obj)
		% 			dStates = obj.getDiscreteState;
		% 			fn = fields(dStates);
		% 			for m = 1:numel(fn)
		% 				dStates.(fn{m}) = 0;
		% 			end
		% 		end
		% 		function releaseImpl(obj)
		% 			fetchPropsFromGpu(obj)
		% 		end
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
		function F = applyHybridMedianFilter(~, F)
			% Runs a small external (normal matlab) function that constructs/calls a custom element-wise kernel
			
			% CALL ELEMENT-WISE MATLAB FUNCTION THAT RUNS ON GPU
			
			F = hybridMedianFilterRunGpuKernel(F);
			
		end
	end
	
	
	
	
	
	
end





















