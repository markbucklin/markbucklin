classdef (CaseInsensitiveProperties = true) ImageNormalizer < ignition.core.VideoStreamProcessor
	% IMAGENORMALIZER - Normalizes input and scales to values between [0,1], [-sigma,sigma] (single) or [0,255] (uint8)
	%	
	%
	% Syntax:
	%			>> INr = ignition.stream.ImageNormalizer;
	%			>> Fr = step(INr, F);
	%			>> INg = ignition.stream.ImageNormalizer('NormalizationType','ExpNormComplement');
	%			>> Fg = step(INg, F);
	%			>> INb = ignition.stream.ImageNormalizer('NormalizationType','Geman-McClure');
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
	%			BWMORPH GPUARRAY/BWMORPH UPDATESTATISTICSGPU, ignition.stream.STATISTICCOLLECTOR
	
	
	
	
	
	
	
	
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
	properties (SetAccess = ?ignition.core.Object)
		Output
	end
	
	
	% ##################################################
	% PRIVATE
	% ##################################################	
	properties (SetAccess = ?ignition.core.Object)		
		PixelMin
		PixelMax
		PixelMean
		PixelVariance
	end
	properties (Nontunable, SetAccess = ?ignition.core.Object)
		StatCollector		
	end
	properties (SetAccess = ?ignition.core.Object, Hidden, Nontunable)
		NormalizationTypeSet = matlab.system.StringSet({'PScore-Framewise','ZScore-Framewise','ExpNorm','LogNorm','ExpNormComplement','PScore-Pixelwise','ZScore-Pixelwise','Welsch','Geman-McClure','Cauchy','Lp'})
		NormalizationTypeIdx		
	end
	
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = ImageNormalizer(varargin)
			
			% PARSE INPUT
			parseConstructorInput(obj,varargin{:});
			
			% GET NAME OF PACKAGE CONTAINING CLASS
			% 			getCurrentClassPackage
			% 			obj.SubPackageName = currentClassPkg;
				
			% INITIALIZE
			% 			initialize(obj)
			
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
			F = checkInput(obj, F);
			initialize(obj)			
			
			% INITIALIZATION (CLASS-SPECIFIC)
			updateNormalizationTypeIdx(obj)
			% 			obj.StatCollector = ignition.stream.StatisticCollector;
			
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function F = stepImpl(obj, Fin)
			
			% CHECK INPUT
			Fin = checkInput(obj, Fin);
			
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
			
			% CHECK OUTPUT
			F = checkOutput(obj, F);
			
		end
		
		
	end
	
	% ##################################################
	% RUNTIME HELPER METHODS
	% ##################################################
	methods (Access = protected)
		function F = normalizeInput(obj, F)
			
			% TODO: Make GpuKernelFunctions
			
			cLow = min(min(obj.PixelMin,[],1),[],2);
			cHigh = max(max(obj.PixelMax,[],1),[],2);
			cRange = max(cHigh - cLow, eps(cHigh));
			if ~isfloat(F)
				F = single(F);
				cLow = single(cLow);
				cRange = single(cRange);			
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
		function updatePixelStats(obj)
			
			sc = obj.StatCollector;
			obj.PixelMin = sc.Min;
			obj.PixelMax = sc.Max;
			obj.PixelMean = sc.Mean;
			obj.PixelVariance = sc.Variance;
			
		end
	end
	
	
	
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
	methods (Hidden)
		function initialize(obj)
			
			if obj.IsInitialized
				return
			end
			
			obj.StatCollector = ignition.stream.StatisticCollector;
			
			obj.initialize@ignition.core.Object()
			
		end
	end
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
	
	% ##################################################
	% OUTPUT DISPLAY
	% ##################################################
	methods (Access = public)
	end
	
	
	
	
	
	
	
	
	
	
end
