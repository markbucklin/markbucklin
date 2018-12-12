classdef (CaseInsensitiveProperties = true) HybridSpatialMedianFilter < scicadelic.SciCaDelicSystem
	% SpatialMedianFilter
	
	
	
	
	
	
	% USER SETTINGS
	properties (Nontunable)		
		FilterSize = 3
	end
	
	% STATES
	properties (DiscreteState)
	end
	properties (SetAccess = protected, Logical)
	end
	
	% PRIVATE VARIABLES
	properties (SetAccess = protected, Hidden)		
		pFilterSize
	end
	
	
	
	
	
	
	
	
	% CONSTRUCTOR
	methods
		function obj = SpatialMedianFilter(varargin)
			setProperties(obj,nargin,varargin{:});
			obj.CanUseInteractive = true;
		end		
	end
	
	% BASIC INTERNAL SYSTEM METHODS	
	methods (Access = protected)
		function setupImpl(obj, data)			
			
			% INITIALIZE
			fillDefaults(obj)
			checkInput(obj, data);
			obj.TuningImageDataSet = [];
			setPrivateProps(obj)
		
							
			obj.TuningImageDataSet = [];
			if ~isempty(obj.GpuRetrievedProps)
				pushGpuPropsBack(obj)
			end
		end
		function data = stepImpl(obj,data)
			
			data = applyMedianFilter(obj, data);
			
		end
		function resetImpl(obj)
			dStates = obj.getDiscreteState;
			fn = fields(dStates);
			for m = 1:numel(fn)
				dStates.(fn{m}) = 0;
			end
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end
	
	% RUN-TIME HELPER FUNCTIONS
	methods (Access = protected, Hidden)
		function data = applyMedianFilter(obj, data, filterSize)
			if nargin < 3
				filterSize = obj.pFilterSize;
			end
			if isscalar(filterSize)
				filterSize = [filterSize filterSize];
			end
			[nRows, nCols, nFrames] = size(data);
			
			data = reshape( ...
				medfilt2( ...
				reshape( data, [nRows, nCols*nFrames]), ...
				filterSize), ...
				[nRows, nCols, nFrames]);
			
		end
	end
	
% TUNING
methods (Hidden)
		function tuneInteractive(obj)			
			
			
			% STEP 1: MEDIAN FILTER
			k = 1;
			obj.TuningStep(k).ParameterName = 'FilterSize';
			x = obj.FilterSize;			
			obj.TuningStep(k).ParameterDomain = 3:2:15;
			obj.TuningStep(k).ParameterIdx = 1;
			obj.TuningStep(k).Function = @applyMedianFilter;
			obj.TuningStep(k).CompleteStep = true;
			
			% SET UP TUNING WINDOW
			createTuningFigure(obj);			%TODO: can also use for automated tuning?
			
		end			
		function tuneAutomated(obj)
			constructDomainTransferFunctions(obj)			
			constructLocalLowPassFilter(obj)
			tuneScalarBaseline(obj, obj.TuningImageDataSet);
			lockLimits(obj)
			obj.TuningImageDataSet = [];
		end		
end

% INITIALIZATION HELPER METHODS
	methods (Access = protected, Hidden)
		function setPrivateProps(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			for k=1:numel(oProps)
				prop = oProps(k);
				if prop.Name(1) == 'p'
					pname = prop.Name(2:end);
					try
						pval = obj.(pname);
						obj.(prop.Name) = pval;
					catch me
						getReport(me)
					end
				end
			end
		end		
		function fetchPropsFromGpu(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			propSettable = ~[oProps.Dependent] & ~[oProps.Constant];			
			for k=1:length(propSettable)
				if propSettable(k)
					pn = oProps(k).Name;
					try
						if isa(obj.(pn), 'gpuArray') && existsOnGPU(obj.(pn))
							obj.(pn) = gather(obj.(pn));
							obj.GpuRetrievedProps.(pn) = obj.(pn);			
						end
					catch me
						getReport(me)
					end
				end
			end
		end
		function pushGpuPropsBack(obj)
			fn = fields(obj.GpuRetrievedProps);
			for kf = 1:numel(fn)
				pn = fn{kf};
				if isprop(obj, pn)
					if obj.UseGpu
						obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
					else
						obj.(pn) = obj.GpuRetrievedProps.(pn);
					end
				end
			end
		end
	end	
	
	
	
	
	
	
end





















