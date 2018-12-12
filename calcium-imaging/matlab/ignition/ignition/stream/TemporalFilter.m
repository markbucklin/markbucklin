classdef (CaseInsensitiveProperties = true, TruncatedProperties) TemporalFilter < ignition.core.VideoStreamProcessor
	% TEMPORALFILTER - Suppresses noise using recursive filter in time domain
	%
	%
	% Syntax:
	%			>> [dstat, stat] = getStatisticDifferentialGPU(F);
	%			>> [dstat, stat] = getStatisticDifferentialGPU(F, stat);
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
	%			BWMORPH GPUARRAY/BWMORPH UPDATESTATISTICSGPU, IGNITION.STATISTICCOLLECTOR
	
	
	
	
	
	
	
	
	% ##################################################
	% SETTINGS
	% ##################################################
	properties (Nontunable)
		MinTimeConstantNumFrames = 3
		MaxTimeConstantNumFrames = 50
		AdaptiveType = 'none'
	end
	properties (Nontunable, Logical)
	end
	properties (Nontunable, PositiveInteger)
		FilterOrder = 2
	end
	
	
	% ##################################################
	% OUTPUT
	% ##################################################
	properties (SetAccess = ?ignition.core.Object)
		Output
	end
	
	
	% ##################################################
	% PRIVATE
	% ##################################################
	properties (SetAccess = ?ignition.core.Object, Hidden)
		OutputBuffer
	end
	properties (SetAccess = ?ignition.core.Object)
		A
		PreFilterStat
		ActivityMetricStat
	end
	properties (Nontunable, Access = ?ignition.core.Object)
		MinA
		MaxA
	end
	properties (SetAccess = ?ignition.core.Object, Nontunable, Hidden)
		signedConversionFcn
		AdaptiveTypeSet = matlab.system.StringSet({'Temporal','Spatial','none'})
		AdaptiveTypeIdx
	end
	
	
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = TemporalFilter(varargin)
			
			parseConstructorInput(obj,varargin{:});
			initialize(obj);
			
		end
	end
	
	
	% ##################################################
	% RUN: MAIN PROCESSING PROCEDURE
	% ##################################################
	methods (Access = ?ignition.core.Object)
		function F = run(obj, F)
			
			if nargin > 1
				if ~isempty(F)
					% LOCAL VARIABLES
					F0 = obj.OutputBuffer;
					N0Max = obj.MaxTimeConstantNumFrames;
					A = obj.A;
					
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
						[F, F0] = temporalArFilterRunGpuKernel(F, A, F0, obj.FilterOrder);
						
					end
					
					% UPDATE PROPERTIES
					obj.OutputBuffer = F0;
					obj.A = A;
					
				end
				
			else
				F = [];
			end
			
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
			setupImpl@ignition.core.VideoStreamProcessor(F)
			
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
			obj.A = double(obj.MinA);
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
		
	end
	
	
	
	
	
	
	
end
