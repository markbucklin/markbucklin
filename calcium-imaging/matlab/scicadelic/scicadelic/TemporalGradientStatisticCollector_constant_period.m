classdef (CaseInsensitiveProperties = true) TemporalGradientStatisticCollector < scicadelic.StatisticCollector
	% TEMPORALGRADIENTSTATISTICCOLLECTOR - Computes running statistics after taking temporal derivative of input
	%
	%
	% Syntax:
	%			>> sc = scicadelic.TemporalGradientStatisticCollector;
	%			>> step(sc, F);
	%
	% Description:
	%			Additional options available for collecting positive (increasing) or negative (decreasing) samples only:
	%					'None' (Default)
	%					'Positive Only'
	%					'Negative Only'
	%
	%			The other options may need work... (TODO)
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
		GradientRestriction = 'None'
	end
	
	% ##################################################
	% PRIVATE
	% ##################################################
	properties (SetAccess = protected, Hidden)
		InputBuffer
	end
	properties (SetAccess = protected, Nontunable, Hidden)		
		GradientRestrictionSet = matlab.system.StringSet({'None','Positive Only','Negative Only','Absolute Value','Square'})
		GradientRestrictionIdx
	end
	
	
	
	
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = TemporalGradientStatisticCollector(varargin)
			% CALL PARENT CONSTRUCTOR WITH RELAYED INPUT
			obj = obj@scicadelic.StatisticCollector(varargin{:});
			
		end
	end
	
	% ##################################################
	% BASIC INTERNAL SYSTEM METHODS
	% ##################################################
	methods (Access = protected)
		
		% ============================================================
		% SETUP
		% ============================================================
		function setupImpl(obj, F)
			
			% CHECK GRADIENT RESTRICTION & UPDATE INDEX
			if ~isempty(obj.GradientRestriction)
				obj.GradientRestrictionIdx = getIndex(obj.GradientRestrictionSet, obj.GradientRestriction);
			else
				obj.GradientRestrictionIdx = 1;
			end
			
			% USE MEAN OF FIRST CHUNK TO PREPARE INPUT BUFFER
			if isempty(obj.InputBuffer)
				Ft = computeTemporalGradient(obj, F);				
			else				
				Ft = computeTemporalGradient(obj, F, obj.InputBuffer);
			end
			
			% REFILL INPUT BUFFER
			obj.InputBuffer = cast(mean(F(:,:,1:2,:),3) - diff(double(F(:,:,1:2,:)),[],3),'like',F);
			
			% CALL PARENT FUNCTION
			setupImpl@scicadelic.StatisticCollector(obj, Ft);
			
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function varargout = stepImpl(obj, F)
			
			Ft = computeTemporalGradient(obj, F);
			
			% CALL PARENT FUNCTION
			numArgs = getNumOutputs(obj);
			if numArgs == 0
				stepImpl@scicadelic.StatisticCollector(obj, Ft);
			elseif numArgs == 1
				availableArgs{1} = stepImpl@scicadelic.StatisticCollector(obj, Ft);
			elseif numArgs == 2
				[availableArgs{1}, availableArgs{2}] = stepImpl@scicadelic.StatisticCollector(obj, Ft);
			else
				[availableArgs{1}, availableArgs{2}, availableArgs{3}] = stepImpl@scicadelic.StatisticCollector(obj, Ft);
			end
			
			if nargout
				varargout = availableArgs(1:nargout);
			end
			
		end
		
		
	end
	
	
	% ##################################################
	% RUNTIME HELPER METHODS
	% ##################################################
	methods (Access = protected)
		function Ft = computeTemporalGradient(obj, F, Fbuf)
			
			% -----------------------------------
			% MANAGE INPUT & CREATE LOCAL VARIABLES
			% -----------------------------------
			if nargin < 3
				Fbuf = obj.InputBuffer;
			end
			if isempty(Fbuf)
				Fbuf = cast(single(F(:,:,1,:)) - single(mean(diff(F,[],3),3)), 'like', F);
			end
			numFrames = size(F,3);			
			
			% -----------------------------------
			% COMPUTE TEMPORAL GRADIENT
			% -----------------------------------
			if obj.UseGpu
				% CALL EXTERNAL FUNCTION THAT USES ARRAYFUN TO OPERATE ON GPU
				[Ft, obj.InputBuffer] = temporalGradientRunGpuKernel(F,Fbuf);
				
			else
				% PREALLOCATE & CONVERT INPUT TO FLOATING-POINT
				Ft = single(F);
				F0 = single(Fbuf);
				
				% LOOP THROUGH FRAMES (TAKES ADVANTAGE OF MATLAB JIT-ACCELERATION...? CHECK)
				k = numFrames;
				while (k>1)
					Ft(:,:,k,:) = Ft(:,:,k,:) - Ft(:,:,k-1,:);
					k = k - 1;
				end
				Ft(:,:,k,:) = max(0, Ft(:,:,k,:) - F0);
				
				% REFILL INPUT BUFFER
				obj.InputBuffer = F(:,:,end,:);
				
			end
			
			% -----------------------------------
			% CHECK RESTRICTIONS
			% -----------------------------------			
			switch obj.GradientRestrictionIdx
				case 2 % POSITIVE ONLY				
					Ft = max(0, Ft);					
				case 3 % NEGATIVE ONLY						
					Ft = min(0, Ft);
				case 4 % ABS
					Ft = abs(Ft);
				case 5 % SQUARE
					Ft = Ft.^2;
			end
			
			
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












