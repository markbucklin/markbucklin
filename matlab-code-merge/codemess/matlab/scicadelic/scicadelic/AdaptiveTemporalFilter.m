classdef (CaseInsensitiveProperties = true) AdaptiveTemporalFilter < scicadelic.SciCaDelicSystem
	% ADAPTIVETEMPORALFILTER - Suppresses noise due to local motion
	%	
	%
	% Syntax:
	%			>> [dstat, stat] = differentialMomentGeneratorRunGpuKernel(F);
	%			>> [dstat, stat] = differentialMomentGeneratorRunGpuKernel(F, stat);
	%
	% Description:
	%
	% Examples:
	%
	% Input Arguments:
	%
	% Output Arguments:
	%	
	% More About:
	%
	%	References:
	%
	% See Also: 
	%			BWMORPH GPUARRAY/BWMORPH STATISTICCOLLECTORRUNGPUKERNEL, SCICADELIC.STATISTICCOLLECTOR
	
	
	
	
	
	
	
	
	% ##################################################
	% SETTINGS
	% ##################################################
	properties (Nontunable)
		MinTimeConstantNumFrames = 3
		MaxTimeConstantNumFrames = 50
		AdaptiveType = 'Temporal'
	end
	properties (Nontunable, Logical)
	end
	properties (Nontunable, PositiveInteger)
		FilterOrder = 2
	end
	
	
	% ##################################################
	% OUTPUT
	% ##################################################
	properties (SetAccess = protected)
		Output
	end
	
	
	% ##################################################
	% PRIVATE
	% ##################################################	
	properties (SetAccess = protected, Hidden)		
		OutputBuffer
	end
	properties (SetAccess = protected)
		A
		PreFilterStat
		ActivityMetricStat
	end
	properties (Nontunable, Access = protected)		
		MinA
		MaxA
	end
	properties (SetAccess = protected, Nontunable, Hidden)
		signedConversionFcn
		AdaptiveTypeSet = matlab.system.StringSet({'Temporal','Spatial','none'})
		AdaptiveTypeIdx
	end
	
	
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = AdaptiveTemporalFilter(varargin)
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
			
			% ADAPTIVITY TYPE & UPDATE INDEX
			if ~isempty(obj.AdaptiveType)
				obj.AdaptiveTypeIdx = getIndex(obj.AdaptiveTypeSet, obj.AdaptiveType);
			else
				obj.AdaptiveTypeIdx = 1;
			end
			
			% INITIALIZATION (CLASS-SPECIFIC)
			if obj.MinTimeConstantNumFrames > 1
				obj.MinA = single(exp(-obj.FilterOrder/obj.MinTimeConstantNumFrames));
			else
				obj.MinA = single(0);
			end
			obj.MaxA = single(exp(-obj.FilterOrder/obj.MaxTimeConstantNumFrames));
			nBuf = min(size(F,3), obj.FilterOrder);
			if nBuf < obj.FilterOrder
				obj.OutputBuffer = repmat(F(:,:,1,:),1,1,obj.FilterOrder,1);
			else
				obj.OutputBuffer = F(:,:,1:nBuf,:);
			end
			
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function F = stepImpl(obj, F, varargin)
			
			if nargin > 1
				if ~isempty(F)
					% LOCAL VARIABLES
					F0 = obj.OutputBuffer;
					N0Max = obj.MaxTimeConstantNumFrames;
					
					% RUN GPU KERNEL
					if obj.AdaptiveTypeIdx == 1
						% TEMPORALLY ADAPTIVE TEMPORAL FILTER
						A0 = obj.MinA;
						stat = obj.PreFilterStat;
						dmstat = obj.ActivityMetricStat;
						[F, F0, A, stat, dmstat] = temporallyAdaptiveTemporalFilterRunGpuKernel(F, F0, A0, stat, dmstat, N0Max);
						obj.PreFilterStat = stat;
						obj.ActivityMetricStat = dmstat;
						
					elseif obj.AdaptiveTypeIdx == 2
						% SPATIALLY ADAPTIVE TEMPORAL FILTER
						A0 = max(obj.A, obj.MinA);
						[F, F0, A] = spatiallyAdaptiveTemporalFilterRunGpuKernel(F, F0, A0, N0Max);
												
					else
						% NONE
						[F, F0] = temporalArFilterRunGpuKernel(F, obj.A, F0, obj.FilterOrder);
						
					end
					
					% UPDATE PROPERTIES
					obj.OutputBuffer = F0;
					obj.A = A;
					
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