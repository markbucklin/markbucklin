classdef (CaseInsensitiveProperties = true, TruncatedProperties) AdaptiveTemporalFilter < rtsci.proc.PipedSystem
	% ADAPTIVETEMPORALFILTER - Suppresses noise due to local motion
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
	%			BWMORPH GPUARRAY/BWMORPH UPDATESTATISTICSGPU, RTSCI.STATISTICCOLLECTOR
	
	
	
	
	
	
	
	
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
	properties (SetAccess = ?rtsci.System)
		Output
	end
	
	
	% ##################################################
	% PRIVATE
	% ##################################################	
	properties (SetAccess = ?rtsci.System, Hidden)		
		OutputBuffer
	end
	properties (SetAccess = ?rtsci.System)
		A
		PreFilterStat
		ActivityMetricStat
	end
	properties (Nontunable, Access = ?rtsci.System)		
		MinA
		MaxA
	end
	properties (SetAccess = ?rtsci.System, Nontunable, Hidden)
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
	methods (Access = ?rtsci.System)
		function F = run(obj, F, varargin)
			
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
	end
	
	% ##################################################
	% INTERNAL SYSTEM METHODS
	% ##################################################
	methods (Access = protected)		
		function setupImpl(obj, F)
			
			% INITIALIZATION (STANDARD)
			setupImpl@rtsci.proc.PipedSystem(obj, F)
			
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
	end
	
	
	
	
	% ##################################################
	% OUTPUT DISPLAY
	% ##################################################
	methods (Access = public)
	end
	
	
	
	
	
	
	
	
	
	
end
