classdef (CaseInsensitiveProperties = true) ImageNormalizer < scicadelic.SciCaDelicSystem
	% IMAGENORMALIZER - Normalizes input and scales to values between [0,1], [-sigma,sigma] (single) or [0,255] (uint8)
	%	
	%
	% Syntax:
	%			>> INr = scicadelic.ImageNormalizer;
	%			>> Fr = step(INr, F);
	%			>> INg = scicadelic.ImageNormalizer('NormalizationType','ExpNormComplement');
	%			>> Fg = step(INg, F);
	%			>> INb = scicadelic.ImageNormalizer('NormalizationType','Geman-McClure');
	%			>> Fb = step(INb, F);
	%
	% Description:
	%			Currently the options that seem to work well are:
	%					'PScore-Framewise' (Default)
	%					'ExpNormComplement'
	%					'Geman-McClure'
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
		NormalizationType = 'PScore-Framewise'
	end
	properties (Nontunable, Logical)
	end
	properties (Nontunable, PositiveInteger)
		FilterOrder = 1
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
	properties (SetAccess = protected)
		StatCollector
		PixelMin
		PixelMax
		PixelMean
		PixelVariance
	end
	properties (Nontunable, Access = protected, Hidden)	
	end
	properties (SetAccess = protected, Hidden, Nontunable)
		NormalizationTypeSet = matlab.system.StringSet({'PScore-Framewise','ZScore-Framewise','ExpNorm','LogNorm','ExpNormComplement','PScore-Pixelwise','ZScore-Pixelwise','Welsch','Geman-McClure','Cauchy','Lp'})
		NormalizationTypeIdx		
	end
	
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = ImageNormalizer(varargin)
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
			updateNormalizationTypeIdx(obj)
			obj.StatCollector = scicadelic.StatisticCollector;
			
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function F = stepImpl(obj, Fin)
			
			if nargin > 1
				if ~isempty(Fin)
					% APPLY PRE-UPDATE IF THIS IS FIRST CALL, OTHERWISE POST-UPDATE
					if ~isempty(obj.StatCollector.N)
						% UPDATE STAT COLLECTOR AFTER NORMALIZATION
						updatePixelStats(obj)
						F = normalizeInput(obj, Fin);
						step(obj.StatCollector, Fin);
					else
						% UPDATE STAT COLLECTOR BEFORE NORMALIZATION
						step(obj.StatCollector, Fin);
						updatePixelStats(obj)
						F = normalizeInput(obj, Fin);
					end
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
	% RUNTIME HELPER METHODS
	% ##################################################
	methods (Access = protected)		
		function F = normalizeInput(obj, Fin)
			
			% TODO: Make GpuKernelFunctions
			
			cLow = min(min(obj.PixelMin,[],1),[],2);
			cHigh = max(max(obj.PixelMax,[],1),[],2);
			cRange = max(cHigh - cLow, eps(cHigh));
			if ~isfloat(Fin)
				F = single(Fin);
				cLow = single(cLow);
				cRange = single(cRange);
			else
				F = Fin;
			end
			
			
			% {'ExpNorm','LogNorm','ExpNormComplement','PScore','ZScore','Welsch','Geman-McClure','Cauchy','Lp'}
			switch obj.NormalizationTypeIdx				
					
				case 1
					% -----------------------------------
					% PSCORE-FRAMEWISE
					% -----------------------------------
					F = bsxfun(@times, bsxfun(@minus, F, cLow), 1./cRange);
					
				case 2
					% -----------------------------------
					% ZSCORE-FRAMEWISE
					% -----------------------------------
					cMean = mean(mean(obj.PixelMean,1),2);
					cRange = mean(mean(sqrt(obj.PixelVariance),1),2);
					F = bsxfun(@times, bsxfun(@minus, F, cMean), 1./cRange);
					
				case 3
					% -----------------------------------
					% EXPNORM
					% -----------------------------------					
					m = cast(1/(1-exp(-1)), 'like', F); %expInvScale
					b = cast(exp(-1), 'like', F); % expInvShift					
					F = bsxfun(@minus, F, cLow);
					F = bsxfun(@minus, cRange, F);
					F = bsxfun(@times, F, 1./cRange);
					F = exp(-F);
					F = m * (F - b);
					
				case 4
					% -----------------------------------
					% LOGNORM
					% -----------------------------------
					m = cast(1/(exp(-1)), 'like', F); %expInvScale
					b = cast(1-exp(-1), 'like', F); % expInvShift		
					F = max(0, bsxfun(@minus, F, cLow));
					F = max(0, abs(bsxfun(@minus, cRange, F)));
					F = bsxfun(@rdivide, cRange, F);
					F = log1p(F);
					F = m .* (F - b);
					
				case 5
					% -----------------------------------
					% EXPNORMCOMPLEMENT
					% -----------------------------------					
					a = bsxfun(@max, F, cast(obj.PixelMax,'like',F));					
					F = 1 - exp( bsxfun(@rdivide, bsxfun(@minus, F, a), a+eps(a) ));					
					cRange = cast(1-exp(-1),'like',F);
					F = bsxfun(@times, F, 1./cRange);
				
				case 6
					% -----------------------------------
					% PSCORE-PIXELWISE
					% -----------------------------------
					fMin = bsxfun(@min, min(F,[],3), obj.PixelMin);
					fMax = bsxfun(@max, max(F,[],3), obj.PixelMax);
					fRange = fMax - fMin;
					F = bsxfun(@times, bsxfun(@minus, F, fMin), 1./fRange);
					
				case 7
					% -----------------------------------
					% ZSCORE-PIXELWISE
					% -----------------------------------
					fMean = obj.PixelMean;
					fStd = sqrt(obj.PixelVariance);
					F = bsxfun(@times, bsxfun(@minus, F, fMean), 1./fStd);
					
				case 8
					% -----------------------------------
					% WELSCH
					% -----------------------------------					
					a2 = obj.PixelVariance;
					F = bsxfun(@times, .5*a2, (1 - exp(-bsxfun(@rdivide, F.^2, a2))));
					
				case 9
					% -----------------------------------
					% GEMAN-MCCLURE
					% -----------------------------------
					fVar = obj.PixelVariance;
					fSquared = F.^2;
					F = bsxfun(@rdivide, fSquared, bsxfun(@plus, fSquared, fVar));
					
				case 10
					% -----------------------------------
					% CAUCHY
					% -----------------------------------
					a2 = obj.PixelVariance;
					% 					c = cast(obj.PixelMax,'like',F);
					F = bsxfun(@times, .5*a2, log1p(bsxfun(@rdivide, F.^2, a2)));
				
				case 11
					% -----------------------------------
					% LP
					% -----------------------------------					
					a = obj.PixelVariance;
					F = bsxfun(@times, bsxfun(@power, F, a), 1./a);
					
					
			end
			
		end
		function F = normalizeOutput(~, F)
			% TODO
			lowLim = approximateFrameMinimum(F, .20);
			highLim = approximateFrameMaximum(F, .001);
			% lowLim = gather(temporalArFilterRunGpuKernel(gpuArray(lowLim), .97));
			% highLim = gather(temporalArFilterRunGpuKernel(gpuArray(highLim), .97));
			limRange = highLim - lowLim;
			F = bsxfun(@times, bsxfun(@minus, F, lowLim), 1./limRange);
			
		end
		function updatePixelStats(obj)
			
			sc = obj.StatCollector;
			obj.PixelMin = sc.Min;
			obj.PixelMax = sc.Max;
			obj.PixelMean = sc.Mean;
			obj.PixelVariance = sc.Variance;
			
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
		function updateNormalizationTypeIdx(obj)
			% SET/LOCK FILTER TYPE 
			if ~isempty(obj.NormalizationType)
				obj.NormalizationTypeIdx = getIndex(obj.NormalizationTypeSet, obj.NormalizationType);
			else
				obj.NormalizationTypeIdx = 1;
			end
		end
	end
	methods
		function set.NormalizationType(obj, filterType)			
			obj.NormalizationType = filterType;
			updateNormalizationTypeIdx(obj);
		end
	end
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