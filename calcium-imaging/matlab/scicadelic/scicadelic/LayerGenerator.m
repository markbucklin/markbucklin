classdef (CaseInsensitiveProperties = true) LayerGenerator < scicadelic.SciCaDelicSystem
	% Prototype
	
	% ##################################################
	% SETTINGS
	% ##################################################
	properties (Nontunable)
	end
	properties (Nontunable, Logical)
	end
	properties (Nontunable, PositiveInteger)
	end
	
	
	% ##################################################
	% OUTPUT
	% ##################################################
	properties (SetAccess = protected)
		Output
	end
	
	
	% ##################################################
	% PRIVATE INTERNAL PROPS
	% ##################################################
	properties (Nontunable, Access = protected) % Hidden
		NonLocalStats
	end
	
	
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = LayerGenerator(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));
		end
	end
	
	
	% ##################################################
	% INTERNAL SYSTEM METHODS
	% ##################################################
	methods (Access = protected)
		% ============================================================
		% SETUP
		% ============================================================
		function setupImpl(obj, F)
			
			% INITIALIZATION (STANDARD)
			fillDefaults(obj)
			checkInput(obj, F);
			obj.TuningImageDataSet = [];
			setPrivateProps(obj)
			if ~isempty(obj.GpuRetrievedProps)
				pushGpuPropsBack(obj)
			end
			
			% INITIALIZATION (CLASS-SPECIFIC)
			if isempty(obj.NonLocalStats)
				obj.NonLocalStats = nonLocalStatisticUpdateRunGpuKernel(F);
			end
			
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function R = stepImpl(obj, F, varargin)
			
			if nargin > 1
				if ~isempty(F)
					% LOCAL VARIABLES
					nlstat = obj.NonLocalStats;					
					
					% UPDATE NON-LOCAL STATISTCS FOR USE AS BACKGROUND
					nlstat = nonLocalStatisticUpdateRunGpuKernel(F, nlstat);
					
					% UPDATE LAYER
					R = computeLayerFromRegionalComparisonRunGpuKernel(F, [], [], nlstat.M1);
					
				end
				
				
			else
				F = [];
			end
			
		end
		
		% ============================================================
		% I/O & RESET
		% ============================================================		
		function resetImpl(obj)
			setPrivateProps(obj)
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
		function s = saveObjectImpl(obj)
			s = saveObjectImpl@matlab.System(obj);
			if isLocked(obj)
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			if ~isempty(obj.ChildSystem)
				for k=1:numel(obj.ChildSystem)
					s.ChildSystem{k} = matlab.System.saveObject(obj.ChildSystem{k});
				end
			end
		end
		function loadObjectImpl(obj,s,wasLocked)
			if wasLocked
				% Load child System objects
				if ~isempty(s.ChildSystem)
					for k=1:numel(s.ChildSystem)
						obj.ChildSystem{k} = matlab.System.loadObject(s.ChildSystem{k});
					end
				end
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				% 		 oProps = oProps(~strcmp({oProps.GetAccess},'private'));
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			% Call base class method to load public properties
			loadObjectImpl@matlab.System(obj,s,[]);
		end
	end
	
	
	% ##################################################
	% TUNING
	% ##################################################
	methods (Hidden)
		function tuneInteractive(~)
		end
		function tuneAutomated(~)
		end
	end
	
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
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
						msg = getReport(me);
						disp(msg)
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
						msg = getReport(me);
						disp(msg)
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
						if ~isa(obj.(pn), 'gpuArray')
							obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
						end
					else
						obj.(pn) = obj.GpuRetrievedProps.(pn);
					end
				end
			end
		end
	end
	
	
	% ##################################################
	% OUTPUT DISPLAY
	% ##################################################
	methods (Access = public)
	end
	
	
	
	
	
	
	
	
	
	
end